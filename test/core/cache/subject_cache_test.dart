import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/cache/subject_cache.dart';
import 'package:hajiku/src/core/wanikani/models/wanikani_subject.dart';

void main() {
  late Directory dir;
  late SubjectCache cache;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('subject_cache_test');
    cache = SubjectCache(directory: dir);
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  WaniKaniSubject subject(int id, String characters) {
    return WaniKaniSubject.fromJson({
      'id': id,
      'object': 'radical',
      'data': {
        'characters': characters,
        'slug': 'r$id',
        'meanings': [
          {'meaning': 'M$id', 'primary': true, 'accepted_answer': true},
        ],
        'auxiliary_meanings': <Object>[],
      },
    });
  }

  test('stores and retrieves subjects by id', () async {
    await cache.putAll([subject(1, '一'), subject(2, '二')]);

    final result = await cache.getMany([1, 2, 3]);

    expect(result.keys, unorderedEquals([1, 2]));
    expect(result[1]!.displayText, '一');
    expect(result[2]!.displayText, '二');
    expect(result.containsKey(3), isFalse, reason: 'id 3 was never cached');
  });

  test('getMany on an empty cache returns nothing', () async {
    expect(await cache.getMany([1, 2]), isEmpty);
  });

  test('syncedAt round-trips and starts null', () async {
    expect(await cache.syncedAt(), isNull);

    final now = DateTime.utc(2026, 6, 20, 9, 30);
    await cache.setSyncedAt(now);

    expect(await cache.syncedAt(), now);
  });

  test('count reflects the number of cached subjects', () async {
    expect(await cache.count(), 0);
    await cache.putAll([subject(1, '一'), subject(2, '二')]);
    expect(await cache.count(), 2);
  });

  test('clear removes cached subjects and metadata', () async {
    await cache.putAll([subject(1, '一')]);
    await cache.setSyncedAt(DateTime.utc(2026, 6, 20));

    await cache.clear();

    expect(await cache.getMany([1]), isEmpty);
    expect(await cache.syncedAt(), isNull);
  });
}
