import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/widgets/flick_keyboard/flick_kana_layout.dart';
import 'package:hajiku/src/core/widgets/flick_keyboard/flick_key.dart';

void main() {
  // (1,3) - か: center=か, up=く, right=け, down=こ, left=き.
  final ka = FlickKanaLayout.grid[0][2] as FlickKanaCell;
  // (4,4) - 、: center=、, up=！, right=。, down=？, left=null.
  final ten = FlickKanaLayout.grid[3][3] as FlickKanaCell;
  // (1,5) - backspace.
  final backspace = FlickKanaLayout.grid[0][4];
  // (3,1) - empty spacer.
  final empty = FlickKanaLayout.grid[2][0];

  Future<void> pumpKey(
    WidgetTester tester,
    FlickGridCell cell, {
    bool enabled = true,
    void Function(FlickDirection?, {required bool isFlick})? onKanaCommit,
    VoidCallback? onControlTap,
    void Function(bool, FlickDirection?, bool)? onLiveStateChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              height: 100,
              child: FlickKey(
                cell: cell,
                enabled: enabled,
                onKanaCommit: onKanaCommit,
                onControlTap: onControlTap,
                onLiveStateChanged: onLiveStateChanged,
                child: const Text('x'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tap on か commits か (tap-commit, direction == null)', (
    tester,
  ) async {
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ka,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
    );

    await tester.tap(find.byType(FlickKey));
    await tester.pump();

    expect(commits, [(null, false)]);
  });

  testWidgets('flick up on か commits く', (tester) async {
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ka,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await gesture.up();
    await tester.pump();

    expect(commits, [(FlickDirection.up, true)]);
  });

  testWidgets('flick right on か commits け', (tester) async {
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ka,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pump();

    expect(commits, [(FlickDirection.right, true)]);
  });

  testWidgets('flick down on か commits こ', (tester) async {
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ka,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey)),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.up();
    await tester.pump();

    expect(commits, [(FlickDirection.down, true)]);
  });

  testWidgets('flick left on か commits き', (tester) async {
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ka,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey)),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.up();
    await tester.pump();

    expect(commits, [(FlickDirection.left, true)]);
  });

  testWidgets('flicking toward a missing direction falls back to tap-commit', (
    tester,
  ) async {
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ten,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
    );

    // 、 has no `down` candidate, so a downward flick should fall back to a
    // tap-commit of the center character.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey)),
    );
    await gesture.moveBy(const Offset(0, 30));
    await gesture.up();
    await tester.pump();

    expect(commits, [(null, false)]);
  });

  testWidgets('pointer cancel commits nothing', (tester) async {
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ka,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await gesture.cancel();
    await tester.pump();

    expect(commits, isEmpty);
  });

  testWidgets('reports live press/drag state while dragging', (tester) async {
    final liveStates = <(bool, FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      ka,
      onKanaCommit: (_, {required isFlick}) {},
      onLiveStateChanged: (pressed, direction, hasMoved) =>
          liveStates.add((pressed, direction, hasMoved)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlickKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(liveStates, [
      (true, null, false),
      (true, FlickDirection.up, true),
      (false, null, false),
    ]);
  });

  testWidgets(
    'movement below the flick threshold does not report pastThreshold',
    (tester) async {
      final liveStates = <(bool, FlickDirection?, bool)>[];
      await pumpKey(
        tester,
        ka,
        onKanaCommit: (_, {required isFlick}) {},
        onLiveStateChanged: (pressed, direction, pastThreshold) =>
            liveStates.add((pressed, direction, pastThreshold)),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FlickKey)),
      );
      await tester.pump();
      // Below the 18px flick threshold.
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(liveStates, [(true, null, false), (false, null, false)]);
    },
  );

  testWidgets('control cells commit on tap with no popup state', (
    tester,
  ) async {
    var controlTaps = 0;
    final liveStates = <(bool, FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      backspace,
      onControlTap: () => controlTaps++,
      onLiveStateChanged: (pressed, direction, hasMoved) =>
          liveStates.add((pressed, direction, hasMoved)),
    );

    await tester.tap(find.byType(FlickKey));
    await tester.pump();

    expect(controlTaps, 1);
    expect(liveStates, isEmpty);
  });

  testWidgets('disabled control cells do not commit', (tester) async {
    var controlTaps = 0;
    await pumpKey(
      tester,
      backspace,
      enabled: false,
      onControlTap: () => controlTaps++,
    );

    await tester.tap(find.byType(FlickKey));
    await tester.pump();

    expect(controlTaps, 0);
  });

  testWidgets('FlickEmptyCell is inert', (tester) async {
    var controlTaps = 0;
    final commits = <(FlickDirection?, bool)>[];
    await pumpKey(
      tester,
      empty,
      onKanaCommit: (direction, {required isFlick}) =>
          commits.add((direction, isFlick)),
      onControlTap: () => controlTaps++,
    );

    await tester.tap(find.byType(FlickKey));
    await tester.pump();

    expect(controlTaps, 0);
    expect(commits, isEmpty);
  });
}
