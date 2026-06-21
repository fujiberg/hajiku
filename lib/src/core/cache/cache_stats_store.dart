import 'package:shared_preferences/shared_preferences.dart';

import 'cache_stats.dart';

/// Persists [CacheStats] on-device via `shared_preferences`, so cache
/// performance can be observed across launches.
class CacheStatsStore {
  CacheStatsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _revalidatedKey = 'cache_stats_revalidated';
  static const _fetchedKey = 'cache_stats_fetched';
  static const _uncacheableKey = 'cache_stats_uncacheable';
  static const _servedFromCacheKey = 'cache_stats_served_from_cache';

  final SharedPreferencesAsync _preferences;

  Future<CacheStats> read() async {
    return CacheStats(
      revalidated: await _preferences.getInt(_revalidatedKey) ?? 0,
      fetched: await _preferences.getInt(_fetchedKey) ?? 0,
      uncacheable: await _preferences.getInt(_uncacheableKey) ?? 0,
      servedFromCache: await _preferences.getInt(_servedFromCacheKey) ?? 0,
    );
  }

  Future<void> write(CacheStats stats) async {
    await _preferences.setInt(_revalidatedKey, stats.revalidated);
    await _preferences.setInt(_fetchedKey, stats.fetched);
    await _preferences.setInt(_uncacheableKey, stats.uncacheable);
    await _preferences.setInt(_servedFromCacheKey, stats.servedFromCache);
  }

  Future<void> clear() async {
    await _preferences.remove(_revalidatedKey);
    await _preferences.remove(_fetchedKey);
    await _preferences.remove(_uncacheableKey);
    await _preferences.remove(_servedFromCacheKey);
  }
}
