import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/widgets/flick_keyboard/flick_kana_keyboard.dart';
import 'package:hajiku/src/core/widgets/flick_keyboard/flick_key.dart';

// Cell indices into the row-major FlickKey list built by FlickKanaKeyboard.
// Row 0: toggle, あ,    か,    さ,    backspace
// Row 1: cursor<, た,    な,    は,    cursor>
// Row 2: empty,  ま,    や,    ら,    space
// Row 3: collapse, 小, わ,    、,    submit
const _toggle = 0;
const _a = 1;
const _ka = 2;
const _backspace = 4;
const _cursorLeft = 5;
const _ta = 6;
const _ha = 8;
const _cursorRight = 9;
const _ra = 13;
const _space = 14;
const _collapse = 15;
const _modifier = 16;
const _submit = 19;

void main() {
  Future<void> pumpKeyboard(
    WidgetTester tester,
    TextEditingController controller, {
    VoidCallback? onCollapse,
    VoidCallback? onSubmit,
    ThemeData? theme,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: FlickKanaKeyboard(
            controller: controller,
            onCollapse: onCollapse,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }

  Future<void> tapCell(WidgetTester tester, int index) async {
    await tester.tap(find.byType(FlickKey).at(index));
    await tester.pump();
  }

  Future<void> flickCell(WidgetTester tester, int index, Offset delta) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey).at(index)),
    );
    await gesture.moveBy(delta);
    await gesture.up();
    await tester.pump();
  }

  group('basic insertion', () {
    testWidgets('sequential taps on different keys insert their centers', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ka); // か
      await tapCell(tester, _a); // あ
      await tapCell(tester, _ra); // ら

      expect(controller.text, 'かあら');
    });

    testWidgets('flick inserts the candidate in that direction', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      // あ flick up -> う.
      await flickCell(tester, _a, const Offset(0, -30));

      expect(controller.text, 'う');
    });

    testWidgets('the space cell inserts a space character', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _a); // あ
      await tapCell(tester, _space);
      await tapCell(tester, _ka); // か

      expect(controller.text, 'あ か');
    });
  });

  group('multi-tap cycling', () {
    testWidgets('three quick taps on か cycle か -> き -> く in place', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ka);
      expect(controller.text, 'か');
      await tapCell(tester, _ka);
      expect(controller.text, 'き');
      await tapCell(tester, _ka);
      expect(controller.text, 'く');
    });

    testWidgets('a flick resets the cycle so the next tap starts fresh', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ka); // "か"
      // Flick up on か -> く, always a fresh insert, resets the cycle chain.
      await flickCell(tester, _ka, const Offset(0, -30)); // "かく"
      expect(controller.text, 'かく');

      await tapCell(tester, _ka); // fresh insert (cycle was reset) -> "かくか"
      expect(controller.text, 'かくか');
      await tapCell(tester, _ka); // continues new cycle: か -> き
      expect(controller.text, 'かくき');
    });

    testWidgets('separated taps (>300ms apart) each insert a fresh center', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tester.runAsync(() async {
        await tapCell(tester, _ka);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        await tapCell(tester, _ka);
      });

      expect(controller.text, 'かか');
    });
  });

  group('cursor movement and backspace', () {
    testWidgets('cursor left/right move the collapsed selection', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'かきく')
        ..selection = const TextSelection.collapsed(offset: 3);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _cursorLeft);
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
      await tapCell(tester, _cursorLeft);
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      await tapCell(tester, _cursorRight);
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets('cursor movement resets the multi-tap cycle', (tester) async {
      final controller = TextEditingController(text: 'かきく')
        ..selection = const TextSelection.collapsed(offset: 3);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _cursorLeft); // offset 2
      await tapCell(tester, _cursorLeft); // offset 1

      await tapCell(tester, _ka); // fresh insert at offset 1
      expect(controller.text, 'かかきく');
      await tapCell(tester, _ka); // continues cycle: か -> き
      expect(controller.text, 'かききく');
    });

    testWidgets('backspace removes the character before the cursor', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'かきく')
        ..selection = const TextSelection.collapsed(offset: 3);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _backspace);
      expect(controller.text, 'かき');
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets('backspace at position 0 is a no-op', (tester) async {
      final controller = TextEditingController(text: 'かき')
        ..selection = const TextSelection.collapsed(offset: 0);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _backspace);
      expect(controller.text, 'かき');
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
    });

    testWidgets('backspace deletes a range selection and collapses to start', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'かきく')
        ..selection = const TextSelection(baseOffset: 1, extentOffset: 3);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _backspace);
      expect(controller.text, 'か');
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
    });
  });

  group('insertion at cursor / range replacement', () {
    testWidgets('inserts at a mid-string cursor, not at the end', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'かく')
        ..selection = const TextSelection.collapsed(offset: 1);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _a); // あ
      expect(controller.text, 'かあく');
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets('insert with a range selection replaces it', (tester) async {
      final controller = TextEditingController(text: 'かきく')
        ..selection = const TextSelection(baseOffset: 1, extentOffset: 3);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _a); // あ
      expect(controller.text, 'かあ');
      expect(controller.selection, const TextSelection.collapsed(offset: 2));
    });
  });

  group('小 modifier cycle', () {
    testWidgets('か -> が -> か', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ka); // "か"
      await tapCell(tester, _modifier);
      expect(controller.text, 'が');
      await tapCell(tester, _modifier);
      expect(controller.text, 'か');
    });

    testWidgets('は -> ば -> ぱ -> は (3-way cycle)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ha); // "は"
      await tapCell(tester, _modifier);
      expect(controller.text, 'ば');
      await tapCell(tester, _modifier);
      expect(controller.text, 'ぱ');
      await tapCell(tester, _modifier);
      expect(controller.text, 'は');
    });

    testWidgets('つ -> っ -> づ -> つ (3-way cycle)', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      // た flick up -> つ.
      await flickCell(tester, _ta, const Offset(0, -30));
      expect(controller.text, 'つ');

      await tapCell(tester, _modifier);
      expect(controller.text, 'っ');
      await tapCell(tester, _modifier);
      expect(controller.text, 'づ');
      await tapCell(tester, _modifier);
      expect(controller.text, 'つ');
    });

    testWidgets('is a no-op for characters with no modifier entry', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ra); // "ら"
      await tapCell(tester, _modifier);
      expect(controller.text, 'ら');
    });

    testWidgets('is a no-op at cursor position 0', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _modifier);
      expect(controller.text, '');
    });

    testWidgets('is a no-op when the selection is a range', (tester) async {
      final controller = TextEditingController(text: 'かか')
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _modifier);
      expect(controller.text, 'かか');
    });
  });

  group('katakana toggle', () {
    testWidgets('toggling katakana mode shifts inserted and flicked kana', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _toggle);
      await tapCell(tester, _a); // あ -> ア
      expect(controller.text, 'ア');

      await flickCell(tester, _ka, const Offset(0, -30)); // か-up -> く -> ク
      expect(controller.text, 'アク');
    });

    testWidgets('小 modifier works on katakana via hiragana round-trip', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _toggle);
      await flickCell(tester, _ka, const Offset(0, -30)); // ク
      expect(controller.text, 'ク');

      await tapCell(tester, _modifier); // ク -> グ
      expect(controller.text, 'グ');
    });
  });

  group('collapse / submit', () {
    testWidgets('onCollapse fires when the collapse key is tapped', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var collapsed = false;
      await pumpKeyboard(
        tester,
        controller,
        onCollapse: () => collapsed = true,
      );

      await tapCell(tester, _collapse);
      expect(collapsed, isTrue);
    });

    testWidgets('onSubmit fires when the submit key is tapped', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var submitted = false;
      await pumpKeyboard(tester, controller, onSubmit: () => submitted = true);

      await tapCell(tester, _submit);
      expect(submitted, isTrue);
    });

    testWidgets('collapse and submit keys are inert when callbacks are null', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _collapse);
      await tapCell(tester, _submit);

      expect(controller.text, '');
    });
  });

  group('modifier key preview', () {
    // The modifier key always shows a small "小" badge, plus (when a
    // transformation applies) a larger result character - so this picks
    // out the larger of the one or two Text widgets present.
    String? modifierLabel(WidgetTester tester) {
      final texts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(FlickKey).at(_modifier),
              matching: find.byType(Text),
            ),
          )
          .toList();
      if (texts.length == 1) return texts.single.data;
      return texts
          .reduce(
            (a, b) =>
                (a.style?.fontSize ?? 0) >= (b.style?.fontSize ?? 0) ? a : b,
          )
          .data;
    }

    bool modifierEnabled(WidgetTester tester) =>
        tester.widget<FlickKey>(find.byType(FlickKey).at(_modifier)).enabled;

    testWidgets('shows 小 and is disabled with nothing before the cursor', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      expect(modifierLabel(tester), '小');
      expect(modifierEnabled(tester), isFalse);
    });

    testWidgets('shows the dakuten result after a k-row character', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ka); // "か"

      expect(modifierLabel(tester), 'が');
      expect(modifierEnabled(tester), isTrue);
    });

    testWidgets('shows the small-kana result after a vowel character', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _a); // "あ"

      expect(modifierLabel(tester), 'ぁ');
      expect(modifierEnabled(tester), isTrue);
    });

    testWidgets('shows 小 and is disabled after a character with no entry', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      await tapCell(tester, _ra); // "ら"

      expect(modifierLabel(tester), '小');
      expect(modifierEnabled(tester), isFalse);
    });

    testWidgets('updates as the cursor moves between characters', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'かあ')
        ..selection = const TextSelection.collapsed(offset: 2);
      addTearDown(controller.dispose);
      await pumpKeyboard(tester, controller);

      // Cursor after "あ" -> small-kana result.
      expect(modifierLabel(tester), 'ぁ');

      // Move cursor to after "か" -> dakuten result.
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();

      expect(modifierLabel(tester), 'が');
    });
  });

  group('theming', () {
    testWidgets('renders under a light theme', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(
        tester,
        controller,
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      );

      expect(find.byType(FlickKanaKeyboard), findsOneWidget);
    });

    testWidgets('renders under a dark theme', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpKeyboard(
        tester,
        controller,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      );

      expect(find.byType(FlickKanaKeyboard), findsOneWidget);
    });
  });
}
