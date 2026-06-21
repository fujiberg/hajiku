import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cache/audio_cache.dart';
import '../cache/cache_stats.dart';
import '../cache/subject_cache.dart';
import '../connectivity/connectivity_service.dart';
import '../settings/models/app_settings.dart';
import '../wanikani/http_cache_store.dart';
import '../wanikani/models/wanikani_assignment.dart';
import '../wanikani/models/wanikani_subject.dart';
import '../wanikani/wanikani_api_client.dart';

/// A playable pronunciation-audio source resolved by [ResourceService]:
/// either a local cached file or a remote URL. Callers turn it into an
/// `audioplayers` source without needing to know which one it is.
class AudioResource {
  const AudioResource.file(String this.filePath) : url = null;
  const AudioResource.remote(String this.url) : filePath = null;

  /// Absolute path to a cached file, or `null` if this is a remote source.
  final String? filePath;

  /// Remote URL to stream from, or `null` if this is a local file.
  final String? url;
}

/// Progress of the background audio prefetch, surfaced to the UI as a spinner.
@immutable
class AudioDownloadProgress {
  const AudioDownloadProgress({this.total = 0, this.completed = 0});

  final int total;
  final int completed;

  bool get inProgress => completed < total;

  @override
  bool operator ==(Object other) =>
      other is AudioDownloadProgress &&
      other.total == total &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(total, completed);
}

/// Single entry point through which the rest of the app fetches WaniKani
/// learning content, keeping caching an implementation detail.
///
/// Subjects (meanings, readings, mnemonics) and pronunciation audio are
/// cached on-device; the live SRS state (which items are due) is always
/// fetched fresh and never cached.
class ResourceService {
  ResourceService({
    required this._client,
    required this._subjectCache,
    required this._audioCache,
    required this._connectivity,
    required this._httpCacheStore,
    required this._statsRecorder,
    required this.settingsReader,
    required this._audioProgress,
  });

  final WaniKaniApiClient _client;
  final SubjectCache _subjectCache;
  final AudioCache _audioCache;
  final ConnectivityService _connectivity;
  final HttpCacheStore _httpCacheStore;
  final CacheStatsRecorder _statsRecorder;
  final ValueNotifier<AudioDownloadProgress> _audioProgress;

  /// Reads the current app settings (voice caching / Wi-Fi-only).
  final Future<AppSettings> Function() settingsReader;

  /// Background audio-prefetch progress, for the download indicator.
  ValueListenable<AudioDownloadProgress> get audioProgress => _audioProgress;

  /// Assignments with a review available right now (live SRS state).
  Future<List<WaniKaniAssignment>> getReviewAssignments() =>
      _client.getReviewAssignments();

  /// Assignments with a lesson available right now (live SRS state).
  Future<List<WaniKaniAssignment>> getLessonAssignments() =>
      _client.getLessonAssignments();

  /// Submits a completed review. Writes aren't cached; this just forwards to
  /// the API so callers go through a single facade.
  Future<void> submitReview({
    required int assignmentId,
    required int incorrectMeaningAnswers,
    required int incorrectReadingAnswers,
  }) => _client.submitReview(
    assignmentId: assignmentId,
    incorrectMeaningAnswers: incorrectMeaningAnswers,
    incorrectReadingAnswers: incorrectReadingAnswers,
  );

  /// Marks a lesson's assignment as started on WaniKani.
  Future<void> startAssignment(int assignmentId) =>
      _client.startAssignment(assignmentId);

  /// Returns the subjects for [ids], served from the on-device cache.
  ///
  /// Subjects not yet cached are fetched in full; when [revalidate] is set,
  /// already-cached subjects are checked for changes via `updated_after`
  /// (usually a no-op). Session screens pass `revalidate: false` for an
  /// instant, network-free load after the home screen has prepared the cache.
  Future<List<WaniKaniSubject>> subjectsFor(
    List<int> ids, {
    bool revalidate = true,
  }) async {
    if (ids.isEmpty) return const [];

    final byId = await _subjectCache.getMany(ids);
    _statsRecorder.recordServedFromCache(byId.length);
    final missing = [
      for (final id in ids)
        if (!byId.containsKey(id)) id,
    ];

    if (missing.isNotEmpty) {
      final fetched = await _client.getSubjects(missing);
      await _subjectCache.putAll(fetched);
      for (final subject in fetched) {
        byId[subject.id] = subject;
      }
    }

    if (revalidate) {
      final cachedIds = [
        for (final id in ids)
          if (!missing.contains(id)) id,
      ];
      final syncedAt = await _subjectCache.syncedAt();
      if (cachedIds.isNotEmpty && syncedAt != null) {
        final changed = await _client.getSubjects(
          cachedIds,
          updatedAfter: syncedAt,
        );
        if (changed.isNotEmpty) {
          await _subjectCache.putAll(changed);
          for (final subject in changed) {
            byId[subject.id] = subject;
          }
        }
      }
      await _subjectCache.setSyncedAt(DateTime.now());
    }

    return [for (final id in ids) ?byId[id]];
  }

  /// Prepares everything needed to start lessons and reviews: fetches the
  /// currently available assignments, ensures their subjects are cached, and
  /// kicks off (without awaiting) a background download of their audio.
  ///
  /// Completes once the learning content is ready — audio keeps downloading
  /// afterwards, surfaced via [audioProgress].
  Future<void> prepare() async {
    final results = await Future.wait([
      getReviewAssignments(),
      getLessonAssignments(),
    ]);
    final subjectIds = {
      for (final assignment in [...results[0], ...results[1]])
        assignment.subjectId,
    }.toList();

    final subjects = await subjectsFor(subjectIds);

    // Fire-and-forget: callers don't wait on audio.
    unawaited(_prefetchAudio(subjects));
  }

  Future<void> _prefetchAudio(List<WaniKaniSubject> subjects) async {
    final settings = await settingsReader();
    if (!settings.cacheVoiceData) return;
    if (settings.voiceWifiOnly && !await _connectivity.isWifi()) return;

    final urls = <String>{
      for (final subject in subjects)
        for (final audio in subject.pronunciationAudios)
          if (audio.contentType == 'audio/mpeg') audio.url,
    }.where((url) => _audioCache.cached(url) == null).toList();

    if (urls.isEmpty) return;

    var completed = 0;
    _audioProgress.value = AudioDownloadProgress(total: urls.length);
    for (final url in urls) {
      await _audioCache.download(url);
      completed++;
      _audioProgress.value = AudioDownloadProgress(
        total: urls.length,
        completed: completed,
      );
    }
  }

  /// Resolves a playable source for [audio], honoring the voice-caching and
  /// Wi-Fi-only settings. Returns `null` when playback should be suppressed
  /// (Wi-Fi-only, off Wi-Fi, and not [userInitiated]).
  ///
  /// A [userInitiated] request (an explicit tap on a play button) always
  /// tries to fetch, regardless of the connection.
  Future<AudioResource?> resolveAudio(
    WaniKaniPronunciationAudio audio, {
    required bool userInitiated,
  }) async {
    final url = audio.url;

    final cached = _audioCache.cached(url);
    if (cached != null) return AudioResource.file(cached.path);

    final settings = await settingsReader();
    if (settings.voiceWifiOnly &&
        !userInitiated &&
        !await _connectivity.isWifi()) {
      return null;
    }

    if (settings.cacheVoiceData) {
      final file = await _audioCache.getOrDownload(url);
      return file == null ? null : AudioResource.file(file.path);
    }

    return AudioResource.remote(url);
  }

  /// Deletes all cached learning content and audio, and resets the cache
  /// statistics.
  Future<void> purge() async {
    await _subjectCache.clear();
    await _audioCache.clear();
    await _httpCacheStore.clear();
    await _statsRecorder.reset();
    _audioProgress.value = const AudioDownloadProgress();
  }
}
