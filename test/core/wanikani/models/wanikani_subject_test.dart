import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/wanikani/models/wanikani_assignment.dart';
import 'package:hajiku/src/core/wanikani/models/wanikani_subject.dart';

void main() {
  test('toJson round-trips back through fromJson', () {
    final json = {
      'id': 42,
      'object': 'vocabulary',
      'data': {
        'characters': '一つ',
        'slug': 'one thing',
        'meanings': [
          {'meaning': 'One Thing', 'primary': true, 'accepted_answer': true},
        ],
        'auxiliary_meanings': [
          {'meaning': 'single', 'type': 'whitelist'},
          {'meaning': 'wrong', 'type': 'blacklist'},
        ],
        'readings': [
          {'reading': 'ひとつ', 'primary': true, 'accepted_answer': true},
        ],
        'meaning_mnemonic': 'meaning text',
        'reading_mnemonic': 'reading text',
        'context_sentences': [
          {'en': 'I want one thing.', 'ja': '一つ欲しい。'},
        ],
        'pronunciation_audios': [
          {
            'url': 'https://example.com/a.mp3',
            'content_type': 'audio/mpeg',
            'metadata': {'pronunciation': 'ひとつ', 'voice_actor_name': 'Kyoko'},
          },
        ],
      },
    };

    final subject = WaniKaniSubject.fromJson(json);
    final reparsed = WaniKaniSubject.fromJson(subject.toJson());

    expect(reparsed.id, 42);
    expect(reparsed.type, WaniKaniSubjectType.vocabulary);
    expect(reparsed.displayText, '一つ');
    expect(reparsed.acceptedMeanings, ['One Thing', 'single']);
    expect(reparsed.acceptedReadings, ['ひとつ']);
    expect(reparsed.meaningMnemonic, 'meaning text');
    expect(reparsed.readingMnemonic, 'reading text');
    expect(reparsed.contextSentences.single.japanese, '一つ欲しい。');
    expect(
      reparsed.pronunciationAudios.single.url,
      'https://example.com/a.mp3',
    );
    expect(reparsed.pronunciationAudios.single.voiceActorName, 'Kyoko');
  });

  test('toJson round-trips a kanji with typed readings', () {
    final json = {
      'id': 7,
      'object': 'kanji',
      'data': {
        'characters': '一',
        'slug': '一',
        'meanings': [
          {'meaning': 'One', 'primary': true, 'accepted_answer': true},
        ],
        'auxiliary_meanings': <Object>[],
        'readings': [
          {
            'reading': 'いち',
            'primary': true,
            'accepted_answer': true,
            'type': 'onyomi',
          },
          {
            'reading': 'ひと',
            'primary': false,
            'accepted_answer': true,
            'type': 'kunyomi',
          },
        ],
      },
    };

    final reparsed = WaniKaniSubject.fromJson(
      WaniKaniSubject.fromJson(json).toJson(),
    );

    expect(reparsed.readings, hasLength(2));
    expect(reparsed.readings[0].type, WaniKaniReadingType.onyomi);
    expect(reparsed.readings[1].type, WaniKaniReadingType.kunyomi);
  });
}
