import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/cache/cache_paths.dart';
import 'package:hajiku/src/core/settings/settings_controller.dart';
import 'package:hajiku/src/core/wanikani/providers.dart';
import 'package:hajiku/src/core/wanikani/wanikani_api_client.dart';
import 'package:hajiku/src/features/lessons/lesson_session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late Directory cacheDir;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    cacheDir = Directory.systemTemp.createTempSync('lesson_controller_test');
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  const radicalAssignment = {
    'id': 100,
    'object': 'assignment',
    'data': {'subject_id': 1, 'subject_type': 'radical', 'srs_stage': 0},
  };

  const kanjiAssignment = {
    'id': 101,
    'object': 'assignment',
    'data': {'subject_id': 2, 'subject_type': 'kanji', 'srs_stage': 0},
  };

  const secondRadicalAssignment = {
    'id': 102,
    'object': 'assignment',
    'data': {'subject_id': 3, 'subject_type': 'radical', 'srs_stage': 0},
  };

  const radicalSubject = {
    'id': 1,
    'object': 'radical',
    'data': {
      'characters': '一',
      'slug': 'ground',
      'meanings': [
        {'meaning': 'Ground', 'primary': true, 'accepted_answer': true},
      ],
      'auxiliary_meanings': <Object>[],
    },
  };

  const kanjiSubject = {
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
  };

  const secondRadicalSubject = {
    'id': 3,
    'object': 'radical',
    'data': {
      'characters': '人',
      'slug': 'leaf',
      'meanings': [
        {'meaning': 'Leaf', 'primary': true, 'accepted_answer': true},
      ],
      'auxiliary_meanings': <Object>[],
    },
  };

  http.Response jsonResponse(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  ProviderContainer buildContainer({
    required List<Map<String, Object?>> assignments,
    required List<Map<String, Object?>> subjects,
  }) {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/v2/assignments') {
        expect(
          request.url.queryParameters['immediately_available_for_lessons'],
          'true',
        );
        return jsonResponse({
          'pages': {'next_url': null},
          'data': assignments,
        });
      }
      if (request.url.path == '/v2/subjects') {
        return jsonResponse({
          'pages': {'next_url': null},
          'data': subjects,
        });
      }
      throw StateError('Unexpected request to ${request.url}');
    });

    final container = ProviderContainer(
      overrides: [
        cacheDirectoryProvider.overrideWithValue(cacheDir),
        wanikaniApiClientProvider.overrideWithValue(
          WaniKaniApiClient(
            tokenProvider: () async => 'test-token',
            httpClient: mockClient,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-dispose session provider alive for the test's duration, as
    // the on-screen widget would; otherwise it can dispose between the await
    // on its future and the next read.
    container.listen(lessonSessionControllerProvider, (_, _) {});
    return container;
  }

  test('returns an empty session when no lessons are available', () async {
    final container = buildContainer(assignments: [], subjects: []);

    final session = await container.read(
      lessonSessionControllerProvider.future,
    );

    expect(session.items, isEmpty);
    expect(session.current, isNull);
  });

  test('builds the session from the first lessonsPerSession lessons, in '
      'the order returned by the API', () async {
    final container = buildContainer(
      assignments: [
        radicalAssignment,
        kanjiAssignment,
        secondRadicalAssignment,
      ],
      subjects: [radicalSubject, kanjiSubject, secondRadicalSubject],
    );
    await container.read(settingsControllerProvider.future);
    await container
        .read(settingsControllerProvider.notifier)
        .setLessonsPerSession(2);

    final session = await container.read(
      lessonSessionControllerProvider.future,
    );

    expect(session.items, hasLength(2));
    expect(session.items[0].assignmentId, 100);
    expect(session.items[1].assignmentId, 101);
    expect(session.currentIndex, 0);
    expect(session.isFirst, isTrue);
    expect(session.isLast, isFalse);
  });

  test('next and back move through the items and clamp at the ends', () async {
    final container = buildContainer(
      assignments: [radicalAssignment, kanjiAssignment],
      subjects: [radicalSubject, kanjiSubject],
    );
    await container.read(lessonSessionControllerProvider.future);
    final controller = container.read(lessonSessionControllerProvider.notifier);

    controller.back();
    var session = container.read(lessonSessionControllerProvider).value!;
    expect(session.currentIndex, 0, reason: 'cannot go before the first item');

    controller.next();
    session = container.read(lessonSessionControllerProvider).value!;
    expect(session.currentIndex, 1);
    expect(session.isLast, isTrue);

    controller.next();
    session = container.read(lessonSessionControllerProvider).value!;
    expect(session.currentIndex, 1, reason: 'cannot go past the last item');

    controller.back();
    session = container.read(lessonSessionControllerProvider).value!;
    expect(session.currentIndex, 0);
  });
}
