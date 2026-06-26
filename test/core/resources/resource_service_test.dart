import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/cache/audio_cache.dart';
import 'package:hajiku/src/core/cache/cache_stats.dart';
import 'package:hajiku/src/core/cache/cache_stats_store.dart';
import 'package:hajiku/src/core/cache/study_material_cache.dart';
import 'package:hajiku/src/core/cache/subject_cache.dart';
import 'package:hajiku/src/core/cache/svg_cache.dart';
import 'package:hajiku/src/core/connectivity/connectivity_service.dart';
import 'package:hajiku/src/core/resources/resource_service.dart';
import 'package:hajiku/src/core/settings/models/app_settings.dart';
import 'package:hajiku/src/core/wanikani/http_cache_store.dart';
import 'package:hajiku/src/core/wanikani/models/wanikani_subject.dart';
import 'package:hajiku/src/core/wanikani/wanikani_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeConnectivity extends ConnectivityService {
  _FakeConnectivity(this.wifi);
  final bool wifi;
  @override
  Future<bool> isWifi() async => wifi;
}

Map<String, dynamic> _subjectJson(int id, {List<String> audioUrls = const []}) {
  return {
    'id': id,
    'object': 'vocabulary',
    'data': {
      'characters': 'word$id',
      'slug': 'word$id',
      'meanings': [
        {'meaning': 'M$id', 'primary': true, 'accepted_answer': true},
      ],
      'auxiliary_meanings': <Object>[],
      'readings': [
        {'reading': 'よみ', 'primary': true, 'accepted_answer': true},
      ],
      'pronunciation_audios': [
        for (final url in audioUrls)
          {
            'url': url,
            'content_type': 'audio/mpeg',
            'metadata': {'pronunciation': 'よみ', 'voice_actor_name': 'Kyoko'},
          },
      ],
    },
  };
}

void main() {
  late Directory dir;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    dir = Directory.systemTemp.createTempSync('resource_service_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  http.Response jsonResponse(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  ResourceService build({
    required http.Client httpClient,
    AppSettings settings = const AppSettings(),
    bool wifi = true,
    ValueNotifier<AudioDownloadProgress>? progress,
  }) {
    return ResourceService(
      client: WaniKaniApiClient(
        tokenProvider: () async => 'test-token',
        httpClient: httpClient,
      ),
      subjectCache: SubjectCache(directory: dir),
      studyMaterialCache: StudyMaterialCache(directory: dir),
      audioCache: AudioCache(directory: dir, httpClient: httpClient),
      svgCache: SvgCache(directory: dir, httpClient: httpClient),
      connectivity: _FakeConnectivity(wifi),
      httpCacheStore: InMemoryHttpCacheStore(),
      statsRecorder: CacheStatsRecorder(store: CacheStatsStore()),
      settingsReader: () async => settings,
      audioProgress: progress ?? ValueNotifier(const AudioDownloadProgress()),
    );
  }

  test('subjectsFor fetches missing subjects and caches them', () async {
    var subjectRequests = 0;
    final service = build(
      httpClient: MockClient((request) async {
        if (request.url.path == '/v2/subjects') {
          subjectRequests++;
          final ids = request.url.queryParameters['ids']!
              .split(',')
              .map(int.parse);
          return jsonResponse({
            'pages': {'next_url': null},
            'data': [for (final id in ids) _subjectJson(id)],
          });
        }
        throw StateError('unexpected ${request.url}');
      }),
    );

    final first = await service.subjectsFor([1, 2]);
    expect(first.map((s) => s.id), [1, 2]);
    expect(subjectRequests, 1);

    // Second call is served from cache; only a revalidation (updated_after)
    // request is made, returning nothing new.
    final second = await service.subjectsFor([1, 2]);
    expect(second.map((s) => s.id), [1, 2]);
    expect(subjectRequests, 2);
  });

  test('subjectsFor with revalidate:false makes no network call when '
      'everything is cached', () async {
    var subjectRequests = 0;
    final service = build(
      httpClient: MockClient((request) async {
        subjectRequests++;
        final ids = request.url.queryParameters['ids']!
            .split(',')
            .map(int.parse);
        return jsonResponse({
          'pages': {'next_url': null},
          'data': [for (final id in ids) _subjectJson(id)],
        });
      }),
    );

    await service.subjectsFor([1]);
    final before = subjectRequests;

    final cached = await service.subjectsFor([1], revalidate: false);
    expect(cached.single.id, 1);
    expect(subjectRequests, before, reason: 'no request when fully cached');
  });

  test('revalidation passes updated_after for cached subjects', () async {
    String? sawUpdatedAfter;
    final service = build(
      httpClient: MockClient((request) async {
        sawUpdatedAfter = request.url.queryParameters['updated_after'];
        final idsParam = request.url.queryParameters['ids']!;
        final ids = idsParam.split(',').map(int.parse);
        final isRevalidation = sawUpdatedAfter != null;
        return jsonResponse({
          'pages': {'next_url': null},
          'data': isRevalidation
              ? <Object>[]
              : [for (final id in ids) _subjectJson(id)],
        });
      }),
    );

    await service.subjectsFor([5]); // caches id 5
    sawUpdatedAfter = null;
    await service.subjectsFor([5]); // revalidates id 5

    expect(sawUpdatedAfter, isNotNull);
  });

  test('prepare caches subjects and prefetches mp3 audio', () async {
    const audioUrl = 'https://cdn.wanikani.com/audio/1.mp3';
    final progress = ValueNotifier(const AudioDownloadProgress());
    final service = build(
      progress: progress,
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/v2/assignments') {
          final forReview =
              request.url.queryParameters['immediately_available_for_review'] ==
              'true';
          return jsonResponse({
            'pages': {'next_url': null},
            'data': forReview
                ? [
                    {
                      'id': 100,
                      'object': 'assignment',
                      'data': {
                        'subject_id': 1,
                        'subject_type': 'vocabulary',
                        'srs_stage': 1,
                      },
                    },
                  ]
                : <Object>[],
          });
        }
        if (path == '/v2/study_materials') {
          return jsonResponse({
            'pages': {'next_url': null},
            'data': <Object>[],
          });
        }
        if (path == '/v2/subjects') {
          final ids = request.url.queryParameters['ids']!
              .split(',')
              .map(int.parse);
          return jsonResponse({
            'pages': {'next_url': null},
            'data': [
              for (final id in ids) _subjectJson(id, audioUrls: [audioUrl]),
            ],
          });
        }
        if (request.url.toString() == audioUrl) {
          return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
        }
        throw StateError('unexpected ${request.url}');
      }),
    );

    await service.prepare();
    // The audio prefetch is fire-and-forget; wait for it to settle.
    for (
      var i = 0;
      i < 100 && service.audioProgress.value.completed == 0;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    expect(service.audioProgress.value.total, 1);
    expect(service.audioProgress.value.completed, 1);
    expect(service.audioProgress.value.inProgress, isFalse);
  });

  group('resolveAudio', () {
    final audio = WaniKaniPronunciationAudio.fromJson({
      'url': 'https://cdn.wanikani.com/audio/9.mp3',
      'content_type': 'audio/mpeg',
      'metadata': {'pronunciation': 'a', 'voice_actor_name': 'Kyoko'},
    });

    test('downloads and returns a local file when caching is on', () async {
      final service = build(
        httpClient: MockClient(
          (request) async => http.Response.bytes(Uint8List.fromList([1]), 200),
        ),
      );

      final resource = await service.resolveAudio(audio, userInitiated: false);
      expect(resource?.filePath, isNotNull);
      expect(resource?.url, isNull);
    });

    test('streams the remote URL when caching is off', () async {
      final service = build(
        settings: const AppSettings(cacheVoiceData: false),
        httpClient: MockClient(
          (request) async => throw StateError('should not download'),
        ),
      );

      final resource = await service.resolveAudio(audio, userInitiated: false);
      expect(resource?.url, audio.url);
      expect(resource?.filePath, isNull);
    });

    test('suppresses auto-play on cellular when Wi-Fi-only', () async {
      final service = build(
        settings: const AppSettings(voiceWifiOnly: true),
        wifi: false,
        httpClient: MockClient(
          (request) async => throw StateError('should not download'),
        ),
      );

      final resource = await service.resolveAudio(audio, userInitiated: false);
      expect(resource, isNull);
    });

    test('still plays on cellular when the user taps play', () async {
      final service = build(
        settings: const AppSettings(voiceWifiOnly: true),
        wifi: false,
        httpClient: MockClient(
          (request) async => http.Response.bytes(Uint8List.fromList([1]), 200),
        ),
      );

      final resource = await service.resolveAudio(audio, userInitiated: true);
      expect(resource?.filePath, isNotNull);
    });
  });

  test('purge clears cached subjects and audio', () async {
    const audioUrl = 'https://cdn.wanikani.com/audio/1.mp3';
    final service = build(
      httpClient: MockClient((request) async {
        if (request.url.path == '/v2/subjects') {
          final ids = request.url.queryParameters['ids']!
              .split(',')
              .map(int.parse);
          return jsonResponse({
            'pages': {'next_url': null},
            'data': [
              for (final id in ids) _subjectJson(id, audioUrls: [audioUrl]),
            ],
          });
        }
        return http.Response.bytes(Uint8List.fromList([1]), 200);
      }),
    );

    await service.subjectsFor([1]);
    final audio = WaniKaniPronunciationAudio.fromJson({
      'url': audioUrl,
      'content_type': 'audio/mpeg',
      'metadata': {'pronunciation': 'a', 'voice_actor_name': 'Kyoko'},
    });
    await service.resolveAudio(audio, userInitiated: true);

    await service.purge();

    final cache = SubjectCache(directory: dir);
    expect(await cache.getMany([1]), isEmpty);
    expect(AudioCache(directory: dir).cached(audioUrl), isNull);
  });
}
