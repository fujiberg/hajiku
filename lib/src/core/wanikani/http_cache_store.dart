/// A stored response from a conditional (`ETag`) GET: the raw response body
/// alongside the `ETag` used to revalidate it.
class CachedHttpResponse {
  const CachedHttpResponse({required this.etag, required this.body});

  final String etag;
  final String body;
}

/// Stores `ETag`/body pairs so [WaniKaniApiClient] can make conditional GET
/// requests (`If-None-Match`) and reuse the cached body on a `304 Not
/// Modified`. Keyed by request URL.
abstract class HttpCacheStore {
  Future<CachedHttpResponse?> read(String key);
  Future<void> write(String key, CachedHttpResponse value);
  Future<void> clear();
}

/// In-memory [HttpCacheStore]; the default when no persistent store is wired
/// in. Loses its contents when the process exits.
class InMemoryHttpCacheStore implements HttpCacheStore {
  final _entries = <String, CachedHttpResponse>{};

  @override
  Future<CachedHttpResponse?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, CachedHttpResponse value) async =>
      _entries[key] = value;

  @override
  Future<void> clear() async => _entries.clear();
}
