import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/cache/cache_paths.dart';
import 'package:hajiku/src/core/resources/resource_providers.dart';
import 'package:hajiku/src/core/resources/resource_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late Directory cacheDir;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    cacheDir = Directory.systemTemp.createTempSync('cache_contents_test');
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  test('voices count refreshes as audio finishes downloading', () async {
    final container = ProviderContainer(
      overrides: [
        cacheDirectoryProvider.overrideWithValue(cacheDir),
        // Skip real preparation (no network) — we only exercise the audio
        // progress refresh path here.
        cachePreparationProvider.overrideWith((ref) async {}),
      ],
    );
    addTearDown(container.dispose);

    CacheContents? latest;
    container.listen(cacheContentsProvider, (_, next) {
      if (next.hasValue) latest = next.value;
    }, fireImmediately: true);

    await container.read(cacheContentsProvider.future);
    expect(latest?.voices, 0);

    // Simulate the background prefetch writing a clip, then ticking progress.
    final audioDir = Directory('${cacheDir.path}${Platform.pathSeparator}audio')
      ..createSync(recursive: true);
    File(
      '${audioDir.path}${Platform.pathSeparator}clip.mp3',
    ).writeAsBytesSync([1, 2, 3, 4]);

    container.read(audioDownloadProgressProvider).value =
        const AudioDownloadProgress(total: 1, completed: 1);

    // Let the invalidation/recompute settle.
    await container.read(cacheContentsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(latest?.voices, 1);
    expect(latest?.voiceBytes, 4);
  });
}
