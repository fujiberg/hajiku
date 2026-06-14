/// User-configurable preferences for lessons and reviews.
class AppSettings {
  const AppSettings({
    this.lessonsPerSession = defaultLessonsPerSession,
    this.reviewsPerSession = defaultReviewsPerSession,
    this.hapticFeedbackEnabled = true,
    this.autoAdvanceEnabled = false,
    this.vocabAudioEnabled = true,
  });

  static const defaultLessonsPerSession = 5;
  static const defaultReviewsPerSession = 10;

  /// Number of lessons presented in a single session.
  final int lessonsPerSession;

  /// Number of reviews presented in a single session.
  final int reviewsPerSession;

  /// Whether to vibrate on correct (short buzz) and incorrect (long buzz)
  /// answers.
  final bool hapticFeedbackEnabled;

  /// Whether to automatically continue to the next question after a
  /// correct answer.
  final bool autoAdvanceEnabled;

  /// Whether to play the audio for vocabulary items after answering.
  final bool vocabAudioEnabled;

  AppSettings copyWith({
    int? lessonsPerSession,
    int? reviewsPerSession,
    bool? hapticFeedbackEnabled,
    bool? autoAdvanceEnabled,
    bool? vocabAudioEnabled,
  }) {
    return AppSettings(
      lessonsPerSession: lessonsPerSession ?? this.lessonsPerSession,
      reviewsPerSession: reviewsPerSession ?? this.reviewsPerSession,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      autoAdvanceEnabled: autoAdvanceEnabled ?? this.autoAdvanceEnabled,
      vocabAudioEnabled: vocabAudioEnabled ?? this.vocabAudioEnabled,
    );
  }
}
