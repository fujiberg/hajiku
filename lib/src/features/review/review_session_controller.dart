import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/settings_controller.dart';
import '../../core/wanikani/providers.dart';
import '../../core/wanikani/wanikani_exception.dart';
import 'models/review_session.dart';

/// One-shot "seed" slot for starting a review session from a fixed,
/// already-fetched set of items (e.g. the lesson quiz) instead of fetching
/// due reviews from WaniKani. Set just before navigating to [ReviewScreen],
/// and consumed/cleared by [ReviewSessionController.build].
///
/// This is intentionally a plain static holder rather than a provider:
/// Riverpod disallows a provider from writing to another provider's state
/// while it is still building, which a consume-during-build pattern would
/// require.
abstract final class PendingLessonQuizItems {
  static List<ReviewItem>? _items;

  /// Seeds the next review session with [items].
  static void seed(List<ReviewItem> items) => _items = items;

  /// Returns the seeded items, if any, and clears them.
  static List<ReviewItem>? consume() {
    final items = _items;
    _items = null;
    return items;
  }
}

/// Drives a single review session: builds the initial quiz queue, checks
/// answers, and reports completed items back to WaniKani.
class ReviewSessionController extends AsyncNotifier<ReviewSessionState> {
  @override
  Future<ReviewSessionState> build() async {
    final seeded = PendingLessonQuizItems.consume();
    if (seeded != null) {
      if (seeded.isEmpty) {
        return const ReviewSessionState(
          queue: [],
          initialQueue: [],
          totalItems: 0,
          completedItems: 0,
        );
      }
      final queue = buildQuizQueue(seeded);
      return ReviewSessionState(
        queue: queue,
        initialQueue: List.of(queue),
        totalItems: seeded.length,
        completedItems: 0,
      );
    }

    final client = ref.watch(wanikaniApiClientProvider);
    final allAssignments = await client.getReviewAssignments();

    if (allAssignments.isEmpty) {
      return const ReviewSessionState(
        queue: [],
        initialQueue: [],
        totalItems: 0,
        completedItems: 0,
      );
    }

    final settings = await ref.watch(settingsControllerProvider.future);
    allAssignments.shuffle(Random());
    final assignments = allAssignments
        .take(settings.reviewsPerSession)
        .toList();

    final subjects = await client.getSubjects(
      assignments.map((a) => a.subjectId).toList(),
    );
    final subjectsById = {for (final subject in subjects) subject.id: subject};

    final items = <ReviewItem>[];
    for (final assignment in assignments) {
      final subject = subjectsById[assignment.subjectId];
      if (subject == null) continue;
      items.add(ReviewItem(assignmentId: assignment.id, subject: subject));
    }
    final queue = buildQuizQueue(items);

    return ReviewSessionState(
      queue: queue,
      initialQueue: List.of(queue),
      totalItems: items.length,
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

    state = AsyncData(
      session.copyWith(
        feedback: ReviewAnswerFeedback(correct: correct),
        hasCorrectAnswer: session.hasCorrectAnswer || correct,
      ),
    );
  }

  /// Advances past the current quiz's feedback. Quizzes answered
  /// incorrectly are re-queued at a random later position to be retried.
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
      // Re-queue at a random later position, but never immediately next, so
      // the user gets at least one other question before a retry.
      final retryQuiz = ReviewQuiz(item: quiz.item, type: quiz.type);
      final insertIndex = remaining.isEmpty
          ? 0
          : 1 + Random().nextInt(remaining.length);
      remaining.insert(insertIndex, retryQuiz);
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
