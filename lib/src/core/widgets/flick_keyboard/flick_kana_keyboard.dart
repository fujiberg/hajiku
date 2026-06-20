import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'flick_kana_layout.dart';
import 'flick_key.dart';

/// A self-contained 12-key flick kana input keyboard.
///
/// Renders a 5x4 grid of keys: a center 3x4 block of gojuuon-row keys (plus
/// 小, わ and 、) surrounded by control keys (hiragana/katakana toggle,
/// backspace, cursor movement, space, collapse, submit). Inserts/deletes
/// text directly on [controller] at its current `selection` - no system
/// keyboard is involved.
///
/// Each row key supports both flick gestures (drag in a direction to pick
/// that row's i/u/e/o sound) and Samsung-style multi-tap cycling (tap the
/// same key repeatedly within ~300ms to cycle through its a-i-u-e-o
/// candidates in place).
///
/// [onCollapse] and [onSubmit] are optional; their cells render as inert
/// placeholders when not supplied, so a consumer can wire them up only when
/// relevant (e.g. only show submit when "submit on enter" is enabled).
class FlickKanaKeyboard extends StatefulWidget {
  const FlickKanaKeyboard({
    super.key,
    required this.controller,
    this.onCollapse,
    this.onSubmit,
    this.height = 260,
    this.enabled = true,
  });

  /// The text field controller this keyboard inserts/deletes characters on.
  final TextEditingController controller;

  /// Called when the collapse key is tapped. If `null`, that key renders as
  /// inert - closing/reopening any system keyboard is the consumer's
  /// responsibility.
  final VoidCallback? onCollapse;

  /// Called when the submit key is tapped. If `null`, that key renders as
  /// inert.
  final VoidCallback? onSubmit;

  /// The total height of the keyboard.
  final double height;

  /// Whether the keyboard responds to input. When `false`, every key renders
  /// in its disabled state and ignores taps/flicks - mirrors a disabled
  /// [TextField].
  final bool enabled;

  @override
  State<FlickKanaKeyboard> createState() => _FlickKanaKeyboardState();
}

class _FlickKanaKeyboardState extends State<FlickKanaKeyboard> {
  static const _multiTapWindow = Duration(milliseconds: 300);
  static const _columns = 5;
  static const _rows = 4;

  bool _katakana = false;

  // Multi-tap cycling state.
  (int, int)? _lastCommittedCell;
  DateTime? _lastCommitTime;
  (int, int)? _lastInsertionRange;
  int _cycleIndex = 0;

  // Live flick-preview popup state.
  (int, int)? _activeCell;
  FlickDirection? _activeDirection;
  bool _activePastThreshold = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  // The modifier key's displayed character and enabled state depend on the
  // character before the cursor, which can change from outside this widget
  // (e.g. tapping to reposition the cursor in a bound text field).
  void _handleControllerChanged() => setState(() {});

  String _applyMode(String text) => _katakana ? toKatakana(text) : text;

  void _resetCycle() {
    _lastCommittedCell = null;
    _lastCommitTime = null;
    _lastInsertionRange = null;
    _cycleIndex = 0;
  }

  /// Replaces the controller's current selection (or appends, if invalid)
  /// with [text], collapsing the cursor after it. Returns the inserted
  /// range.
  (int, int) _insert(String text) {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    return (start, start + text.length);
  }

  /// Replaces [range] with [text], collapsing the cursor after it.
  void _replaceRange((int, int) range, String text) {
    final (start, end) = range;
    final value = widget.controller.value;
    final newText = value.text.replaceRange(start, end, text);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _lastInsertionRange = (start, start + text.length);
  }

  void _handleKanaCommit(
    int row,
    int col,
    FlickKeyData data,
    FlickDirection? direction, {
    required bool isFlick,
  }) {
    if (isFlick) {
      _insert(_applyMode(data[direction]!));
      _resetCycle();
      return;
    }

    final cell = (row, col);
    final now = DateTime.now();
    if (_lastCommittedCell == cell &&
        _lastCommitTime != null &&
        now.difference(_lastCommitTime!) < _multiTapWindow &&
        _lastInsertionRange != null) {
      final order = data.cycleOrder;
      _cycleIndex = (_cycleIndex + 1) % order.length;
      _replaceRange(_lastInsertionRange!, _applyMode(order[_cycleIndex]));
      _lastCommitTime = now;
    } else {
      final range = _insert(_applyMode(data.center));
      _lastCommittedCell = cell;
      _cycleIndex = 0;
      _lastCommitTime = now;
      _lastInsertionRange = range;
    }
  }

  void _backspace() {
    _resetCycle();
    final value = widget.controller.value;
    final selection = value.selection;
    if (!selection.isValid) return;

    if (!selection.isCollapsed) {
      final newText = value.text.replaceRange(
        selection.start,
        selection.end,
        '',
      );
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
      return;
    }

    if (selection.start == 0) return;
    final newText = value.text.replaceRange(
      selection.start - 1,
      selection.start,
      '',
    );
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start - 1),
    );
  }

  void _moveCursor(FlickCursorDirection direction) {
    _resetCycle();
    final value = widget.controller.value;
    final selection = value.selection;
    if (!selection.isValid) return;

    final current = selection.isCollapsed
        ? selection.start
        : direction == FlickCursorDirection.left
        ? selection.start
        : selection.end;
    final next = direction == FlickCursorDirection.left
        ? current - 1
        : current + 1;
    widget.controller.selection = TextSelection.collapsed(
      offset: next.clamp(0, value.text.length),
    );
  }

  /// The character tapping the modifier key would currently produce, based
  /// on the character immediately before the cursor - or `null` if no
  /// modification applies (cursor at position 0, a range selection, or a
  /// character with no entry in [flickModifierCycle]).
  String? _modifierResult() {
    final value = widget.controller.value;
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed || selection.start == 0) {
      return null;
    }

    final preceding = value.text[selection.start - 1];
    final code = preceding.runes.first;
    final isKatakana = code >= katakanaRangeStart && code <= katakanaRangeEnd;
    final lookup = isKatakana ? toHiragana(preceding) : preceding;
    final replacement = flickModifierCycle[lookup];
    if (replacement == null) return null;
    return isKatakana ? toKatakana(replacement) : replacement;
  }

  void _applyModifier() {
    _resetCycle();
    final result = _modifierResult();
    if (result == null) return;

    final value = widget.controller.value;
    final selection = value.selection;
    final index = selection.start - 1;
    final newText = value.text.replaceRange(index, selection.start, result);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start),
    );
  }

  void _insertSpace() {
    _resetCycle();
    _insert(' ');
  }

  void _toggleKatakana() {
    _resetCycle();
    setState(() => _katakana = !_katakana);
  }

  void _handleControlTap(FlickGridCell cell) {
    switch (cell) {
      case FlickModifierCell():
        _applyModifier();
      case FlickBackspaceCell():
        _backspace();
      case FlickCursorCell(direction: final direction):
        _moveCursor(direction);
      case FlickKanaModeToggleCell():
        _toggleKatakana();
      case FlickSpaceCell():
        _insertSpace();
      case FlickCollapseCell():
        _resetCycle();
        widget.onCollapse?.call();
      case FlickSubmitCell():
        _resetCycle();
        widget.onSubmit?.call();
      case FlickKanaCell():
      case FlickEmptyCell():
        break;
    }
  }

  void _onLiveStateChanged(
    int row,
    int col,
    bool pressed,
    FlickDirection? direction,
    bool pastThreshold,
  ) {
    setState(() {
      if (pressed) {
        _activeCell = (row, col);
        _activeDirection = direction;
        _activePastThreshold = pastThreshold;
      } else if (_activeCell == (row, col)) {
        _activeCell = null;
        _activeDirection = null;
        _activePastThreshold = false;
      }
    });
  }

  /// The 小 modifier key's content: the character it would currently
  /// produce, or "小" itself when it wouldn't transform anything.
  Widget _modifierContent() {
    final result = _modifierResult();
    return Text(result ?? '小', style: const TextStyle(fontSize: 22));
  }

  Widget _content(FlickGridCell cell) {
    return switch (cell) {
      FlickKanaCell(data: final data) => Text(
        _applyMode(data.center),
        style: const TextStyle(fontSize: 22),
      ),
      FlickModifierCell() => _modifierContent(),
      FlickSpaceCell() => const Icon(Icons.space_bar),
      FlickBackspaceCell() => const Icon(Icons.backspace_outlined),
      FlickCollapseCell() => const Icon(Icons.keyboard_hide_outlined),
      FlickSubmitCell() => const Icon(Icons.send_outlined),
      FlickKanaModeToggleCell() => Text(
        _katakana ? 'カナ' : 'かな',
        style: const TextStyle(fontSize: 14),
      ),
      FlickCursorCell(direction: final direction) => Icon(
        direction == FlickCursorDirection.left
            ? Icons.chevron_left
            : Icons.chevron_right,
      ),
      FlickEmptyCell() => const SizedBox.shrink(),
    };
  }

  Widget _buildCell(int row, int col) {
    final cell = FlickKanaLayout.grid[row][col];
    final enabled =
        widget.enabled &&
        switch (cell) {
          FlickCollapseCell() => widget.onCollapse != null,
          FlickSubmitCell() => widget.onSubmit != null,
          FlickModifierCell() => _modifierResult() != null,
          _ => true,
        };

    return FlickKey(
      cell: cell,
      enabled: enabled,
      onKanaCommit: cell is FlickKanaCell
          ? (direction, {required isFlick}) => setState(() {
              _handleKanaCommit(
                row,
                col,
                cell.data,
                direction,
                isFlick: isFlick,
              );
            })
          : null,
      onControlTap: () => setState(() => _handleControlTap(cell)),
      onLiveStateChanged: (pressed, direction, pastThreshold) =>
          _onLiveStateChanged(row, col, pressed, direction, pastThreshold),
      child: _content(cell),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Leave room below the keyboard so it doesn't sit flush against the
    // device's home indicator / nav bar.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      // A dedicated, more tinted background - like a system keyboard's
      // tray - so the (lighter) keys read as raised above it.
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: widget.height + bottomInset,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / _columns;
                  final cellHeight = constraints.maxHeight / _rows;

                  final children = <Widget>[
                    Column(
                      children: [
                        for (var row = 0; row < _rows; row++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var col = 0; col < _columns; col++)
                                  Expanded(child: _buildCell(row, col)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ];

                  final activeCell = _activeCell;
                  if (activeCell != null) {
                    final (row, col) = activeCell;
                    final cell = FlickKanaLayout.grid[row][col];
                    if (cell is FlickKanaCell) {
                      final minCellDimension = math.min(cellWidth, cellHeight);
                      // Same footprint whether showing the candidate grid or
                      // the single live-preview badge, so the popup doesn't
                      // change size when the touch starts moving.
                      final popupSize = minCellDimension * 1.2;

                      const gap = 6.0;
                      final cellCenterX = (col + 0.5) * cellWidth;
                      final cellTop = row * cellHeight;

                      final maxLeft = math.max(
                        0.0,
                        constraints.maxWidth - popupSize,
                      );
                      final left = (cellCenterX - popupSize / 2).clamp(
                        0.0,
                        maxLeft,
                      );

                      // Position above the key so the popup isn't covered by
                      // the finger. Allowed to overflow above the keyboard's
                      // own bounds (e.g. for top-row keys); only clamp the
                      // bottom so it never overlaps the row below the key.
                      final maxTop = math.max(
                        0.0,
                        constraints.maxHeight - popupSize,
                      );
                      final top = math.min(cellTop - gap - popupSize, maxTop);

                      children.add(
                        Positioned(
                          left: left,
                          top: top,
                          child: IgnorePointer(
                            child: _FlickPreviewPopup(
                              data: cell.data,
                              activeDirection: _activeDirection,
                              pastThreshold: _activePastThreshold,
                              katakana: _katakana,
                              size: popupSize,
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  return Stack(clipBehavior: Clip.none, children: children);
                },
              ),
            ),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }
}

/// The preview popup shown above a [FlickKanaCell] while it's pressed.
///
/// Before the drag passes the flick threshold, shows all of the cell's
/// candidates arranged in a cross inside a circular backdrop - the center
/// character plus up to 4 directional alternatives. Once the drag passes the
/// threshold, it switches to a single large badge showing the character that
/// would be committed if released right now, tracking [activeDirection] live
/// as the user drags.
class _FlickPreviewPopup extends StatelessWidget {
  const _FlickPreviewPopup({
    required this.data,
    required this.activeDirection,
    required this.pastThreshold,
    required this.katakana,
    required this.size,
  });

  final FlickKeyData data;
  final FlickDirection? activeDirection;
  final bool pastThreshold;
  final bool katakana;
  final double size;

  String _label(String text) => katakana ? toKatakana(text) : text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (pastThreshold) {
      return _FlickBadge(text: _label(data[activeDirection]!), diameter: size);
    }

    // The center character (slightly larger) plus up to 4 directional
    // alternatives, laid out directly on top of the circular backdrop -
    // avoids a Row/Column grid so nothing can overflow the circle, and
    // keeps the alternatives close to the center.
    final centerFontSize = size * 0.24;
    final sideFontSize = size * 0.16;
    const sideOffset = 0.55;

    Widget label(String? text, {bool center = false}) {
      if (text == null) return const SizedBox.shrink();
      return Text(
        _label(text),
        style: TextStyle(
          fontSize: center ? centerFontSize : sideFontSize,
          color: theme.colorScheme.onSurface,
          fontWeight: center ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: const Alignment(0, -sideOffset),
            child: label(data.up),
          ),
          Align(
            alignment: const Alignment(-sideOffset, 0),
            child: label(data.left),
          ),
          Align(
            alignment: const Alignment(sideOffset, 0),
            child: label(data.right),
          ),
          Align(
            alignment: const Alignment(0, sideOffset),
            child: label(data.down),
          ),
          label(data.center, center: true),
        ],
      ),
    );
  }
}

/// A circular badge showing a single (large) character, styled the same as
/// the cross-layout popup backdrop so the popup's appearance doesn't change
/// when the drag crosses the flick threshold - only its content does.
class _FlickBadge extends StatelessWidget {
  const _FlickBadge({required this.text, required this.diameter});

  final String text;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        _centeredGlyph(text),
        style: TextStyle(
          fontSize: diameter * 0.45,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Fullwidth ASCII punctuation (！ ？ etc., U+FF01-FF5E) draws its glyph in
/// the left half of its full-width advance box in most fonts, which looks
/// off-center when shown alone at large size - so for this single-character
/// badge, show the halfwidth equivalent instead (visually near-identical,
/// just properly centered).
String _centeredGlyph(String text) {
  if (text.length != 1) return text;
  final code = text.runes.first;
  if (code < 0xFF01 || code > 0xFF5E) return text;
  return String.fromCharCode(code - 0xFEE0);
}
