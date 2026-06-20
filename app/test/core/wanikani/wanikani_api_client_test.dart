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
              'id': 100,
              'object': 'assignment',
              'data': {
                'subject_id': 1,
                'subject_type': 'radical',
                'srs_stage': 0,
              },
            },
            {
              'id': 101,
              'object': 'assignment',
              'data': {
                'subject_id': 2,
                'subject_type': 'kanji',
                'srs_stage': 3,
              },
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
    expect(assignments[0].id, 100);
    expect(assignments[0].subjectId, 1);
    expect(assignments[0].subjectType, WaniKaniSubjectType.radical);
    expect(assignments[0].srsStage, 0);
    expect(assignments[1].id, 101);
    expect(assignments[1].subjectId, 2);
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
                'id': 100,
                'object': 'assignment',
                'data': {
                  'subject_id': 1,
                  'subject_type': 'radical',
                  'srs_stage': 0,
                },
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
              'id': 101,
              'object': 'assignment',
              'data': {
                'subject_id': 2,
                'subject_type': 'vocabulary',
                'srs_stage': 2,
              },
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

  test('returns assignments with a review available', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/v2/assignments');
      expect(
        request.url.queryParameters['immediately_available_for_review'],
        'true',
      );

      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'id': 100,
              'object': 'assignment',
              'data': {
                'subject_id': 1,
                'subject_type': 'kanji',
                'srs_stage': 4,
              },
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

    final assignments = await client.getReviewAssignments();

    expect(assignments, hasLength(1));
    expect(assignments[0].id, 100);
    expect(assignments[0].subjectId, 1);
  });

  test('returns assignments with a lesson available', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/v2/assignments');
      expect(
        request.url.queryParameters['immediately_available_for_lessons'],
        'true',
      );

      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'id': 200,
              'object': 'assignment',
              'data': {
                'subject_id': 5,
                'subject_type': 'radical',
                'srs_stage': 0,
              },
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

    final assignments = await client.getLessonAssignments();

    expect(assignments, hasLength(1));
    expect(assignments[0].id, 200);
    expect(assignments[0].subjectId, 5);
  });

  test('starts an assignment', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/v2/assignments/200/start');

      return http.Response('', 200);
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    await client.startAssignment(200);
  });

  test(
    'throws WaniKaniApiException when starting an assignment fails',
    () async {
      final client = WaniKaniApiClient(
        tokenProvider: () async => 'test-token',
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      await expectLater(
        client.startAssignment(200),
        throwsA(isA<WaniKaniApiException>()),
      );
    },
  );

  test('returns the parsed subjects for the given ids', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/v2/subjects');
      expect(request.url.queryParameters['ids'], '1,2');

      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'id': 1,
              'object': 'radical',
              'data': {
                'characters': '一',
                'slug': 'ground',
                'meanings': [
                  {
                    'meaning': 'Ground',
                    'primary': true,
                    'accepted_answer': true,
                  },
                ],
                'auxiliary_meanings': <Object>[],
              },
            },
            {
              'id': 2,
              'object': 'kanji',
              'data': {
                'characters': '一',
                'slug': '一',
                'meanings': [
                  {'meaning': 'One', 'primary': true, 'accepted_answer': true},
                ],
                'auxiliary_meanings': <Object>[],
                'readings': [
                  {'reading': 'いち', 'primary': true, 'accepted_answer': true},
                ],
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    final subjects = await client.getSubjects([1, 2]);

    expect(subjects, hasLength(2));
    expect(subjects[0].displayText, '一');
    expect(subjects[0].acceptedMeanings, ['Ground']);
    expect(subjects[0].readings, isEmpty);
    expect(subjects[1].acceptedReadings, ['いち']);
  });

  test('returns an empty list of subjects without making a request', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: MockClient(
        (request) async => throw StateError('unexpected request'),
      ),
    );

    expect(await client.getSubjects([]), isEmpty);
  });

  test('submits a review', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/v2/reviews');
      expect(jsonDecode(request.body), {
        'review': {
          'assignment_id': 100,
          'incorrect_meaning_answers': 1,
          'incorrect_reading_answers': 0,
        },
      });

      return http.Response('', 201);
    });

    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: mockClient,
    );

    await client.submitReview(
      assignmentId: 100,
      incorrectMeaningAnswers: 1,
      incorrectReadingAnswers: 0,
    );
  });

  test('throws WaniKaniApiException when submitting a review fails', () async {
    final client = WaniKaniApiClient(
      tokenProvider: () async => 'test-token',
      httpClient: MockClient((request) async => http.Response('', 500)),
    );

    await expectLater(
      client.submitReview(
        assignmentId: 100,
        incorrectMeaningAnswers: 0,
        incorrectReadingAnswers: 0,
      ),
      throwsA(isA<WaniKaniApiException>()),
    );
  });

  test('includes srs_stages when counting assignments', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.queryParameters['per_page'], '1');
      expect(request.url.queryParameters['srs_stages'], '1,2,3,4');

      return http.Response(
        jsonEncode({
          'total_count': 7,
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

    final count = await client.getAssignmentCount(srsStages: [1, 2, 3, 4]);

    expect(count, 7);
  });

  test('returns upcoming review assignments before the given time', () async {
    final before = DateTime.utc(2026, 6, 16);

    final mockClient = MockClient((request) async {
      expect(request.url.path, '/v2/assignments');
      expect(request.url.queryParameters['srs_stages'], '1,2,3,4,5,6,7,8');
      expect(
        request.url.queryParameters['available_before'],
        before.toIso8601String(),
      );

      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'id': 100,
              'object': 'assignment',
              'data': {
                'subject_id': 1,
                'subject_type': 'radical',
                'srs_stage': 1,
                'available_at': '2026-06-15T01:00:00.000Z',
              },
            },
            {
              'id': 101,
              'object': 'assignment',
              'data': {
                'subject_id': 2,
                'subject_type': 'kanji',
                'srs_stage': 6,
                'available_at': '2026-06-15T08:00:00.000Z',
              },
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

    final assignments = await client.getUpcomingReviewAssignments(
      before: before,
    );

    expect(assignments, hasLength(2));
    expect(assignments[0].srsStage, 1);
    expect(assignments[0].availableAt, DateTime.utc(2026, 6, 15, 1));
    expect(assignments[1].srsStage, 6);
    expect(assignments[1].availableAt, DateTime.utc(2026, 6, 15, 8));
  });

  test('parses an assignment without an available_at', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'pages': {'next_url': null},
          'data': [
            {
              'id': 100,
              'object': 'assignment',
              'data': {
                'subject_id': 1,
                'subject_type': 'radical',
                'srs_stage': 9,
              },
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

    final assignments = await client.getReviewAssignments();

    expect(assignments[0].availableAt, isNull);
  });
}
