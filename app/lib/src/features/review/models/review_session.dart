import '../../../core/wanikani/models/wanikani_subject.dart';

/// The two kinds of question asked for a subject during a review.
enum ReviewQuizType { meaning, reading }

/// Display label for a [ReviewQuizType].
extension ReviewQuizTypeLabel on ReviewQuizType {
  String get label => switch (this) {
    ReviewQuizType.meaning => 'Meaning',
    ReviewQuizType.reading => 'Reading',
  };
}

/// Tracks one subject's progress through a review session. Shared by
/// reference across the [ReviewQuiz] entries for that subject, so that
/// answering one quiz updates the other.
class ReviewItem {
  ReviewItem({required this.assignmentId, required this.subject});

  final int assignmentId;
  final WaniKaniSubject subject;

  int incorrectMeaningAnswers = 0;
  int incorrectReadingAnswers = 0;
  final Set<ReviewQuizType> completedTypes = {};

  /// The quiz types this subject must answer correctly to be done. Radicals
  /// have no readings, so only a meaning quiz is required for them.
  Set<ReviewQuizType> get requiredTypes => {
    ReviewQuizType.meaning,
    if (subject.readings.isNotEmpty) ReviewQuizType.reading,
  };

  bool get isComplete => completedTypes.containsAll(requiredTypes);
}

/// A single question in the review queue.
class ReviewQuiz {
  const ReviewQuiz({required this.item, required this.type});

  final ReviewItem item;
  final ReviewQuizType type;
}

/// Feedback shown for the current quiz after the user submits an answer,
/// before they move on to the next one.
class ReviewAnswerFeedback {
  const ReviewAnswerFeedback({required this.correct});

  final bool correct;
}

/// State of an in-progress (or finished) review session.
class ReviewSessionState {
  const ReviewSessionState({
    required this.queue,
    required this.initialQueue,
    required this.totalItems,
    required this.completedItems,
    this.feedback,
  });

  /// Remaining quizzes, in the order they'll be asked. Quizzes answered
  /// incorrectly are re-queued at a random later position to be retried.
  final List<ReviewQuiz> queue;

  /// The shuffled queue as it was at the start of the session, before any
  /// answers or retries. Fixed for the lifetime of the session; used to lay
  /// out a progress overview in the order items will be encountered.
  final List<ReviewQuiz> initialQueue;

  /// The number of distinct subjects in this session.
  final int totalItems;

  /// The number of subjects answered correctly across all required quiz
  /// types.
  final int completedItems;

  /// Feedback for the quiz at the front of [queue], or `null` if it hasn't
  /// been answered yet.
  final ReviewAnswerFeedback? feedback;

  ReviewQuiz? get current => queue.isEmpty ? null : queue.first;

  bool get isFinished => queue.isEmpty;

  ReviewSessionState copyWith({
    List<ReviewQuiz>? queue,
    int? completedItems,
    ReviewAnswerFeedback? feedback,
    bool clearFeedback = false,
  }) {
    return ReviewSessionState(
      queue: queue ?? this.queue,
      initialQueue: initialQueue,
      totalItems: totalItems,
      completedItems: completedItems ?? this.completedItems,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
    );
  }
}
