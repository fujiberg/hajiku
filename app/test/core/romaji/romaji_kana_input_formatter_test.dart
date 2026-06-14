import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/romaji/romaji_kana_input_formatter.dart';

/// Simulates typing [char] at the current cursor position.
TextEditingValue _type(
  RomajiKanaInputFormatter formatter,
  TextEditingValue current,
  String char,
) {
  final cursor = current.selection.end < 0
      ? current.text.length
      : current.selection.end;
  final text =
      current.text.substring(0, cursor) + char + current.text.substring(cursor);
  final raw = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor + char.length),
  );
  return formatter.formatEditUpdate(current, raw);
}

/// Simulates pressing backspace at the current cursor position.
TextEditingValue _backspace(
  RomajiKanaInputFormatter formatter,
  TextEditingValue current,
) {
  final cursor = current.selection.end;
  final text =
      current.text.substring(0, cursor - 1) + current.text.substring(cursor);
  final raw = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor - 1),
  );
  return formatter.formatEditUpdate(current, raw);
}

void main() {
  test('typing kya builds up to きゃ progressively', () {
    final formatter = RomajiKanaInputFormatter();
    var value = TextEditingValue.empty;

    value = _type(formatter, value, 'k');
    expect(value.text, 'k');

    value = _type(formatter, value, 'y');
    expect(value.text, 'ky');

    value = _type(formatter, value, 'a');
    expect(value.text, 'きゃ');
    expect(value.selection, const TextSelection.collapsed(offset: 2));
  });

  test('typing konnichiwa resolves n along the way', () {
    final formatter = RomajiKanaInputFormatter();
    var value = TextEditingValue.empty;

    for (final char in 'konnichiwa'.split('')) {
      value = _type(formatter, value, char);
    }

    expect(value.text, 'こんにちわ');
    expect(value.selection, TextSelection.collapsed(offset: value.text.length));
  });

  test('shows a pending trailing n before it resolves', () {
    final formatter = RomajiKanaInputFormatter();
    var value = TextEditingValue.empty;

    value = _type(formatter, value, 'k');
    value = _type(formatter, value, 'o');
    value = _type(formatter, value, 'n');
    expect(value.text, 'こn');
  });

  test('backspace removes a whole mora', () {
    final formatter = RomajiKanaInputFormatter();
    var value = TextEditingValue.empty;

    value = _type(formatter, value, 'k');
    value = _type(formatter, value, 'y');
    value = _type(formatter, value, 'a');
    expect(value.text, 'きゃ');

    value = _backspace(formatter, value);
    expect(value.text, '');
    expect(value.selection, const TextSelection.collapsed(offset: 0));
  });

  test('inserting mid-word re-converts correctly and places the cursor', () {
    final formatter = RomajiKanaInputFormatter();
    var value = TextEditingValue.empty;

    for (final char in 'kakya'.split('')) {
      value = _type(formatter, value, char);
    }
    expect(value.text, 'かきゃ');

    // Move the cursor between か and きゃ, then type "n". It stays pending
    // rather than eagerly merging with the already-converted きゃ that
    // follows.
    value = value.copyWith(selection: const TextSelection.collapsed(offset: 1));
    value = _type(formatter, value, 'n');

    expect(value.text, 'かnきゃ');
    expect(value.selection, const TextSelection.collapsed(offset: 2));

    // Typing "a" next resolves it, as if typed sequentially.
    value = _type(formatter, value, 'a');
    expect(value.text, 'かなきゃ');
    expect(value.selection, const TextSelection.collapsed(offset: 2));
  });

  test('pasting multiple characters at once converts them together', () {
    final formatter = RomajiKanaInputFormatter();
    const raw = TextEditingValue(
      text: 'tte',
      selection: TextSelection.collapsed(offset: 3),
    );

    final value = formatter.formatEditUpdate(TextEditingValue.empty, raw);

    expect(value.text, 'って');
    expect(value.selection, const TextSelection.collapsed(offset: 2));
  });

  test('finalize resolves a pending trailing n without mutating state', () {
    final formatter = RomajiKanaInputFormatter();
    var value = TextEditingValue.empty;

    value = _type(formatter, value, 'n');
    expect(value.text, 'n');
    expect(formatter.finalize(), 'ん');

    // Further edits still build on the un-finalized "n" buffer.
    value = _type(formatter, value, 'a');
    expect(value.text, 'な');
  });
}
