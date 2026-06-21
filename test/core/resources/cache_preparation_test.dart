import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/cache/cache_paths.dart';
import 'package:hajiku/src/core/resources/resource_providers.dart';
import 'package:hajiku/src/core/wanikani/providers.dart';
import 'package:hajiku/src/core/wanikani/wanikani_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late Directory cacheDir;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    cacheDir = Directory.systemTemp.createTempSync('home_prep_test');
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  test('re-runs preparation and re-downloads subjects after a purge', () async {
    var subjectRequests = 0;
    final mock = MockClient((request) async {
      http.Response json(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

      if (request.url.path == '/v2/assignments') {
        final forReview =
            request.url.queryParameters['immediately_available_for_review'] ==
            'true';
        return json({
          'pages': {'next_url': null},
          'data': forReview
              ? [
                  {
                    'id': 100,
                    'object': 'assignment',
                    'data': {
                      'subject_id': 1,
                      'subject_type': 'radical',
                      'srs_stage': 1,
                    },
                  },
                ]
              : <Object>[],
        });
      }
      if (request.url.path == '/v2/subjects') {
        subjectRequests++;
        return json({
          'pages': {'next_url': null},
          'data': [
            {
              'id': 1,
              'object': 'radical',
              'data': {
                'characters': '一',
                'slug': 'ground',
                'meanings': [
                  {
                    'meaning': 'Ground',
                    'primary': true,
                    'accepted_answer': true,
                  },
                ],
                'auxiliary_meanings': <Object>[],
              },
            },
          ],
        });
      }
      throw StateError('unexpected ${request.url}');
    });

    final container = ProviderContainer(
      overrides: [
        cacheDirectoryProvider.overrideWithValue(cacheDir),
        wanikaniApiClientProvider.overrideWithValue(
          WaniKaniApiClient(
            tokenProvider: () async => 'test-token',
            httpClient: mock,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Stand in for the home screen keeping the provider alive.
    container.listen(cachePreparationProvider, (_, _) {});

    await container.read(cachePreparationProvider.future);
    expect(subjectRequests, greaterThan(0));
    final afterFirst = subjectRequests;
    expect(await container.read(subjectCacheProvider).count(), 1);

    await container.read(resourceServiceProvider).purge();
    expect(await container.read(subjectCacheProvider).count(), 0);

    container.invalidate(cachePreparationProvider);
    await container.read(cachePreparationProvider.future);

    expect(
      subjectRequests,
      greaterThan(afterFirst),
      reason: 'subjects should be re-downloaded after a purge',
    );
    expect(await container.read(subjectCacheProvider).count(), 1);

    // The settings display reflects the repopulated cache after re-download.
    final contents = await container.read(cacheContentsProvider.future);
    expect(contents.terms, 1);
  });
}
