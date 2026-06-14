import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/wanikani/models/wanikani_assignment.dart';
import 'package:hajiku/src/core/wanikani/wanikani_api_client.dart';
import 'package:hajiku/src/core/wanikani/wanikani_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('returns the parsed user on a 200 response', () async {
    final mockClient = MockClient((request) async {
      expect(request.url, Uri.parse('https://api.wanikani.com/v2/user'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Wanikani-Revision'], '20170710');

      return http.Response(
        jsonEncode({
          'object': 'user',
          'data': {'username': 'taro', 'level': 5},
        }),
        200,
      );
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    final user = await client.getUser();

    expect(user.username, 'taro');
    expect(user.level, 5);
  });

  test('throws WaniKaniAuthException when no token is configured', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => null,
      httpClient: MockClient((request) async => http.Response('', 200)),
    );

    await expectLater(client.getUser(), throwsA(isA<WaniKaniAuthException>()));
  });

  test('throws WaniKaniAuthException on a 401 response', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => 'bad-token',
      httpClient: MockClient((request) async => http.Response('', 401)),
    );

    await expectLater(client.getUser(), throwsA(isA<WaniKaniAuthException>()));
  });

  test('throws WaniKaniApiException on an unexpected status', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async => http.Response('', 500)),
    );

    await expectLater(
      client.getUser(),
      throwsA(
        isA<WaniKaniApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
  });

  test('returns the parsed assignments for the given level', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/v2/assignments');
      expect(request.url.queryParameters['levels'], '5');
      expect(request.url.queryParameters['srs_stages'], '0,1,2,3,4');

      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'object': 'assignment',
              'data': {'subject_type': 'radical', 'srs_stage': 0},
            },
            {
              'object': 'assignment',
              'data': {'subject_type': 'kanji', 'srs_stage': 3},
            },
          ],
        }),
        200,
      );
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    final assignments = await client.getAssignments(level: 5);

    expect(assignments, hasLength(2));
    expect(assignments[0].subjectType, WaniKaniSubjectType.radical);
    expect(assignments[0].srsStage, 0);
    expect(assignments[1].subjectType, WaniKaniSubjectType.kanji);
    expect(assignments[1].srsStage, 3);
  });

  test('follows pagination to fetch all assignments', () async {
    var requestCount = 0;
    final mockClient = MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        return http.Response(
          jsonEncode({
            'pages': {
              'next_url':
                  'https://api.wanikani.com/v2/assignments?page_after_id=1',
            },
            'data': [
              {
                'object': 'assignment',
                'data': {'subject_type': 'radical', 'srs_stage': 0},
              },
            ],
          }),
          200,
        );
      }

      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'object': 'assignment',
              'data': {'subject_type': 'vocabulary', 'srs_stage': 2},
            },
          ],
        }),
        200,
      );
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    final assignments = await client.getAssignments(level: 5);

    expect(requestCount, 2);
    expect(assignments, hasLength(2));
    expect(assignments[1].subjectType, WaniKaniSubjectType.vocabulary);
  });

  test('returns the total count of available reviews', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.queryParameters['per_page'], '1');
      expect(
        request.url.queryParameters['immediately_available_for_review'],
        'true',
      );

      return http.Response(
        jsonEncode({
          'total_count': 42,
          'pages': {'next_url': null},
          'data': <Object>[],
        }),
        200,
      );
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    final count = await client.getAssignmentCount(
      immediatelyAvailableForReview: true,
    );

    expect(count, 42);
  });

  test('returns the parsed level progressions', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/v2/level_progressions');

      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'object': 'level_progression',
              'data': {'level': 3, 'started_at': '2026-05-01T00:00:00.000Z'},
            },
            {
              'object': 'level_progression',
              'data': {'level': 4, 'started_at': null},
            },
          ],
        }),
        200,
      );
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    final progressions = await client.getLevelProgressions();

    expect(progressions, hasLength(2));
    expect(progressions[0].level, 3);
    expect(progressions[0].startedAt, DateTime.utc(2026, 5, 1));
    expect(progressions[1].level, 4);
    expect(progressions[1].startedAt, isNull);
  });
}
