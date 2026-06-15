import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flick_kana_layout.dart';

/// A single cell of the flick keyboard.
///
/// Handles tap/flick gesture detection for [FlickKanaCell]s and simple-tap
/// detection for other interactive cells, rendering [child] inside a themed
/// tile. [FlickEmptyCell]s render [child] directly with no interaction or
/// styling.
class FlickKey extends StatefulWidget {
  const FlickKey({
    super.key,
    required this.cell,
    required this.child,
    this.enabled = true,
    this.onKanaCommit,
    this.onControlTap,
    this.onLiveStateChanged,
  });

  /// The grid cell this widget represents.
  final FlickGridCell cell;

  /// The content to render centered inside the key (a character, icon, etc).
  final Widget child;

  /// Whether this cell responds to input. Used by [FlickCollapseCell] and
  /// [FlickSubmitCell] to render as inert when no callback is supplied.
  final bool enabled;

  /// Called when a [FlickKanaCell] commits a character via tap or flick.
  /// [isFlick] is `true` for a flick commit (always a fresh insert) and
  /// `false` for a tap commit (may continue a multi-tap cycle).
  final void Function(FlickDirection? direction, {required bool isFlick})?
  onKanaCommit;

  /// Called when any non-kana, non-empty cell is tapped.
  final VoidCallback? onControlTap;

  /// Called as the user presses and drags a [FlickKanaCell], reporting
  /// whether the key is currently pressed, the live flick direction (if
  /// any), and whether the drag has passed the flick threshold - so the
  /// parent can render a preview popup above the key and switch it from
  /// "show all candidates" to "show the character that would be committed".
  final void Function(
    bool pressed,
    FlickDirection? direction,
    bool pastThreshold,
  )?
  onLiveStateChanged;

  @override
  State<FlickKey> createState() => _FlickKeyState();
}

class _FlickKeyState extends State<FlickKey> {
  static const _flickThreshold = 18.0;

  Offset _dragOffset = Offset.zero;
  FlickDirection? _liveDirection;
  bool _pressed = false;
  bool _pastThreshold = false;

  FlickKeyData? get _data => switch (widget.cell) {
    FlickKanaCell(data: final data) => data,
    _ => null,
  };

  bool get _interactive => widget.enabled && widget.cell is! FlickEmptyCell;

  FlickDirection? _directionFor(Offset offset) {
    if (offset.distance < _flickThreshold) return null;
    final angle = math.atan2(offset.dy, offset.dx);
    final normalized = (angle + math.pi / 4 + 2 * math.pi) % (2 * math.pi);
    final sector = (normalized / (math.pi / 2)).floor() % 4;
    final direction = switch (sector) {
      0 => FlickDirection.right,
      1 => FlickDirection.down,
      2 => FlickDirection.left,
      _ => FlickDirection.up,
    };
    // Fall back to the center if this key has no candidate in that
    // direction (e.g. や's up/down), so there's never a dead selection.
    return _data?[direction] != null ? direction : null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_interactive) return;
    setState(() {
      _pressed = true;
      _dragOffset = Offset.zero;
      _liveDirection = null;
      _pastThreshold = false;
    });
    if (_data != null) widget.onLiveStateChanged?.call(true, null, false);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pressed) return;
    _dragOffset += event.delta;
    final direction = _directionFor(_dragOffset);
    final pastThreshold = _dragOffset.distance >= _flickThreshold;
    if (direction == _liveDirection && pastThreshold == _pastThreshold) {
      return;
    }
    setState(() {
      _liveDirection = direction;
      _pastThreshold = pastThreshold;
    });
    if (_data != null) {
      widget.onLiveStateChanged?.call(true, direction, pastThreshold);
      HapticFeedback.selectionClick();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_pressed) return;
    final direction = _liveDirection;
    setState(() {
      _pressed = false;
      _dragOffset = Offset.zero;
      _liveDirection = null;
      _pastThreshold = false;
    });
    if (_data != null) widget.onLiveStateChanged?.call(false, null, false);
    switch (widget.cell) {
      case FlickKanaCell():
        widget.onKanaCommit?.call(direction, isFlick: direction != null);
      case FlickEmptyCell():
        break;
      default:
        widget.onControlTap?.call();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_pressed) return;
    setState(() {
      _pressed = false;
      _dragOffset = Offset.zero;
      _liveDirection = null;
      _pastThreshold = false;
    });
    if (_data != null) widget.onLiveStateChanged?.call(false, null, false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cell is FlickEmptyCell) {
      return widget.child;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isControlKey = widget.cell is! FlickKanaCell;

    final Color background;
    final Color foreground;
    if (!widget.enabled) {
      background = colorScheme.surfaceContainerLowest;
      foreground = colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (_pressed) {
      // Pressed keys look "depressed" - recessed below the surrounding
      // keys, like a physical key being pushed in.
      background = colorScheme.surfaceContainerLowest;
      foreground = colorScheme.onSurface;
    } else if (isControlKey) {
      // Non-character keys (toggle, backspace, cursor, modifier, space,
      // collapse, submit) get a distinct tint, like the function-key row on
      // a system keyboard.
      background = colorScheme.secondaryContainer;
      foreground = colorScheme.onSecondaryContainer;
    } else {
      background = colorScheme.surfaceContainerLow;
      foreground = colorScheme.onSurface;
    }

    // While a kana cell is pressed, its candidates are shown in the preview
    // popup above it - dim the key's own content so it doesn't compete with
    // the popup or get hidden under the finger.
    final content = _pressed && _data != null
        ? Opacity(opacity: 0.3, child: widget.child)
        : widget.child;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: content,
          ),
        ),
      ),
    );
  }
}
