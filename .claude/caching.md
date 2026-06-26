# Local caching

How Hajiku caches WaniKani learning content on-device. The goal: cache as much
*learning information* (subjects and pronunciation audio) as possible, while
**never** caching live SRS state (which items are due, counts, forecasts).

## The resource service is the only entry point

All fetching of learning content goes through `ResourceService`
(`lib/src/core/resources/resource_service.dart`), exposed as
`resourceServiceProvider`. Screens and session controllers call it and never
touch the cache directly — caching is an implementation detail behind this
facade.

What still bypasses it (intentionally): the home screen's dashboard stats
(`wanikaniReviewCountProvider`, `wanikaniReviewForecastProvider`,
`wanikaniLevelProgressProvider`, `wanikaniUserProvider`, …). These are SRS
state and are always fetched fresh from `wanikaniApiClientProvider`.

## Study materials (user synonyms) — cached, subject-id-keyed

`StudyMaterialCache` (`lib/src/core/cache/study_material_cache.dart`) stores each
`WaniKaniStudyMaterial` as a `<subjectId>.json` file under a `study_materials/`
subdirectory. Keyed by subject id (not the material's own id) since that's how
the rest of the app looks them up.

`ResourceService.prepare()` fetches **all** study materials on first load
(`GET /study_materials`), then uses `updated_after` on subsequent runs to pick up
only server-side changes. The full set is kept in an in-memory
`Map<int, WaniKaniStudyMaterial>` (`_studyMaterials`) for synchronous access
during validation.

`ResourceService.studyMaterialFor(subjectId)` is a synchronous getter on that
in-memory map — safe to call during `submitAnswer` without awaiting.

`ResourceService.saveStudyMaterial(subjectId, synonyms)` POSTs (create) or PUTs
(update, using the material's stored `id`) to WaniKani, then updates both the
in-memory map and the on-disk cache so the change is immediately reflected in
answer validation and the UI.

Purge clears the cache directory and the in-memory map.

## Subjects (learning info) — cached, id-keyed

`SubjectCache` (`lib/src/core/cache/subject_cache.dart`) stores each subject as
a `<id>.json` file under the app cache directory. `WaniKaniSubject.toJson()`
round-trips with `fromJson`, so subjects serialize losslessly.

`ResourceService.subjectsFor(ids)`:

1. Serves any cached ids from disk.
2. Fetches never-seen ids in full (`GET /subjects?ids=…`).
3. When `revalidate` is true, revalidates already-cached ids with
   `GET /subjects?ids=…&updated_after=<syncedAt>` — usually an empty response,
   since subject data changes very rarely. `syncedAt` is then bumped.

Session controllers call `subjectsFor(ids, revalidate: false)` for an instant,
network-free load, because the home screen's preparation step has already
populated the cache (see below).

## Audio — cached as files

`AudioCache` (`lib/src/core/cache/audio_cache.dart`) stores each clip as a file
named after a hash of its URL, so a clip is downloaded at most once.

`ResourceService.resolveAudio(audio, userInitiated:)` returns an
`AudioResource` (a local file or a remote URL) or `null`, deciding based on
settings + connectivity:

- Already cached → always returns the local file.
- `cacheVoiceData` on → download + return the file.
- `cacheVoiceData` off → return the remote URL to stream (no storage used).
- `voiceWifiOnly` on, off Wi-Fi, **not** `userInitiated` → returns `null`
  (auto-play is suppressed). An explicit play-button tap (`userInitiated:
  true`) always tries, regardless of connection.

Consumers (`PronunciationAudioButton` with `userInitiated: true`, review
auto-play with `userInitiated: false`) turn the `AudioResource` into an
audioplayers `Source` via the `audio_resource_source.dart` extension. They know
nothing about caching or connectivity.

`ConnectivityService` (`lib/src/core/connectivity/`) wraps `connectivity_plus`
to answer "on Wi-Fi?"; subclass and override `isWifi()` in tests.

## Preparation gate + background download

`cachePreparationProvider` (in `resource_providers.dart`) runs
`ResourceService.prepare()`, which fetches the currently available review +
lesson assignments, ensures their subjects are cached, and kicks off
(fire-and-forget) a background download of their `audio/mpeg` clips. The home
screen shows a spinner in place of the Lessons/Reviews buttons until preparation
completes, so a session never starts before its learning content is cached.

Background audio progress is published via `audioDownloadProgressProvider` (a
stable `ValueNotifier<AudioDownloadProgress>`), surfaced as a small spinner
left of the settings button.

Preparation re-runs (via `ref.invalidate(cachePreparationProvider)`) when the
user returns from a session — picking up newly available items — and when they
clear the cache, which re-downloads everything needed. `cacheContentsProvider`
depends on `cachePreparationProvider`, so the settings "terms/voices cached"
counts refresh automatically as content is (re)cached. For the same "things may
have changed" reason, the result page has **no** "next reviews/lessons"
shortcut — the user always goes back through home, which re-prepares.

## HTTP-level caching and rate limits

`WaniKaniApiClient` adds two cross-cutting behaviors (see `api-wanikani.md`):

- **Conditional GETs** via `HttpCacheStore` (`http_cache_store.dart`): cacheable
  endpoints (`user`, `level_progressions`, `subjects`) send `If-None-Match` and
  reuse the cached body on a `304`. The store is shared via
  `httpCacheStoreProvider` and cleared on purge. It is in-memory (per session).
- **429 handling**: requests retry on `429 Too Many Requests`, waiting the
  `Retry-After` period (capped), so we back off cleanly instead of hammering.

## Statistics

`CacheStatsRecorder` (`cache_stats.dart`, shared via `cacheStatsRecorderProvider`)
keeps cumulative, persisted counters of cache performance, reported into from
two layers:

- The **API client** records per request: `revalidated` (a `304`), `fetched` (a
  cacheable `200`), or `uncacheable` (non-cacheable endpoints and writes).
- The **resource service** records `servedFromCache` — subjects returned from
  the on-device cache with no request.

The settings screen shows these (terms/voices cached come from
`cacheContentsProvider`, a snapshot of the cache directories; the counters
update live). Derived totals: **cache hits** = `revalidated + servedFromCache`,
**network requests** = `revalidated + fetched + uncacheable`. Counters persist
across launches (`CacheStatsStore`, `shared_preferences`) and reset on purge.

## Purge

Settings → "Clear cached data" calls `ResourceService.purge()`, which clears the
subject cache, audio cache, and HTTP cache store, resets the statistics, then
invalidates `cachePreparationProvider` so content is re-downloaded immediately.

## Cache directory

Resolved once in `main()` via `resolveCacheDirectory()` (under the platform
application-support directory) and supplied through `cacheDirectoryProvider`,
which is overridden with a temp directory in tests.
