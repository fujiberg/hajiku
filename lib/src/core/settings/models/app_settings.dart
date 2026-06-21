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
    this.flickKeyboardEnabled = true,
    this.flickKeyboardSubmitEnabled = true,
    this.cacheVoiceData = true,
    this.voiceWifiOnly = false,
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

  /// Whether pressing Enter/Done on the system keyboard submits an answer.
  ///
  /// Disabling this requires tapping the Submit button instead, to avoid
  /// accidentally submitting an answer when reaching for backspace.
  final bool keyboardSubmitEnabled;

  /// Whether to vibrate when Submit is pressed with an invalid answer (for
  /// example, an empty input).
  final bool invalidInputHapticFeedbackEnabled;

  /// Whether to use the built-in flick kana keyboard for reading quizzes,
  /// instead of the system keyboard with romaji-to-kana input.
  final bool flickKeyboardEnabled;

  /// Whether tapping the flick keyboard's Submit key submits an answer.
  ///
  /// Separate from [keyboardSubmitEnabled] since the flick keyboard's
  /// Submit key is much larger and less prone to accidental taps than the
  /// system keyboard's Enter key.
  final bool flickKeyboardSubmitEnabled;

  /// Whether pronunciation audio is downloaded and stored on-device for
  /// offline playback. When off, audio is streamed from WaniKani on demand.
  final bool cacheVoiceData;

  /// Whether automatic voice playback/caching is restricted to Wi-Fi. When on
  /// and off Wi-Fi, audio is not played automatically — but an explicit tap on
  /// a play button still downloads and plays it.
  final bool voiceWifiOnly;

  AppSettings copyWith({
    int? lessonsPerSession,
    int? reviewsPerSession,
    bool? hapticFeedbackEnabled,
    bool? autoAdvanceEnabled,
    bool? vocabAudioEnabled,
    bool? submitReviewResultsEnabled,
    bool? keyboardSubmitEnabled,
    bool? invalidInputHapticFeedbackEnabled,
    bool? flickKeyboardEnabled,
    bool? flickKeyboardSubmitEnabled,
    bool? cacheVoiceData,
    bool? voiceWifiOnly,
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
      flickKeyboardEnabled: flickKeyboardEnabled ?? this.flickKeyboardEnabled,
      flickKeyboardSubmitEnabled:
          flickKeyboardSubmitEnabled ?? this.flickKeyboardSubmitEnabled,
      cacheVoiceData: cacheVoiceData ?? this.cacheVoiceData,
      voiceWifiOnly: voiceWifiOnly ?? this.voiceWifiOnly,
    );
  }
}
