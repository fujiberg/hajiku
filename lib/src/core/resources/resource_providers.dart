import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/audio_cache.dart';
import '../cache/cache_paths.dart';
import '../cache/cache_providers.dart';
import '../cache/subject_cache.dart';
import '../connectivity/connectivity_service.dart';
import '../settings/settings_controller.dart';
import '../wanikani/providers.dart';
import 'resource_service.dart';

final subjectCacheProvider = Provider<SubjectCache>(
  (ref) => SubjectCache(directory: ref.watch(cacheDirectoryProvider)),
);

final audioCacheProvider = Provider<AudioCache>(
  (ref) => AudioCache(directory: ref.watch(cacheDirectoryProvider)),
);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

/// Stable holder for background audio-download progress, watched by the
/// download indicator. Kept separate from [resourceServiceProvider] so it
/// survives that provider rebuilding (e.g. on a token change).
final audioDownloadProgressProvider =
    Provider<ValueNotifier<AudioDownloadProgress>>((ref) {
      final notifier = ValueNotifier(const AudioDownloadProgress());
      ref.onDispose(notifier.dispose);
      return notifier;
    });

/// Single facade for fetching WaniKani learning content, with caching handled
/// internally. See [ResourceService].
final resourceServiceProvider = Provider<ResourceService>((ref) {
  return ResourceService(
    client: ref.watch(wanikaniApiClientProvider),
    subjectCache: ref.watch(subjectCacheProvider),
    audioCache: ref.watch(audioCacheProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    httpCacheStore: ref.watch(httpCacheStoreProvider),
    statsRecorder: ref.watch(cacheStatsRecorderProvider),
    settingsReader: () => ref.read(settingsControllerProvider.future),
    audioProgress: ref.watch(audioDownloadProgressProvider),
  );
});

/// Downloads the learning content (subjects) needed to start the currently
/// available lessons and reviews, and kicks off a background download of their
/// audio. The home screen gates entry into sessions on this completing, and
/// re-runs it (via [Ref.invalidate]) whenever the user returns from a session
/// or clears the cache, since both can change what needs downloading.
final cachePreparationProvider = FutureProvider<void>((ref) async {
  await ref.watch(resourceServiceProvider).prepare();
});

/// The cache's current contents (terms and voices cached) for the settings
/// display. Re-reads after each [cachePreparationProvider] run — including the
/// re-download triggered by clearing the cache — so the counts stay current.
/// The cumulative request counters are read live from
/// [cacheStatsRecorderProvider] instead.
typedef CacheContents = ({int terms, int voices, int voiceBytes});

final cacheContentsProvider = FutureProvider<CacheContents>((ref) async {
  // Refresh whenever content is (re)cached: after preparation finishes (which
  // caches subjects), and as audio clips finish downloading in the background
  // afterwards. Audio prefetch is fire-and-forget, so without the progress
  // listener the voices count would stay stale until the next app launch.
  ref.watch(cachePreparationProvider);
  final audioProgress = ref.watch(audioDownloadProgressProvider);
  void onProgress() => ref.invalidateSelf();
  audioProgress.addListener(onProgress);
  ref.onDispose(() => audioProgress.removeListener(onProgress));

  final terms = await ref.watch(subjectCacheProvider).count();
  final audio = await ref.watch(audioCacheProvider).usage();
  return (terms: terms, voices: audio.count, voiceBytes: audio.bytes);
});
