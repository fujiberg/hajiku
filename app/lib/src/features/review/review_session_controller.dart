import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/wanikani/providers.dart';
import '../../core/wanikani/wanikani_exception.dart';
import 'models/review_session.dart';

/// Drives a single review session: builds the initial quiz queue, checks
/// answers, and reports completed items back to WaniKani.
class ReviewSessionController extends AsyncNotifier<ReviewSessionState> {
  @override
  Future<ReviewSessionState> build() async {
    final client = ref.watch(wanikaniApiClientProvider);
    final assignments = await client.getReviewAssignments();

    if (assignments.isEmpty) {
      return const ReviewSessionState(
        queue: [],
        totalItems: 0,
        completedItems: 0,
      );
    }

    final subjects = await client.getSubjects(
      assignments.map((a) => a.subjectId).toList(),
    );
    final subjectsById = {for (final subject in subjects) subject.id: subject};

    final queue = <ReviewQuiz>[];
    var itemCount = 0;
    for (final assignment in assignments) {
      final subject = subjectsById[assignment.subjectId];
      if (subject == null) continue;

      final item = ReviewItem(assignmentId: assignment.id, subject: subject);
      itemCount++;
      queue.add(ReviewQuiz(item: item, type: ReviewQuizType.meaning));
      if (subject.readings.isNotEmpty) {
        queue.add(ReviewQuiz(item: item, type: ReviewQuizType.reading));
      }
    }
    queue.shuffle(Random());

    return ReviewSessionState(
      queue: queue,
      totalItems: itemCount,
      completedItems: 0,
    );
  }

  /// Checks [input] against the current quiz and records the result as
  /// feedback. Does not advance the queue — call [next] once the user has
  /// seen the result.
  void submitAnswer(String input) {
    final session = state.value;
    if (session == null || session.feedback != null) return;

    final quiz = session.current;
    if (quiz == null) return;

    final normalized = input.trim();
    final correct = quiz.type == ReviewQuizType.meaning
        ? quiz.item.subject.acceptedMeanings
              .map((meaning) => meaning.toLowerCase())
              .contains(normalized.toLowerCase())
        : quiz.item.subject.acceptedReadings.contains(normalized);

    if (correct) {
      quiz.item.completedTypes.add(quiz.type);
    } else if (quiz.type == ReviewQuizType.meaning) {
      quiz.item.incorrectMeaningAnswers++;
    } else {
      quiz.item.incorrectReadingAnswers++;
    }

    final answer = quiz.type == ReviewQuizType.meaning
        ? quiz.item.subject.primaryMeaning
        : quiz.item.subject.primaryReading;

    state = AsyncData(
      session.copyWith(
        feedback: ReviewAnswerFeedback(correct: correct, answer: answer),
      ),
    );
  }

  /// Advances past the current quiz's feedback. Quizzes answered
  /// incorrectly are re-queued at the end to be retried.
  Future<void> next() async {
    final session = state.value;
    if (session == null || session.feedback == null) return;

    final quiz = session.queue.first;
    final remaining = session.queue.skip(1).toList();
    var completedItems = session.completedItems;
    final justCompleted = session.feedback!.correct && quiz.item.isComplete;

    if (session.feedback!.correct) {
      if (justCompleted) completedItems++;
    } else {
      remaining.add(ReviewQuiz(item: quiz.item, type: quiz.type));
    }

    state = AsyncData(
      session.copyWith(
        queue: remaining,
        completedItems: completedItems,
        clearFeedback: true,
      ),
    );

    if (justCompleted) {
      try {
        await _submitReview(quiz.item);
      } on WaniKaniException {
        // Reporting to WaniKani is best-effort: the local session has
        // already advanced and shouldn't be blocked by a failed sync.
      }
    }
  }

  Future<void> _submitReview(ReviewItem item) async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (!settings.submitReviewResultsEnabled) return;

    await ref
        .read(wanikaniApiClientProvider)
        .submitReview(
          assignmentId: item.assignmentId,
          incorrectMeaningAnswers: item.incorrectMeaningAnswers,
          incorrectReadingAnswers: item.incorrectReadingAnswers,
        );
  }
}

final reviewSessionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ReviewSessionController,
      ReviewSessionState
    >(ReviewSessionController.new);
