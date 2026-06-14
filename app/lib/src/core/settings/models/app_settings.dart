/// User-configurable preferences for lessons and reviews.
class AppSettings {
  const AppSettings({
    this.lessonsPerSession = defaultLessonsPerSession,
    this.reviewsPerSession = defaultReviewsPerSession,
    this.hapticFeedbackEnabled = true,
    this.autoAdvanceEnabled = false,
    this.vocabAudioEnabled = true,
    this.submitReviewResultsEnabled = true,
    this.keyboardSubmitEnabled = true,
    this.invalidInputHapticFeedbackEnabled = true,
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

  /// Whether completed review results are submitted to WaniKani.
  ///
  /// Disabling this is a temporary developer setting for testing the review
  /// flow against sample data without affecting WaniKani SRS progress.
  final bool submitReviewResultsEnabled;

  /// Whether pressing Enter/Done on the keyboard submits an answer.
  ///
  /// Disabling this requires tapping the Submit button instead, to avoid
  /// accidentally submitting an answer when reaching for backspace.
  final bool keyboardSubmitEnabled;

  /// Whether to vibrate when Submit is pressed with an invalid answer (for
  /// example, an empty input).
  final bool invalidInputHapticFeedbackEnabled;

  AppSettings copyWith({
    int? lessonsPerSession,
    int? reviewsPerSession,
    bool? hapticFeedbackEnabled,
    bool? autoAdvanceEnabled,
    bool? vocabAudioEnabled,
    bool? submitReviewResultsEnabled,
    bool? keyboardSubmitEnabled,
    bool? invalidInputHapticFeedbackEnabled,
  }) {
    return AppSettings(
      lessonsPerSession: lessonsPerSession ?? this.lessonsPerSession,
      reviewsPerSession: reviewsPerSession ?? this.reviewsPerSession,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      autoAdvanceEnabled: autoAdvanceEnabled ?? this.autoAdvanceEnabled,
      vocabAudioEnabled: vocabAudioEnabled ?? this.vocabAudioEnabled,
      submitReviewResultsEnabled:
          submitReviewResultsEnabled ?? this.submitReviewResultsEnabled,
      keyboardSubmitEnabled:
          keyboardSubmitEnabled ?? this.keyboardSubmitEnabled,
      invalidInputHapticFeedbackEnabled:
          invalidInputHapticFeedbackEnabled ??
          this.invalidInputHapticFeedbackEnabled,
    );
  }
}
