import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_stats.dart';
import 'cache_stats_store.dart';

final cacheStatsStoreProvider = Provider<CacheStatsStore>(
  (ref) => CacheStatsStore(),
);

/// Shared, stable recorder of cache statistics. Kept in its own provider so it
/// survives the API client / resource service rebuilding, and so both can
/// report into the same running total.
final cacheStatsRecorderProvider = Provider<CacheStatsRecorder>((ref) {
  final recorder = CacheStatsRecorder(
    store: ref.watch(cacheStatsStoreProvider),
  );
  ref.onDispose(recorder.dispose);
  return recorder;
});
