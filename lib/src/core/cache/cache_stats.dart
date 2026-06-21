import 'package:flutter/foundation.dart';

import 'cache_stats_store.dart';

/// Cumulative counters describing how the cache has performed, persisted
/// across launches and reset when the cache is cleared.
///
/// The raw counters are request-level; the UI shows derived totals
/// ([cacheHits], [networkRequests]).
@immutable
class CacheStats {
  const CacheStats({
    this.revalidated = 0,
    this.fetched = 0,
    this.uncacheable = 0,
    this.servedFromCache = 0,
  });

  /// Conditional GETs that returned `304 Not Modified` — a round-trip was
  /// made, but the cached body was reused instead of re-downloaded.
  final int revalidated;

  /// Cacheable GETs that downloaded fresh data (`200`).
  final int fetched;

  /// Requests to endpoints that can't be cached (live SRS state, writes).
  final int uncacheable;

  /// Subjects served straight from the on-device cache, with no request.
  final int servedFromCache;

  /// Times the cache spared a download: revalidations plus subjects served
  /// locally.
  int get cacheHits => revalidated + servedFromCache;

  /// Total network requests actually sent.
  int get networkRequests => revalidated + fetched + uncacheable;

  CacheStats copyWith({
    int? revalidated,
    int? fetched,
    int? uncacheable,
    int? servedFromCache,
  }) {
    return CacheStats(
      revalidated: revalidated ?? this.revalidated,
      fetched: fetched ?? this.fetched,
      uncacheable: uncacheable ?? this.uncacheable,
      servedFromCache: servedFromCache ?? this.servedFromCache,
    );
  }

  /// Field-wise sum, used to merge persisted counts with in-memory ones.
  CacheStats operator +(CacheStats other) => CacheStats(
    revalidated: revalidated + other.revalidated,
    fetched: fetched + other.fetched,
    uncacheable: uncacheable + other.uncacheable,
    servedFromCache: servedFromCache + other.servedFromCache,
  );

  @override
  bool operator ==(Object other) =>
      other is CacheStats &&
      other.revalidated == revalidated &&
      other.fetched == fetched &&
      other.uncacheable == uncacheable &&
      other.servedFromCache == servedFromCache;

  @override
  int get hashCode =>
      Object.hash(revalidated, fetched, uncacheable, servedFromCache);
}

/// Collects [CacheStats] events from the API client and resource service,
/// keeping a live (and persisted) running total.
///
/// Increments made before the persisted counts finish loading are preserved:
/// nothing is written until the stored values have been merged in.
class CacheStatsRecorder {
  CacheStatsRecorder({required this._store}) {
    _load();
  }

  final CacheStatsStore _store;
  final ValueNotifier<CacheStats> _stats = ValueNotifier(const CacheStats());
  bool _loaded = false;

  /// Live running total, for the settings display.
  ValueListenable<CacheStats> get listenable => _stats;
  CacheStats get value => _stats.value;

  Future<void> _load() async {
    final persisted = await _store.read();
    _stats.value = persisted + _stats.value;
    _loaded = true;
    await _store.write(_stats.value);
  }

  void recordRevalidated() =>
      _update((s) => s.copyWith(revalidated: s.revalidated + 1));

  void recordFetched() => _update((s) => s.copyWith(fetched: s.fetched + 1));

  void recordUncacheable() =>
      _update((s) => s.copyWith(uncacheable: s.uncacheable + 1));

  void recordServedFromCache(int count) {
    if (count <= 0) return;
    _update((s) => s.copyWith(servedFromCache: s.servedFromCache + count));
  }

  /// Resets the counters to zero, in memory and on disk.
  Future<void> reset() async {
    _stats.value = const CacheStats();
    await _store.clear();
  }

  void dispose() => _stats.dispose();

  void _update(CacheStats Function(CacheStats) update) {
    _stats.value = update(_stats.value);
    // Don't persist until the stored counts have been merged in, to avoid
    // racing the initial load.
    if (_loaded) _store.write(_stats.value);
  }
}
