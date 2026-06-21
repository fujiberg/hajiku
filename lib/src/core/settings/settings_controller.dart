import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'settings_storage.dart';

/// Holds the user's preferences, backed by [SettingsStorage].
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsStorageProvider).read();

  Future<void> setLessonsPerSession(int value) async {
    await ref.read(settingsStorageProvider).setLessonsPerSession(value);
    _update((settings) => settings.copyWith(lessonsPerSession: value));
  }

  Future<void> setReviewsPerSession(int value) async {
    await ref.read(settingsStorageProvider).setReviewsPerSession(value);
    _update((settings) => settings.copyWith(reviewsPerSession: value));
  }

  Future<void> setHapticFeedbackEnabled(bool value) async {
    await ref.read(settingsStorageProvider).setHapticFeedbackEnabled(value);
    _update((settings) => settings.copyWith(hapticFeedbackEnabled: value));
  }

  Future<void> setAutoAdvanceEnabled(bool value) async {
    await ref.read(settingsStorageProvider).setAutoAdvanceEnabled(value);
    _update((settings) => settings.copyWith(autoAdvanceEnabled: value));
  }

  Future<void> setVocabAudioEnabled(bool value) async {
    await ref.read(settingsStorageProvider).setVocabAudioEnabled(value);
    _update((settings) => settings.copyWith(vocabAudioEnabled: value));
  }

  Future<void> setSubmitReviewResultsEnabled(bool value) async {
    await ref
        .read(settingsStorageProvider)
        .setSubmitReviewResultsEnabled(value);
    _update((settings) => settings.copyWith(submitReviewResultsEnabled: value));
  }

  Future<void> setKeyboardSubmitEnabled(bool value) async {
    await ref.read(settingsStorageProvider).setKeyboardSubmitEnabled(value);
    _update((settings) => settings.copyWith(keyboardSubmitEnabled: value));
  }

  Future<void> setInvalidInputHapticFeedbackEnabled(bool value) async {
    await ref
        .read(settingsStorageProvider)
        .setInvalidInputHapticFeedbackEnabled(value);
    _update(
      (settings) => settings.copyWith(invalidInputHapticFeedbackEnabled: value),
    );
  }

  Future<void> setFlickKeyboardEnabled(bool value) async {
    await ref.read(settingsStorageProvider).setFlickKeyboardEnabled(value);
    _update((settings) => settings.copyWith(flickKeyboardEnabled: value));
  }

  Future<void> setFlickKeyboardSubmitEnabled(bool value) async {
    await ref
        .read(settingsStorageProvider)
        .setFlickKeyboardSubmitEnabled(value);
    _update((settings) => settings.copyWith(flickKeyboardSubmitEnabled: value));
  }

  Future<void> setCacheVoiceData(bool value) async {
    await ref.read(settingsStorageProvider).setCacheVoiceData(value);
    _update((settings) => settings.copyWith(cacheVoiceData: value));
  }

  Future<void> setVoiceWifiOnly(bool value) async {
    await ref.read(settingsStorageProvider).setVoiceWifiOnly(value);
    _update((settings) => settings.copyWith(voiceWifiOnly: value));
  }

  void _update(AppSettings Function(AppSettings settings) update) {
    final current = state.value;
    if (current != null) state = AsyncData(update(current));
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );
