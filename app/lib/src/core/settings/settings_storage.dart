import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_settings.dart';

/// Persists [AppSettings] on-device.
class SettingsStorage {
  SettingsStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _lessonsPerSessionKey = 'settings_lessons_per_session';
  static const _reviewsPerSessionKey = 'settings_reviews_per_session';
  static const _hapticFeedbackEnabledKey = 'settings_haptic_feedback_enabled';
  static const _autoAdvanceEnabledKey = 'settings_auto_advance_enabled';
  static const _vocabAudioEnabledKey = 'settings_vocab_audio_enabled';
  static const _submitReviewResultsEnabledKey =
      'settings_submit_review_results_enabled';
  static const _keyboardSubmitEnabledKey = 'settings_keyboard_submit_enabled';
  static const _invalidInputHapticFeedbackEnabledKey =
      'settings_invalid_input_haptic_feedback_enabled';

  final SharedPreferencesAsync _preferences;

  Future<AppSettings> read() async {
    const defaults = AppSettings();
    return AppSettings(
      lessonsPerSession:
          await _preferences.getInt(_lessonsPerSessionKey) ??
          defaults.lessonsPerSession,
      reviewsPerSession:
          await _preferences.getInt(_reviewsPerSessionKey) ??
          defaults.reviewsPerSession,
      hapticFeedbackEnabled:
          await _preferences.getBool(_hapticFeedbackEnabledKey) ??
          defaults.hapticFeedbackEnabled,
      autoAdvanceEnabled:
          await _preferences.getBool(_autoAdvanceEnabledKey) ??
          defaults.autoAdvanceEnabled,
      vocabAudioEnabled:
          await _preferences.getBool(_vocabAudioEnabledKey) ??
          defaults.vocabAudioEnabled,
      submitReviewResultsEnabled:
          await _preferences.getBool(_submitReviewResultsEnabledKey) ??
          defaults.submitReviewResultsEnabled,
      keyboardSubmitEnabled:
          await _preferences.getBool(_keyboardSubmitEnabledKey) ??
          defaults.keyboardSubmitEnabled,
      invalidInputHapticFeedbackEnabled:
          await _preferences.getBool(_invalidInputHapticFeedbackEnabledKey) ??
          defaults.invalidInputHapticFeedbackEnabled,
    );
  }

  Future<void> setLessonsPerSession(int value) =>
      _preferences.setInt(_lessonsPerSessionKey, value);

  Future<void> setReviewsPerSession(int value) =>
      _preferences.setInt(_reviewsPerSessionKey, value);

  Future<void> setHapticFeedbackEnabled(bool value) =>
      _preferences.setBool(_hapticFeedbackEnabledKey, value);

  Future<void> setAutoAdvanceEnabled(bool value) =>
      _preferences.setBool(_autoAdvanceEnabledKey, value);

  Future<void> setVocabAudioEnabled(bool value) =>
      _preferences.setBool(_vocabAudioEnabledKey, value);

  Future<void> setSubmitReviewResultsEnabled(bool value) =>
      _preferences.setBool(_submitReviewResultsEnabledKey, value);

  Future<void> setKeyboardSubmitEnabled(bool value) =>
      _preferences.setBool(_keyboardSubmitEnabledKey, value);

  Future<void> setInvalidInputHapticFeedbackEnabled(bool value) =>
      _preferences.setBool(_invalidInputHapticFeedbackEnabledKey, value);
}

final settingsStorageProvider = Provider<SettingsStorage>(
  (ref) => SettingsStorage(),
);
