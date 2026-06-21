import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/cache/audio_cache.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('audio_cache_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  const url = 'https://cdn.wanikani.com/audio/123.mp3';

  test('downloads a clip once and serves it from cache afterwards', () async {
    var requestCount = 0;
    final cache = AudioCache(
      directory: dir,
      httpClient: MockClient((request) async {
        requestCount++;
        expect(request.url.toString(), url);
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      }),
    );

    expect(cache.cached(url), isNull);

    final first = await cache.getOrDownload(url);
    expect(first, isNotNull);
    expect(await first!.readAsBytes(), [1, 2, 3]);
    expect(requestCount, 1);

    expect(cache.cached(url), isNotNull);
    final second = await cache.getOrDownload(url);
    expect(second!.path, first.path);
    expect(requestCount, 1, reason: 'second request is served from cache');
  });

  test('keeps the source extension for ogg clips', () async {
    const oggUrl = 'https://cdn.wanikani.com/audio/123.ogg';
    final cache = AudioCache(
      directory: dir,
      httpClient: MockClient(
        (request) async => http.Response.bytes(Uint8List.fromList([9]), 200),
      ),
    );

    final file = await cache.download(oggUrl);
    expect(file!.path, endsWith('.ogg'));
  });

  test('returns null when the download fails', () async {
    final cache = AudioCache(
      directory: dir,
      httpClient: MockClient((request) async => http.Response('', 404)),
    );

    expect(await cache.getOrDownload(url), isNull);
    expect(cache.cached(url), isNull);
  });

  test('usage reports the cached file count and total size', () async {
    final cache = AudioCache(
      directory: dir,
      httpClient: MockClient(
        (request) async =>
            http.Response.bytes(Uint8List.fromList([1, 2, 3, 4, 5]), 200),
      ),
    );

    expect(await cache.usage(), (count: 0, bytes: 0));

    await cache.download('https://cdn.wanikani.com/audio/a.mp3');
    await cache.download('https://cdn.wanikani.com/audio/b.mp3');

    expect(await cache.usage(), (count: 2, bytes: 10));
  });

  test('clear removes cached files', () async {
    final cache = AudioCache(
      directory: dir,
      httpClient: MockClient(
        (request) async => http.Response.bytes(Uint8List.fromList([1]), 200),
      ),
    );

    await cache.getOrDownload(url);
    expect(cache.cached(url), isNotNull);

    await cache.clear();
    expect(cache.cached(url), isNull);
  });
}
