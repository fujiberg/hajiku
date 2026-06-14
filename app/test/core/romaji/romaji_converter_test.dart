import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/romaji/romaji_converter.dart';

void main() {
  group('basic syllables', () {
    test('plain consonant + vowel', () {
      expect(RomajiConverter.convert('ka').kana, 'か');
      expect(RomajiConverter.convert('su').kana, 'す');
    });

    test('alternate spellings', () {
      expect(RomajiConverter.convert('shi').kana, 'し');
      expect(RomajiConverter.convert('si').kana, 'し');
    });
  });

  group('youon', () {
    test('palatalized combinations', () {
      expect(RomajiConverter.convert('kya').kana, 'きゃ');
      expect(RomajiConverter.convert('sha').kana, 'しゃ');
    });
  });

  group('sokuon', () {
    test('doubled consonants produce small tsu', () {
      expect(RomajiConverter.convert('tte').kana, 'って');
      expect(RomajiConverter.convert('kka').kana, 'っか');
      expect(RomajiConverter.convert('ssa').kana, 'っさ');
    });
  });

  group('trailing n', () {
    test('lone trailing n is pending, not yet ん', () {
      final result = RomajiConverter.convert('n');
      expect(result.kana, 'n');
      expect(result.tokens, hasLength(1));
      expect(result.tokens.single.isPending, isTrue);
    });

    test('n followed by a vowel forms a な-row mora', () {
      expect(RomajiConverter.convert('na').kana, 'な');
    });

    test('n followed by a non-extending consonant resolves to ん', () {
      final result = RomajiConverter.convert('nk');
      expect(result.kana, 'んk');
      expect(result.tokens, hasLength(2));
      expect(result.tokens[0].isPending, isFalse);
      expect(result.tokens[1].isPending, isTrue);
    });

    test('doubled n followed by a vowel', () {
      expect(RomajiConverter.convert('nna').kana, 'んな');
    });
  });

  group('isFinal eager resolution', () {
    test('lone trailing n resolves to ん', () {
      final result = RomajiConverter.convert('n', isFinal: true);
      expect(result.kana, 'ん');
      expect(result.tokens.single.isPending, isFalse);
    });

    test('word ending in n resolves its final mora', () {
      expect(RomajiConverter.convert('kon', isFinal: true).kana, 'こん');
    });

    test('a lone pending consonant with no value stays literal', () {
      final result = RomajiConverter.convert('k', isFinal: true);
      expect(result.kana, 'k');
      expect(result.tokens.single.isPending, isTrue);
    });
  });

  group('pass-through', () {
    test('unmapped characters are kept as-is', () {
      expect(RomajiConverter.convert('5').kana, '5');
      expect(RomajiConverter.convert('ka5ku').kana, 'か5く');
    });
  });

  group('full words', () {
    test('konnichiwa', () {
      expect(RomajiConverter.convert('konnichiwa').kana, 'こんにちわ');
    });

    test('gakkou', () {
      expect(RomajiConverter.convert('gakkou').kana, 'がっこう');
    });
  });
}
