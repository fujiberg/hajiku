import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/widgets/flick_keyboard/flick_kana_layout.dart';

void main() {
  group('FlickKanaLayout.grid', () {
    test('is 4 rows x 5 columns', () {
      expect(FlickKanaLayout.grid, hasLength(4));
      for (final row in FlickKanaLayout.grid) {
        expect(row, hasLength(5));
      }
    });

    test('control cells are in the expected positions', () {
      final grid = FlickKanaLayout.grid;

      expect(grid[0][0], isA<FlickKanaModeToggleCell>());
      expect(grid[0][4], isA<FlickBackspaceCell>());

      expect(grid[1][0], isA<FlickCursorCell>());
      expect(
        (grid[1][0] as FlickCursorCell).direction,
        FlickCursorDirection.left,
      );
      expect(grid[1][4], isA<FlickCursorCell>());
      expect(
        (grid[1][4] as FlickCursorCell).direction,
        FlickCursorDirection.right,
      );

      expect(grid[2][0], isA<FlickEmptyCell>());
      expect(grid[2][4], isA<FlickSpaceCell>());

      expect(grid[3][0], isA<FlickCollapseCell>());
      expect(grid[3][1], isA<FlickModifierCell>());
      expect(grid[3][4], isA<FlickSubmitCell>());
    });

    test('center 3x4 block holds the gojuuon-row keys plus わ and 、', () {
      final grid = FlickKanaLayout.grid;

      const expectedCenters = [
        ['あ', 'か', 'さ'],
        ['た', 'な', 'は'],
        ['ま', 'や', 'ら'],
        [null, 'わ', '、'], // (3,1) is 小, the modifier key.
      ];

      for (var row = 0; row < 4; row++) {
        for (var col = 1; col <= 3; col++) {
          final cell = grid[row][col];
          final expected = expectedCenters[row][col - 1];
          if (expected == null) {
            expect(cell, isA<FlickModifierCell>());
          } else {
            expect(cell, isA<FlickKanaCell>());
            expect((cell as FlickKanaCell).data.center, expected);
          }
        }
      }
    });

    test('a-row keys: flick up/right/down/left give u/e/o/i', () {
      const cases = {
        'あ': ('あ', 'う', 'え', 'お', 'い'),
        'か': ('か', 'く', 'け', 'こ', 'き'),
        'さ': ('さ', 'す', 'せ', 'そ', 'し'),
        'た': ('た', 'つ', 'て', 'と', 'ち'),
        'な': ('な', 'ぬ', 'ね', 'の', 'に'),
        'は': ('は', 'ふ', 'へ', 'ほ', 'ひ'),
        'ま': ('ま', 'む', 'め', 'も', 'み'),
        'ら': ('ら', 'る', 'れ', 'ろ', 'り'),
      };

      for (final row in FlickKanaLayout.grid) {
        for (final cell in row) {
          if (cell is! FlickKanaCell) continue;
          final expected = cases[cell.data.center];
          if (expected == null) continue;
          final (center, up, right, down, left) = expected;
          expect(cell.data.center, center);
          expect(cell.data.up, up);
          expect(cell.data.right, right);
          expect(cell.data.down, down);
          expect(cell.data.left, left);
        }
      }
    });

    test('や has only center, up (ゆ) and down (よ)', () {
      final ya = FlickKanaLayout.grid[2][2] as FlickKanaCell;
      expect(ya.data.center, 'や');
      expect(ya.data.up, 'ゆ');
      expect(ya.data.down, 'よ');
      expect(ya.data.right, isNull);
      expect(ya.data.left, isNull);
    });

    test('わ has up=ん, right=ー, down=～, left=を', () {
      final wa = FlickKanaLayout.grid[3][2] as FlickKanaCell;
      expect(wa.data.center, 'わ');
      expect(wa.data.up, 'ん');
      expect(wa.data.right, 'ー');
      expect(wa.data.down, '～');
      expect(wa.data.left, 'を');
    });

    test('、 has up=！, right=。, left=？, down=null', () {
      final ten = FlickKanaLayout.grid[3][3] as FlickKanaCell;
      expect(ten.data.center, '、');
      expect(ten.data.up, '！');
      expect(ten.data.right, '。');
      expect(ten.data.left, '？');
      expect(ten.data.down, isNull);
    });
  });

  group('FlickKeyData.popupCandidates', () {
    test('returns all 5 candidates in cross order for あ', () {
      const data = FlickKeyData(
        center: 'あ',
        up: 'い',
        right: 'う',
        down: 'え',
        left: 'お',
      );
      expect(data.popupCandidates.toList(), [
        (FlickDirection.up, 'い'),
        (FlickDirection.left, 'お'),
        (null, 'あ'),
        (FlickDirection.right, 'う'),
        (FlickDirection.down, 'え'),
      ]);
    });

    test('omits missing directions for や', () {
      const data = FlickKeyData(center: 'や', right: 'ゆ', left: 'よ');
      expect(data.popupCandidates.toList(), [
        (FlickDirection.left, 'よ'),
        (null, 'や'),
        (FlickDirection.right, 'ゆ'),
      ]);
    });
  });

  group('FlickKeyData.cycleOrder', () {
    test('is gojuuon order for あ (left=i, up=u, right=e, down=o)', () {
      const data = FlickKeyData(
        center: 'あ',
        up: 'う',
        right: 'え',
        down: 'お',
        left: 'い',
      );
      expect(data.cycleOrder, ['あ', 'い', 'う', 'え', 'お']);
    });

    test('skips missing directions for や', () {
      const data = FlickKeyData(center: 'や', up: 'ゆ', down: 'よ');
      expect(data.cycleOrder, ['や', 'ゆ', 'よ']);
    });

    test('covers all 5 for わ', () {
      const data = FlickKeyData(
        center: 'わ',
        up: 'ん',
        right: 'ー',
        down: '～',
        left: 'を',
      );
      expect(data.cycleOrder, ['わ', 'を', 'ん', 'ー', '～']);
    });

    test('skips missing down for 、', () {
      const data = FlickKeyData(center: '、', up: '！', right: '。', left: '？');
      expect(data.cycleOrder, ['、', '？', '！', '。']);
    });
  });

  group('toKatakana / toHiragana', () {
    test('shifts hiragana to katakana', () {
      expect(toKatakana('あ'), 'ア');
      expect(toKatakana('ん'), 'ン');
      expect(toKatakana('を'), 'ヲ');
      expect(toKatakana('ゎ'), 'ヮ');
      expect(toKatakana('かきくけこ'), 'カキクケコ');
    });

    test('leaves non-hiragana characters unchanged', () {
      expect(toKatakana('ー'), 'ー');
      expect(toKatakana('～'), '～');
      expect(toKatakana('、。！？'), '、。！？');
      expect(toKatakana('abc'), 'abc');
    });

    test('toHiragana is the inverse of toKatakana', () {
      const hiragana = 'あいうえおかきくけこんをわゎ';
      expect(toHiragana(toKatakana(hiragana)), hiragana);
    });

    test('toHiragana leaves non-katakana characters unchanged', () {
      expect(toHiragana('ー'), 'ー');
      expect(toHiragana('～'), '～');
      expect(toHiragana('、。！？'), '、。！？');
    });
  });

  group('flickModifierCycle', () {
    test('k/s/t-row pairs round-trip in two steps', () {
      const pairs = ['かが', 'きぎ', 'くぐ', 'けげ', 'こご'];
      for (final pair in pairs) {
        final a = pair[0];
        final b = pair[1];
        expect(flickModifierCycle[a], b);
        expect(flickModifierCycle[b], a);
      }
    });

    test('small-kana pairs round-trip in two steps', () {
      const pairs = ['あぁ', 'いぃ', 'うぅ', 'えぇ', 'おぉ', 'やゃ', 'ゆゅ', 'よょ', 'わゎ'];
      for (final pair in pairs) {
        final a = pair[0];
        final b = pair[1];
        expect(flickModifierCycle[a], b);
        expect(flickModifierCycle[b], a);
      }
    });

    test('h-row cycles through 3 steps back to origin', () {
      const rows = ['はばぱ', 'ひびぴ', 'ふぶぷ', 'へべぺ', 'ほぼぽ'];
      for (final row in rows) {
        final a = row[0];
        final b = row[1];
        final c = row[2];
        expect(flickModifierCycle[a], b);
        expect(flickModifierCycle[b], c);
        expect(flickModifierCycle[c], a);
      }
    });

    test('つ cycles through small and voiced forms back to origin', () {
      expect(flickModifierCycle['つ'], 'っ');
      expect(flickModifierCycle['っ'], 'づ');
      expect(flickModifierCycle['づ'], 'つ');
    });

    test('characters with no transformation return null', () {
      for (final char in ['ら', 'り', 'る', 'れ', 'ろ', 'ん', 'を', 'ー', '、', '。']) {
        expect(flickModifierCycle[char], isNull);
      }
    });
  });
}
