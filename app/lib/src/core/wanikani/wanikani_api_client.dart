import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/wanikani_assignment.dart';
import 'models/wanikani_level_progression.dart';
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
  Future<int> getAssignmentCount({
    bool? immediatelyAvailableForLessons,
    bool? immediatelyAvailableForReview,
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
          },
        );

    final json = await _get(uri);
    return json['total_count'] as int;
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
