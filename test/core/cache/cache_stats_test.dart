import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/cache/cache_stats.dart';
import 'package:hajiku/src/core/cache/cache_stats_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('derived totals combine the raw counters', () {
    const stats = CacheStats(
      revalidated: 3,
      fetched: 5,
      uncacheable: 2,
      servedFromCache: 10,
    );

    expect(stats.cacheHits, 13); // revalidated + servedFromCache
    expect(stats.networkRequests, 10); // revalidated + fetched + uncacheable
  });

  test('recorder accumulates and persists, merging stored counts', () async {
    final store = CacheStatsStore();
    await store.write(const CacheStats(fetched: 4));

    final recorder = CacheStatsRecorder(store: store);
    // Increment before the persisted load has necessarily completed.
    recorder.recordFetched();
    recorder.recordRevalidated();
    recorder.recordServedFromCache(7);

    // Let the async load+merge settle.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(recorder.value.fetched, 5, reason: '4 stored + 1 recorded');
    expect(recorder.value.revalidated, 1);
    expect(recorder.value.servedFromCache, 7);

    // A fresh recorder sees the persisted total.
    final reloaded = CacheStatsRecorder(store: store);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(reloaded.value.fetched, 5);
    expect(reloaded.value.servedFromCache, 7);
  });

  test('reset clears the counters in memory and on disk', () async {
    final store = CacheStatsStore();
    final recorder = CacheStatsRecorder(store: store);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    recorder.recordFetched();
    recorder.recordServedFromCache(3);

    await recorder.reset();

    expect(recorder.value, const CacheStats());
    expect(await store.read(), const CacheStats());
  });

  test('recordServedFromCache ignores non-positive counts', () async {
    final recorder = CacheStatsRecorder(store: CacheStatsStore());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    recorder.recordServedFromCache(0);
    expect(recorder.value.servedFromCache, 0);
  });
}
