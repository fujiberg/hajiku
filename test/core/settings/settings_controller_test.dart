import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/settings/settings_controller.dart';
import 'package:hajiku/src/core/settings/settings_storage.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('build returns the persisted defaults', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(settingsControllerProvider.future);

    expect(settings.lessonsPerSession, 5);
    expect(settings.reviewsPerSession, 10);
    expect(settings.hapticFeedbackEnabled, isTrue);
  });

  test('setLessonsPerSession updates state and persists the value', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.future);

    await container
        .read(settingsControllerProvider.notifier)
        .setLessonsPerSession(8);

    expect(
      container.read(settingsControllerProvider).value?.lessonsPerSession,
      8,
    );
    final reloaded = await container.read(settingsStorageProvider).read();
    expect(reloaded.lessonsPerSession, 8);
  });

  test(
    'setHapticFeedbackEnabled updates state and persists the value',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .setHapticFeedbackEnabled(false);

      expect(
        container.read(settingsControllerProvider).value?.hapticFeedbackEnabled,
        isFalse,
      );
      final reloaded = await container.read(settingsStorageProvider).read();
      expect(reloaded.hapticFeedbackEnabled, isFalse);
    },
  );

  test(
    'setFlickKeyboardEnabled updates state and persists the value',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .setFlickKeyboardEnabled(false);

      expect(
        container.read(settingsControllerProvider).value?.flickKeyboardEnabled,
        isFalse,
      );
      final reloaded = await container.read(settingsStorageProvider).read();
      expect(reloaded.flickKeyboardEnabled, isFalse);
    },
  );

  test(
    'setFlickKeyboardSubmitEnabled updates state and persists the value',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(settingsControllerProvider.future);

      await container
          .read(settingsControllerProvider.notifier)
          .setFlickKeyboardSubmitEnabled(false);

      expect(
        container
            .read(settingsControllerProvider)
            .value
            ?.flickKeyboardSubmitEnabled,
        isFalse,
      );
      final reloaded = await container.read(settingsStorageProvider).read();
      expect(reloaded.flickKeyboardSubmitEnabled, isFalse);
    },
  );
}
