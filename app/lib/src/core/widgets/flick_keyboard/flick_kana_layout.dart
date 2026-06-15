/// Data model and fixed layout for the 12-key flick kana keyboard.
///
/// The keyboard is a 5-column x 4-row grid. The center 3x4 block holds the
/// gojuuon row keys plus the 小 (modifier), わ and 、 keys; the outer columns
/// hold control keys (mode toggle, backspace, cursor movement, space,
/// collapse, submit).
library;

/// A flick direction relative to a key's center.
enum FlickDirection { up, right, down, left }

/// The center character plus up to four directional flick outputs for a
/// single gojuuon-row key. Any direction may be `null`, meaning that
/// direction has no output (flicking that way falls back to the center).
class FlickKeyData {
  const FlickKeyData({
    required this.center,
    this.up,
    this.right,
    this.down,
    this.left,
  });

  /// The character produced by a tap (no flick).
  final String center;

  /// The character produced by flicking up, if any.
  final String? up;

  /// The character produced by flicking right, if any.
  final String? right;

  /// The character produced by flicking down, if any.
  final String? down;

  /// The character produced by flicking left, if any.
  final String? left;

  /// Looks up the character for a tap (`null`) or a flick in [direction].
  String? operator [](FlickDirection? direction) => switch (direction) {
    null => center,
    FlickDirection.up => up,
    FlickDirection.right => right,
    FlickDirection.down => down,
    FlickDirection.left => left,
  };

  /// Non-null candidates in "+"-popup cross order: up, left, center, right,
  /// down.
  Iterable<(FlickDirection?, String)> get popupCandidates => [
    if (up != null) (FlickDirection.up, up!),
    if (left != null) (FlickDirection.left, left!),
    (null, center),
    if (right != null) (FlickDirection.right, right!),
    if (down != null) (FlickDirection.down, down!),
  ];

  /// Non-null candidates in gojuuon (a-i-u-e-o) order, used for multi-tap
  /// cycling. For the gojuuon-row keys, [left]/[up]/[right]/[down] hold the
  /// i/u/e/o-row characters respectively, so this order is [center, left,
  /// up, right, down].
  List<String> get cycleOrder =>
      [center, left, up, right, down].whereType<String>().toList();
}

/// A single cell in the flick keyboard's 5x4 grid.
sealed class FlickGridCell {
  const FlickGridCell();
}

/// A gojuuon-row key (or わ/、), producing kana via tap/flick/multi-tap.
class FlickKanaCell extends FlickGridCell {
  const FlickKanaCell(this.data);
  final FlickKeyData data;
}

/// The 小 modifier key: cycles dakuten/handakuten/small-kana on the
/// character before the cursor. See [flickModifierCycle].
class FlickModifierCell extends FlickGridCell {
  const FlickModifierCell();
}

/// Deletes the character before the cursor, or the current selection.
class FlickBackspaceCell extends FlickGridCell {
  const FlickBackspaceCell();
}

/// Closes the flick keyboard (and, per the consumer, may reopen the system
/// keyboard). Renders inert if no `onCollapse` callback is supplied.
class FlickCollapseCell extends FlickGridCell {
  const FlickCollapseCell();
}

/// Submits the current input. Renders inert if no `onSubmit` callback is
/// supplied.
class FlickSubmitCell extends FlickGridCell {
  const FlickSubmitCell();
}

/// Toggles between hiragana and katakana output.
class FlickKanaModeToggleCell extends FlickGridCell {
  const FlickKanaModeToggleCell();
}

/// An empty, non-interactive cell.
class FlickEmptyCell extends FlickGridCell {
  const FlickEmptyCell();
}

/// Inserts a space character. Tap-only, with no flick or multi-tap
/// behavior.
class FlickSpaceCell extends FlickGridCell {
  const FlickSpaceCell();
}

/// Which way [FlickCursorCell] moves the cursor.
enum FlickCursorDirection { left, right }

/// Moves the text cursor one position left or right.
class FlickCursorCell extends FlickGridCell {
  const FlickCursorCell(this.direction);
  final FlickCursorDirection direction;
}

/// The fixed 5x4 flick keyboard layout, row-major.
abstract final class FlickKanaLayout {
  static const List<List<FlickGridCell>> grid = [
    [FlickKanaModeToggleCell(), _a, _ka, _sa, FlickBackspaceCell()],
    [
      FlickCursorCell(FlickCursorDirection.left),
      _ta,
      _na,
      _ha,
      FlickCursorCell(FlickCursorDirection.right),
    ],
    [FlickEmptyCell(), _ma, _ya, _ra, FlickSpaceCell()],
    [FlickCollapseCell(), FlickModifierCell(), _wa, _ten, FlickSubmitCell()],
  ];

  // For the gojuuon-row keys, flick up/right/down/left produce the
  // u/e/o/i-row characters respectively (the standard Japanese flick
  // layout), with left/up/right/down read off as i/u/e/o for
  // [FlickKeyData.cycleOrder].
  static const _a = FlickKanaCell(
    FlickKeyData(center: 'あ', up: 'う', right: 'え', down: 'お', left: 'い'),
  );
  static const _ka = FlickKanaCell(
    FlickKeyData(center: 'か', up: 'く', right: 'け', down: 'こ', left: 'き'),
  );
  static const _sa = FlickKanaCell(
    FlickKeyData(center: 'さ', up: 'す', right: 'せ', down: 'そ', left: 'し'),
  );
  static const _ta = FlickKanaCell(
    FlickKeyData(center: 'た', up: 'つ', right: 'て', down: 'と', left: 'ち'),
  );
  static const _na = FlickKanaCell(
    FlickKeyData(center: 'な', up: 'ぬ', right: 'ね', down: 'の', left: 'に'),
  );
  static const _ha = FlickKanaCell(
    FlickKeyData(center: 'は', up: 'ふ', right: 'へ', down: 'ほ', left: 'ひ'),
  );
  static const _ma = FlickKanaCell(
    FlickKeyData(center: 'ま', up: 'む', right: 'め', down: 'も', left: 'み'),
  );
  static const _ya = FlickKanaCell(
    FlickKeyData(center: 'や', up: 'ゆ', down: 'よ'),
  );
  static const _ra = FlickKanaCell(
    FlickKeyData(center: 'ら', up: 'る', right: 'れ', down: 'ろ', left: 'り'),
  );
  static const _wa = FlickKanaCell(
    FlickKeyData(center: 'わ', up: 'ん', right: 'ー', down: '～', left: 'を'),
  );
  static const _ten = FlickKanaCell(
    FlickKeyData(center: '、', up: '！', right: '。', left: '？'),
  );
}

/// Maps a hiragana character to what it becomes when the 小 modifier key is
/// tapped, cycling dakuten/handakuten and small-kana forms. Characters with
/// no entry are unaffected - tapping 小 does nothing.
///
/// づ has both a voiced (つ -> づ) and small (つ -> っ) form, so つ cycles
/// through all three: つ -> っ -> づ -> つ.
///
/// Katakana input is converted to hiragana for lookup and shifted back
/// afterward - see [toKatakana] and the inverse shift applied by the
/// keyboard widget.
const Map<String, String> flickModifierCycle = {
  // k-row: unvoiced <-> voiced
  'か': 'が', 'が': 'か',
  'き': 'ぎ', 'ぎ': 'き',
  'く': 'ぐ', 'ぐ': 'く',
  'け': 'げ', 'げ': 'け',
  'こ': 'ご', 'ご': 'こ',

  // s-row: unvoiced <-> voiced
  'さ': 'ざ', 'ざ': 'さ',
  'し': 'じ', 'じ': 'し',
  'す': 'ず', 'ず': 'す',
  'せ': 'ぜ', 'ぜ': 'せ',
  'そ': 'ぞ', 'ぞ': 'そ',

  // t-row: unvoiced <-> voiced
  'た': 'だ', 'だ': 'た',
  'ち': 'ぢ', 'ぢ': 'ち',
  'て': 'で', 'で': 'て',
  'と': 'ど', 'ど': 'と',

  // つ: 3-way cycle through small and voiced forms.
  'つ': 'っ', 'っ': 'づ', 'づ': 'つ',

  // h-row: 3-way unvoiced -> voiced -> p-sound -> unvoiced
  'は': 'ば', 'ば': 'ぱ', 'ぱ': 'は',
  'ひ': 'び', 'び': 'ぴ', 'ぴ': 'ひ',
  'ふ': 'ぶ', 'ぶ': 'ぷ', 'ぷ': 'ふ',
  'へ': 'べ', 'べ': 'ぺ', 'ぺ': 'へ',
  'ほ': 'ぼ', 'ぼ': 'ぽ', 'ぽ': 'ほ',

  // Plain <-> small kana.
  'あ': 'ぁ', 'ぁ': 'あ',
  'い': 'ぃ', 'ぃ': 'い',
  'う': 'ぅ', 'ぅ': 'う',
  'え': 'ぇ', 'ぇ': 'え',
  'お': 'ぉ', 'ぉ': 'お',
  'や': 'ゃ', 'ゃ': 'や',
  'ゆ': 'ゅ', 'ゅ': 'ゆ',
  'よ': 'ょ', 'ょ': 'よ',
  'わ': 'ゎ', 'ゎ': 'わ',
};

/// The inclusive Unicode range of hiragana letters that have a katakana
/// equivalent exactly 0x60 code points higher (ぁ U+3041 .. ゖ U+3096).
const int hiraganaRangeStart = 0x3041;
const int hiraganaRangeEnd = 0x3096;

/// The inclusive Unicode range of the corresponding katakana letters
/// (ァ U+30A1 .. ヶ U+30F6).
const int katakanaRangeStart = 0x30A1;
const int katakanaRangeEnd = 0x30F6;

/// The code point offset between a hiragana letter and its katakana
/// equivalent.
const int katakanaOffset = katakanaRangeStart - hiraganaRangeStart;

/// Shifts hiragana code points in [input] to their katakana equivalents.
/// Everything else (ー, ～, 、。！？, etc.) passes through unchanged.
String toKatakana(String input) => String.fromCharCodes(
  input.runes.map(
    (rune) => (rune >= hiraganaRangeStart && rune <= hiraganaRangeEnd)
        ? rune + katakanaOffset
        : rune,
  ),
);

/// Shifts katakana code points in [input] back to their hiragana
/// equivalents. Everything else passes through unchanged.
String toHiragana(String input) => String.fromCharCodes(
  input.runes.map(
    (rune) => (rune >= katakanaRangeStart && rune <= katakanaRangeEnd)
        ? rune - katakanaOffset
        : rune,
  ),
);
