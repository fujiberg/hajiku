import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/wanikani_assignment.dart';
import 'models/wanikani_level_progression.dart';
import 'models/wanikani_subject.dart';
import 'models/wanikani_user.dart';
import 'wanikani_exception.dart';

/// Thin client for the WaniKani API v2 (https://docs.api.wanikani.com).
class WaniKaniApiClient {
  WaniKaniApiClient({required this._tokenProvider, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static final Uri _baseUrl = Uri.parse('https://api.wanikani.com/v2/');
  static const _apiRevision = '20170710';

  final Future<String?> Function() _tokenProvider;
  final http.Client _httpClient;

  /// Fetches the authenticated user's profile, validating the API token.
  Future<WaniKaniUser> getUser() async {
    final json = await _get(_baseUrl.resolve('user'));
    return WaniKaniUser.fromJson(json);
  }

  /// Fetches the user's assignments (progress) for subjects at [level],
  /// optionally restricted to the given [srsStages]. Defaults to stages
  /// below Guru (0-4), i.e. items still needed to level up.
  Future<List<WaniKaniAssignment>> getAssignments({
    required int level,
    List<int> srsStages = const [0, 1, 2, 3, 4],
  }) async {
    final assignments = <WaniKaniAssignment>[];
    Uri? uri = _baseUrl
        .resolve('assignments')
        .replace(
          queryParameters: {
            'levels': '$level',
            'srs_stages': srsStages.join(','),
          },
        );

    while (uri != null) {
      final json = await _get(uri);
      assignments.addAll(
        (json['data'] as List<dynamic>).map(
          (e) => WaniKaniAssignment.fromJson(e as Map<String, dynamic>),
        ),
      );

      final nextUrl = (json['pages'] as Map<String, dynamic>)['next_url'];
      uri = nextUrl == null ? null : Uri.parse(nextUrl as String);
    }

    return assignments;
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
  Future<List<WaniKaniSubject>> getSubjects(List<int> ids) {
    if (ids.isEmpty) return Future.value(const []);

    final uri = _baseUrl
        .resolve('subjects')
        .replace(queryParameters: {'ids': ids.join(',')});
    return _getAllPages(uri, WaniKaniSubject.fromJson);
  }

  /// Submits the result of a completed review for [assignmentId], advancing
  /// (or resetting) its SRS stage on WaniKani.
  Future<void> submitReview({
    required int assignmentId,
    required int incorrectMeaningAnswers,
    required int incorrectReadingAnswers,
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const WaniKaniAuthException('No WaniKani API token configured.');
    }

    final response = await _httpClient.post(
      _baseUrl.resolve('reviews'),
      headers: {
        'Authorization': 'Bearer $token',
        'Wanikani-Revision': _apiRevision,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'review': {
          'assignment_id': assignmentId,
          'incorrect_meaning_answers': incorrectMeaningAnswers,
          'incorrect_reading_answers': incorrectReadingAnswers,
        },
      }),
    );

    switch (response.statusCode) {
      case 200:
      case 201:
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
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const WaniKaniAuthException('No WaniKani API token configured.');
    }

    final response = await _httpClient.put(
      _baseUrl.resolve('assignments/$assignmentId/start'),
      headers: {
        'Authorization': 'Bearer $token',
        'Wanikani-Revision': _apiRevision,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    switch (response.statusCode) {
      case 200:
      case 201:
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

  /// Fetches the user's progress through each WaniKani level.
  Future<List<WaniKaniLevelProgression>> getLevelProgressions() async {
    final progressions = <WaniKaniLevelProgression>[];
    Uri? uri = _baseUrl.resolve('level_progressions');

    while (uri != null) {
      final json = await _get(uri);
      progressions.addAll(
        (json['data'] as List<dynamic>).map(
          (e) => WaniKaniLevelProgression.fromJson(e as Map<String, dynamic>),
        ),
      );

      final nextUrl = (json['pages'] as Map<String, dynamic>)['next_url'];
      uri = nextUrl == null ? null : Uri.parse(nextUrl as String);
    }

    return progressions;
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
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final items = <T>[];
    Uri? next = uri;

    while (next != null) {
      final json = await _get(next);
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

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const WaniKaniAuthException('No WaniKani API token configured.');
    }

    final response = await _httpClient.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Wanikani-Revision': _apiRevision,
      },
    );

    switch (response.statusCode) {
      case 200:
        return jsonDecode(response.body) as Map<String, dynamic>;
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
}
