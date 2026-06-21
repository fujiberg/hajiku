import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../cache/cache_stats.dart';
import 'http_cache_store.dart';
import 'models/wanikani_assignment.dart';
import 'models/wanikani_level_progression.dart';
import 'models/wanikani_study_material.dart';
import 'models/wanikani_subject.dart';
import 'models/wanikani_user.dart';
import 'wanikani_exception.dart';

/// Thin client for the WaniKani API v2 (https://docs.api.wanikani.com).
class WaniKaniApiClient {
  WaniKaniApiClient({
    required this._tokenProvider,
    http.Client? httpClient,
    HttpCacheStore? cacheStore,
    this.statsRecorder,
    Future<void> Function(Duration)? sleep,
  }) : _httpClient = httpClient ?? http.Client(),
       _cacheStore = cacheStore ?? InMemoryHttpCacheStore(),
       _sleep = sleep ?? Future<void>.delayed;

  static final Uri _baseUrl = Uri.parse('https://api.wanikani.com/v2/');
  static const _apiRevision = '20170710';

  /// How many times a request is retried after a `429 Too Many Requests`
  /// before giving up.
  static const _maxRateLimitRetries = 4;

  /// Upper bound on how long to wait between retries, regardless of what the
  /// server's `Retry-After` header asks for.
  static const _maxRetryWait = Duration(seconds: 60);

  final Future<String?> Function() _tokenProvider;
  final http.Client _httpClient;

  /// Caches `ETag`/body pairs for conditional GETs (see [_get]).
  final HttpCacheStore _cacheStore;

  /// Records cache hit/miss statistics, if wired in.
  final CacheStatsRecorder? statsRecorder;

  /// Waits for the given duration between rate-limit retries. Injectable so
  /// tests can run without real delays.
  final Future<void> Function(Duration) _sleep;

  /// Fetches the authenticated user's profile, validating the API token.
  Future<WaniKaniUser> getUser() async {
    final json = await _get(_baseUrl.resolve('user'), cacheable: true);
    return WaniKaniUser.fromJson(json);
  }

  /// Fetches the user's assignments (progress) for subjects at [level].
  /// Pass [srsStages] to restrict to specific stages; omit for all stages.
  Future<List<WaniKaniAssignment>> getAssignments({
    required int level,
    List<int>? srsStages,
  }) {
    final uri = _baseUrl
        .resolve('assignments')
        .replace(
          queryParameters: {
            'levels': '$level',
            if (srsStages != null) 'srs_stages': srsStages.join(','),
          },
        );
    return _getAllPages(uri, WaniKaniAssignment.fromJson);
  }

  /// Fetches the assignments that currently have a review available,
  /// regardless of level.
  Future<List<WaniKaniAssignment>> getReviewAssignments() {
    final uri = _baseUrl
        .resolve('assignments')
        .replace(queryParameters: {'immediately_available_for_review': 'true'});
    return _getAllPages(uri, WaniKaniAssignment.fromJson);
  }

  /// Fetches the assignments that currently have a lesson available,
  /// regardless of level.
  Future<List<WaniKaniAssignment>> getLessonAssignments() {
    final uri = _baseUrl
        .resolve('assignments')
        .replace(
          queryParameters: {'immediately_available_for_lessons': 'true'},
        );
    return _getAllPages(uri, WaniKaniAssignment.fromJson);
  }

  /// Fetches assignments whose next review is due before [before],
  /// including any already overdue. Burned items (which have no further
  /// reviews) and not-yet-started items (lessons) are excluded.
  Future<List<WaniKaniAssignment>> getUpcomingReviewAssignments({
    required DateTime before,
  }) {
    final uri = _baseUrl
        .resolve('assignments')
        .replace(
          queryParameters: {
            'srs_stages': '1,2,3,4,5,6,7,8',
            'available_before': before.toUtc().toIso8601String(),
          },
        );
    return _getAllPages(uri, WaniKaniAssignment.fromJson);
  }

  /// Fetches the subjects (radicals/kanji/vocabulary) with the given [ids].
  ///
  /// Pass [updatedAfter] to fetch only subjects changed since that time — used
  /// to cheaply revalidate already-cached subjects (the response is usually
  /// empty, since subject data changes very rarely).
  Future<List<WaniKaniSubject>> getSubjects(
    List<int> ids, {
    DateTime? updatedAfter,
  }) {
    if (ids.isEmpty) return Future.value(const []);

    final uri = _baseUrl
        .resolve('subjects')
        .replace(
          queryParameters: {
            'ids': ids.join(','),
            if (updatedAfter != null)
              'updated_after': updatedAfter.toUtc().toIso8601String(),
          },
        );
    return _getAllPages(uri, WaniKaniSubject.fromJson, cacheable: true);
  }

  /// Submits the result of a completed review for [assignmentId], advancing
  /// (or resetting) its SRS stage on WaniKani.
  Future<void> submitReview({
    required int assignmentId,
    required int incorrectMeaningAnswers,
    required int incorrectReadingAnswers,
  }) async {
    final response = await _sendWithRetry(
      (headers) => _httpClient.post(
        _baseUrl.resolve('reviews'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'review': {
            'assignment_id': assignmentId,
            'incorrect_meaning_answers': incorrectMeaningAnswers,
            'incorrect_reading_answers': incorrectReadingAnswers,
          },
        }),
      ),
    );

    switch (response.statusCode) {
      case 200:
      case 201:
        statsRecorder?.recordUncacheable();
        return;
      case 401:
        throw const WaniKaniAuthException('WaniKani API token was rejected.');
      default:
        throw WaniKaniApiException(
          response.statusCode,
          'WaniKani API request to submit a review failed with status '
          '${response.statusCode}.',
        );
    }
  }

  /// Marks assignment [assignmentId] as started, which WaniKani requires
  /// before a review result can be submitted for a lesson item.
  Future<void> startAssignment(int assignmentId) async {
    final response = await _sendWithRetry(
      (headers) => _httpClient.put(
        _baseUrl.resolve('assignments/$assignmentId/start'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ),
    );

    switch (response.statusCode) {
      case 200:
      case 201:
        statsRecorder?.recordUncacheable();
        return;
      case 401:
        throw const WaniKaniAuthException('WaniKani API token was rejected.');
      default:
        throw WaniKaniApiException(
          response.statusCode,
          'WaniKani API request to start assignment $assignmentId failed '
          'with status ${response.statusCode}.',
        );
    }
  }

  /// Fetches study materials (user-created synonyms and notes) for the given
  /// [subjectIds]. Returns only entries that exist — subjects with no custom
  /// data are simply absent from the result.
  Future<List<WaniKaniStudyMaterial>> getStudyMaterials(
    List<int> subjectIds,
  ) {
    if (subjectIds.isEmpty) return Future.value(const []);
    final uri = _baseUrl.resolve('study_materials').replace(
      queryParameters: {'subject_ids': subjectIds.join(',')},
    );
    return _getAllPages(uri, WaniKaniStudyMaterial.fromJson);
  }

  /// Fetches the user's progress through each WaniKani level.
  Future<List<WaniKaniLevelProgression>> getLevelProgressions() {
    return _getAllPages(
      _baseUrl.resolve('level_progressions'),
      WaniKaniLevelProgression.fromJson,
      cacheable: true,
    );
  }

  /// Returns the number of assignments with lessons or reviews
  /// immediately available, without fetching the underlying subject data.
  /// If [srsStages] is given, only assignments at one of those SRS stages
  /// are counted.
  Future<int> getAssignmentCount({
    bool? immediatelyAvailableForLessons,
    bool? immediatelyAvailableForReview,
    List<int>? srsStages,
  }) async {
    final uri = _baseUrl
        .resolve('assignments')
        .replace(
          queryParameters: {
            'per_page': '1',
            if (immediatelyAvailableForLessons != null)
              'immediately_available_for_lessons':
                  '$immediatelyAvailableForLessons',
            if (immediatelyAvailableForReview != null)
              'immediately_available_for_review':
                  '$immediatelyAvailableForReview',
            if (srsStages != null) 'srs_stages': srsStages.join(','),
          },
        );

    final json = await _get(uri);
    return json['total_count'] as int;
  }

  /// Follows `pages.next_url` to fetch every page of a paginated endpoint,
  /// parsing each `data` entry with [fromJson].
  Future<List<T>> _getAllPages<T>(
    Uri uri,
    T Function(Map<String, dynamic>) fromJson, {
    bool cacheable = false,
  }) async {
    final items = <T>[];
    Uri? next = uri;

    while (next != null) {
      final json = await _get(next, cacheable: cacheable);
      items.addAll(
        (json['data'] as List<dynamic>).map(
          (e) => fromJson(e as Map<String, dynamic>),
        ),
      );

      final nextUrl = (json['pages'] as Map<String, dynamic>)['next_url'];
      next = nextUrl == null ? null : Uri.parse(nextUrl as String);
    }

    return items;
  }

  /// Performs an authenticated GET, decoding the JSON body.
  ///
  /// When [cacheable], the request is made conditional: if a previous response
  /// for [uri] was cached, its `ETag` is sent as `If-None-Match`, and a `304
  /// Not Modified` reply reuses the cached body instead of re-downloading it.
  /// Fresh `200` responses with an `ETag` are stored for next time.
  Future<Map<String, dynamic>> _get(Uri uri, {bool cacheable = false}) async {
    final key = uri.toString();
    final cached = cacheable ? await _cacheStore.read(key) : null;

    final response = await _sendWithRetry(
      (headers) => _httpClient.get(
        uri,
        headers: {...headers, if (cached != null) 'If-None-Match': cached.etag},
      ),
    );

    switch (response.statusCode) {
      case 200:
        if (cacheable) {
          statsRecorder?.recordFetched();
          final etag = response.headers['etag'];
          if (etag != null) {
            await _cacheStore.write(
              key,
              CachedHttpResponse(etag: etag, body: response.body),
            );
          }
        } else {
          statsRecorder?.recordUncacheable();
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      case 304:
        statsRecorder?.recordRevalidated();
        return jsonDecode(cached!.body) as Map<String, dynamic>;
      case 401:
        throw const WaniKaniAuthException('WaniKani API token was rejected.');
      default:
        throw WaniKaniApiException(
          response.statusCode,
          'WaniKani API request to "$uri" failed with status '
          '${response.statusCode}.',
        );
    }
  }

  /// Resolves the auth/revision headers and invokes [send], transparently
  /// retrying when WaniKani responds with `429 Too Many Requests`. Each retry
  /// waits for the period indicated by the response's `Retry-After` header
  /// (capped at [_maxRetryWait]) so we back off cleanly instead of hammering
  /// the rate-limited endpoint.
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const WaniKaniAuthException('No WaniKani API token configured.');
    }
    final headers = {
      'Authorization': 'Bearer $token',
      'Wanikani-Revision': _apiRevision,
    };

    for (var attempt = 0; ; attempt++) {
      final response = await send(headers);
      if (response.statusCode != 429 || attempt >= _maxRateLimitRetries) {
        return response;
      }
      await _sleep(_retryAfter(response));
    }
  }

  /// How long to wait before retrying a rate-limited request, read from the
  /// `Retry-After` header (a number of seconds, or an HTTP date). Falls back
  /// to one second and is clamped to [_maxRetryWait].
  Duration _retryAfter(http.Response response) {
    final header = response.headers['retry-after'];
    var wait = const Duration(seconds: 1);
    if (header != null) {
      final seconds = int.tryParse(header.trim());
      if (seconds != null) {
        wait = Duration(seconds: seconds);
      } else {
        try {
          wait = HttpDate.parse(header).difference(DateTime.now());
        } on HttpException {
          // Unparseable header — fall back to the default wait.
        }
      }
    }
    if (wait < Duration.zero) wait = Duration.zero;
    return wait > _maxRetryWait ? _maxRetryWait : wait;
  }
}
