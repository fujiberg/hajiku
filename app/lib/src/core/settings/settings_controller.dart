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

  void _update(AppSettings Function(AppSettings settings) update) {
    final current = state.value;
    if (current != null) state = AsyncData(update(current));
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );
