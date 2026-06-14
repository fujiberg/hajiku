import 'package:flutter/services.dart';

import 'romaji_converter.dart';

/// Live romaji-to-kana conversion for a [TextField], applied via
/// [TextField.inputFormatters].
///
/// Maintains an internal buffer of the literal romaji typed so far and
/// re-converts it on every edit, so edits anywhere in the field (not just at
/// the end) re-derive the displayed kana correctly. Create a fresh instance
/// per question - state isn't meant to be reused across quizzes (or call
/// [reset]).
class RomajiKanaInputFormatter extends TextInputFormatter {
  String _romajiBuffer = '';
  List<RomajiKanaToken> _tokens = const [];

  /// Clears the romaji buffer, e.g. when moving to a new question.
  void reset() {
    _romajiBuffer = '';
    _tokens = const [];
  }

  /// The current input with any still-pending trailing fragment (most
  /// notably a lone trailing `n`) eagerly resolved, as if no more input were
  /// coming. Used to derive the submitted answer.
  String finalize() =>
      RomajiConverter.convert(_romajiBuffer, isFinal: true).kana;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text == oldValue.text) {
      // Selection-only change (e.g. cursor move) - nothing to convert.
      return newValue;
    }

    final oldKana = oldValue.text;
    final newKana = newValue.text;

    final maxPrefix = oldKana.length < newKana.length
        ? oldKana.length
        : newKana.length;
    var prefixLen = 0;
    while (prefixLen < maxPrefix && oldKana[prefixLen] == newKana[prefixLen]) {
      prefixLen++;
    }

    var suffixLen = 0;
    final maxSuffix = maxPrefix - prefixLen;
    while (suffixLen < maxSuffix &&
        oldKana[oldKana.length - 1 - suffixLen] ==
            newKana[newKana.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final oldEditStart = prefixLen;
    final oldEditEnd = oldKana.length - suffixLen;
    final inserted = newKana.substring(prefixLen, newKana.length - suffixLen);

    final romajiEditStart = _kanaToRomajiOffset(oldEditStart, roundUp: false);
    final romajiEditEnd = _kanaToRomajiOffset(oldEditEnd, roundUp: true);

    _romajiBuffer = _romajiBuffer.replaceRange(
      romajiEditStart,
      romajiEditEnd,
      inserted,
    );

    final romajiCursor = romajiEditStart + inserted.length;
    final result = RomajiConverter.convert(
      _romajiBuffer,
      cursorOffset: romajiCursor,
    );
    _tokens = result.tokens;

    final kanaCursor = _romajiToKanaOffset(
      romajiCursor,
      kanaLength: result.kana.length,
    );

    return TextEditingValue(
      text: result.kana,
      selection: TextSelection.collapsed(offset: kanaCursor),
    );
  }

  /// Maps a kana-space offset in the *previous* output (using [_tokens] as
  /// they were before this edit) to a romaji-space offset in [_romajiBuffer].
  ///
  /// Offsets inside a multi-character token are snapped to its start or end
  /// (per [roundUp]), so editing any part of a converted mora affects all of
  /// its underlying romaji.
  int _kanaToRomajiOffset(int kanaOffset, {required bool roundUp}) {
    for (final token in _tokens) {
      if (kanaOffset <= token.kanaStart) return token.romajiStart;
      if (kanaOffset < token.kanaEnd) {
        return roundUp ? token.romajiEnd : token.romajiStart;
      }
    }
    return _romajiBuffer.length;
  }

  /// Maps a romaji-space offset to a kana-space offset in the *new* output,
  /// using [_tokens] as they are after this edit.
  int _romajiToKanaOffset(int romajiOffset, {required int kanaLength}) {
    for (final token in _tokens) {
      if (romajiOffset <= token.romajiStart) return token.kanaStart;
      if (romajiOffset < token.romajiEnd) return token.kanaEnd;
    }
    return kanaLength;
  }
}
