import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/settings/settings_controller.dart';
import 'package:hajiku/src/core/wanikani/providers.dart';
import 'package:hajiku/src/core/wanikani/wanikani_api_client.dart';
import 'package:hajiku/src/features/review/models/review_session.dart';
import 'package:hajiku/src/features/review/review_session_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  const radicalAssignment = {
    'id': 100,
    'object': 'assignment',
    'data': {'subject_id': 1, 'subject_type': 'radical', 'srs_stage': 1},
  };

  const kanjiAssignment = {
    'id': 101,
    'object': 'assignment',
    'data': {'subject_id': 2, 'subject_type': 'kanji', 'srs_stage': 1},
  };

  const secondRadicalAssignment = {
    'id': 102,
    'object': 'assignment',
    'data': {'subject_id': 3, 'subject_type': 'radical', 'srs_stage': 1},
  };

  const thirdRadicalAssignment = {
    'id': 103,
    'object': 'assignment',
    'data': {'subject_id': 4, 'subject_type': 'radical', 'srs_stage': 1},
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

  const thirdRadicalSubject = {
    'id': 4,
    'object': 'radical',
    'data': {
      'characters': '木',
      'slug': 'tree',
      'meanings': [
        {'meaning': 'Tree', 'primary': true, 'accepted_answer': true},
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
    void Function(http.Request request)? onReviewSubmitted,
  }) {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/v2/assignments') {
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
      if (request.url.path == '/v2/reviews') {
        onReviewSubmitted?.call(request);
        return http.Response('', 201);
      }
      throw StateError('Unexpected request to ${request.url}');
    });

    final container = ProviderContainer(
      overrides: [
        wanikaniApiClientProvider.overrideWithValue(
          WaniKaniApiClient(
            tokenProvider: () async => 'test-token',
            httpClient: mockClient,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'builds a queue with a reading quiz only for subjects that have readings',
    () async {
      final container = buildContainer(
        assignments: [radicalAssignment, kanjiAssignment],
        subjects: [radicalSubject, kanjiSubject],
      );

      final session = await container.read(
        reviewSessionControllerProvider.future,
      );

      expect(session.totalItems, 2);
      expect(session.queue, hasLength(3));
      expect(
        session.queue.where((q) => q.type == ReviewQuizType.reading),
        hasLength(1),
      );
    },
  );

  test('correct answer completes the item and submits a review', () async {
    http.Request? submittedRequest;
    final container = buildContainer(
      assignments: [radicalAssignment],
      subjects: [radicalSubject],
      onReviewSubmitted: (request) => submittedRequest = request,
    );
    await container.read(reviewSessionControllerProvider.future);
    final controller = container.read(reviewSessionControllerProvider.notifier);

    controller.submitAnswer('Ground');
    var session = container.read(reviewSessionControllerProvider).value!;
    expect(session.feedback?.correct, isTrue);

    await controller.next();
    session = container.read(reviewSessionControllerProvider).value!;

    expect(session.isFinished, isTrue);
    expect(session.completedItems, 1);
    expect(submittedRequest, isNotNull);
    expect(jsonDecode(submittedRequest!.body), {
      'review': {
        'assignment_id': 100,
        'incorrect_meaning_answers': 0,
        'incorrect_reading_answers': 0,
      },
    });
  });

  test('incorrect answer is retried before the item is completed', () async {
    http.Request? submittedRequest;
    final container = buildContainer(
      assignments: [radicalAssignment],
      subjects: [radicalSubject],
      onReviewSubmitted: (request) => submittedRequest = request,
    );
    await container.read(reviewSessionControllerProvider.future);
    final controller = container.read(reviewSessionControllerProvider.notifier);

    controller.submitAnswer('Floor');
    var session = container.read(reviewSessionControllerProvider).value!;
    expect(session.feedback?.correct, isFalse);
    expect(session.feedback?.answer, 'Ground');

    await controller.next();
    session = container.read(reviewSessionControllerProvider).value!;
    expect(session.isFinished, isFalse);
    expect(session.completedItems, 0);
    expect(submittedRequest, isNull);

    controller.submitAnswer('Ground');
    await controller.next();
    session = container.read(reviewSessionControllerProvider).value!;

    expect(session.isFinished, isTrue);
    expect(session.completedItems, 1);
    expect(jsonDecode(submittedRequest!.body), {
      'review': {
        'assignment_id': 100,
        'incorrect_meaning_answers': 1,
        'incorrect_reading_answers': 0,
      },
    });
  });

  test('does not submit a review when disabled in settings', () async {
    var reviewSubmitted = false;
    final container = buildContainer(
      assignments: [radicalAssignment],
      subjects: [radicalSubject],
      onReviewSubmitted: (_) => reviewSubmitted = true,
    );
    await container
        .read(settingsControllerProvider.notifier)
        .setSubmitReviewResultsEnabled(false);
    await container.read(reviewSessionControllerProvider.future);
    final controller = container.read(reviewSessionControllerProvider.notifier);

    controller.submitAnswer('Ground');
    await controller.next();

    expect(reviewSubmitted, isFalse);
  });

  test('initialQueue is a stable snapshot of the starting queue', () async {
    final container = buildContainer(
      assignments: [radicalAssignment, kanjiAssignment],
      subjects: [radicalSubject, kanjiSubject],
    );
    final initial = await container.read(
      reviewSessionControllerProvider.future,
    );
    final controller = container.read(reviewSessionControllerProvider.notifier);

    expect(initial.initialQueue, hasLength(3));
    expect(initial.initialQueue, initial.queue);

    controller.submitAnswer(
      initial.current!.type == ReviewQuizType.meaning
          ? (initial.current!.item.subject.acceptedMeanings.first)
          : (initial.current!.item.subject.acceptedReadings.first),
    );
    await controller.next();

    final session = container.read(reviewSessionControllerProvider).value!;
    expect(session.initialQueue, initial.initialQueue);
  });

  test('an incorrect answer is re-queued at a random later position, never '
      'immediately next', () async {
    final container = buildContainer(
      assignments: [radicalAssignment, secondRadicalAssignment],
      subjects: [radicalSubject, secondRadicalSubject],
    );
    var session = await container.read(reviewSessionControllerProvider.future);
    final controller = container.read(reviewSessionControllerProvider.notifier);
    final mistakenItem = session.current!.item;

    controller.submitAnswer('wrong answer');
    await controller.next();
    session = container.read(reviewSessionControllerProvider).value!;

    expect(session.isFinished, isFalse);
    expect(session.queue, hasLength(2));
    expect(session.queue.first.item, isNot(mistakenItem));
    expect(session.queue.last.item, mistakenItem);
  });

  test('limits the session to the configured reviewsPerSession', () async {
    final container = buildContainer(
      assignments: [
        radicalAssignment,
        secondRadicalAssignment,
        thirdRadicalAssignment,
      ],
      subjects: [radicalSubject, secondRadicalSubject, thirdRadicalSubject],
    );
    await container
        .read(settingsControllerProvider.notifier)
        .setReviewsPerSession(2);

    final session = await container.read(
      reviewSessionControllerProvider.future,
    );

    expect(session.totalItems, 2);
    expect(session.queue, hasLength(2));
    expect(session.initialQueue, hasLength(2));
  });
}
