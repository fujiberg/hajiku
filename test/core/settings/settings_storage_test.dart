import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/settings/models/app_settings.dart';
import 'package:hajiku/src/core/settings/settings_storage.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('read returns defaults when nothing is stored', () async {
    final storage = SettingsStorage();

    final settings = await storage.read();

    expect(settings.lessonsPerSession, AppSettings.defaultLessonsPerSession);
    expect(settings.reviewsPerSession, AppSettings.defaultReviewsPerSession);
    expect(settings.hapticFeedbackEnabled, isTrue);
    expect(settings.autoAdvanceEnabled, isFalse);
    expect(settings.vocabAudioEnabled, isTrue);
    expect(settings.flickKeyboardEnabled, isTrue);
    expect(settings.flickKeyboardSubmitEnabled, isTrue);
  });

  test('persisted values are returned on subsequent reads', () async {
    final storage = SettingsStorage();

    await storage.setLessonsPerSession(8);
    await storage.setReviewsPerSession(20);
    await storage.setHapticFeedbackEnabled(false);
    await storage.setAutoAdvanceEnabled(true);
    await storage.setVocabAudioEnabled(false);
    await storage.setFlickKeyboardEnabled(false);
    await storage.setFlickKeyboardSubmitEnabled(false);

    final settings = await storage.read();

    expect(settings.lessonsPerSession, 8);
    expect(settings.reviewsPerSession, 20);
    expect(settings.hapticFeedbackEnabled, isFalse);
    expect(settings.autoAdvanceEnabled, isTrue);
    expect(settings.vocabAudioEnabled, isFalse);
    expect(settings.flickKeyboardEnabled, isFalse);
    expect(settings.flickKeyboardSubmitEnabled, isFalse);
  });
}
