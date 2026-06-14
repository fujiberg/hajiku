import 'kana_table.dart';

/// A contiguous span of converted (or pass-through) text, mapping a range of
/// the original romaji input to the resulting kana/literal output.
class RomajiKanaToken {
  const RomajiKanaToken({
    required this.romajiStart,
    required this.romajiEnd,
    required this.kanaStart,
    required this.kanaEnd,
    required this.kana,
    required this.isPending,
  });

  /// Start offset (inclusive) of this token in the original romaji input.
  final int romajiStart;

  /// End offset (exclusive) of this token in the original romaji input.
  final int romajiEnd;

  /// Start offset (inclusive) of this token in [RomajiConversionResult.kana].
  final int kanaStart;

  /// End offset (exclusive) of this token in [RomajiConversionResult.kana].
  final int kanaEnd;

  /// The kana (or literal pass-through) text produced by this token.
  final String kana;

  /// Whether this token is an incomplete trailing romaji fragment, shown
  /// literally because it could still combine with future input (e.g. a
  /// lone trailing `n`, or a doubled consonant awaiting its vowel).
  final bool isPending;
}

/// The result of converting a romaji string to kana.
class RomajiConversionResult {
  const RomajiConversionResult({required this.kana, required this.tokens});

  /// The converted text: kana plus any literal pass-through characters.
  final String kana;

  /// Tokens covering the entire input, in order, with no gaps or overlaps.
  final List<RomajiKanaToken> tokens;
}

/// Converts romaji to hiragana using a longest-match walk over
/// [romajiToKanaTable].
class RomajiConverter {
  const RomajiConverter._();

  /// Converts [romaji] to kana.
  ///
  /// If a romaji fragment ending at [cursorOffset] (or, if `null`, at the end
  /// of [romaji]) could still extend into a different kana given more
  /// characters (e.g. a lone trailing `n`, which could become
  /// `な`/`に`/`ん`/etc.), that fragment is left as literal pending text
  /// rather than being resolved early - unless [isFinal] is `true`, in which
  /// case it's resolved as if no more input is coming (used when the user
  /// submits their answer). Text after [cursorOffset] is treated as already
  /// settled and converted normally, so it isn't eagerly merged into a
  /// fragment the user just typed.
  static RomajiConversionResult convert(
    String romaji, {
    bool isFinal = false,
    int? cursorOffset,
  }) {
    final lower = romaji.toLowerCase();
    final tokens = <RomajiKanaToken>[];
    final buffer = StringBuffer();
    var i = 0;

    while (i < lower.length) {
      final start = i;
      final rootNode = romajiToKanaTable[lower.substring(i, i + 1)];
      if (rootNode is! Map<String, Object>) {
        // Unmapped character: pass through literally.
        final raw = romaji.substring(i, i + 1);
        tokens.add(
          RomajiKanaToken(
            romajiStart: start,
            romajiEnd: start + 1,
            kanaStart: buffer.length,
            kanaEnd: buffer.length + raw.length,
            kana: raw,
            isPending: false,
          ),
        );
        buffer.write(raw);
        i++;
        continue;
      }

      // Only let a fragment the user just typed (i.e. one that starts before
      // the cursor) extend up to the cursor - text further out is already
      // settled and shouldn't be eagerly pulled into it.
      final effectiveEnd =
          (!isFinal && cursorOffset != null && cursorOffset > start)
          ? cursorOffset
          : lower.length;

      var node = rootNode;
      i++;
      while (i < effectiveEnd) {
        final next = node[lower.substring(i, i + 1)];
        if (next is! Map<String, Object>) break;
        node = next;
        i++;
      }

      final sentinelValue = node[kanaEnd];
      final sentinel = sentinelValue is String ? sentinelValue : null;
      final hasChildren = node.keys.any((key) => key != kanaEnd);
      final atEnd = i >= effectiveEnd;
      final committable =
          sentinel != null && (!atEnd || isFinal || !hasChildren);

      final text = committable ? sentinel : romaji.substring(start, i);
      tokens.add(
        RomajiKanaToken(
          romajiStart: start,
          romajiEnd: i,
          kanaStart: buffer.length,
          kanaEnd: buffer.length + text.length,
          kana: text,
          isPending: !committable,
        ),
      );
      buffer.write(text);
    }

    return RomajiConversionResult(kana: buffer.toString(), tokens: tokens);
  }
}
