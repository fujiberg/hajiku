# Flick kana keyboard

Hajiku's core differentiator: a self-contained 12-key flick kana input widget, so reading quizzes never need a system
keyboard switch. It lives under `lib/src/core/widgets/flick_keyboard/` and is wired into the review/lesson quiz screen
behind the "Flick kana keyboard" setting (on by default).

## Files

- `flick_kana_layout.dart` — pure data: the `FlickKeyData` model, the sealed `FlickGridCell` hierarchy, the fixed 5×4
  `FlickKanaLayout.grid`, the `flickModifierCycle` map, and the hiragana⇄katakana shift helpers. No widgets.
- `flick_key.dart` — `FlickKey`, one grid cell. Owns gesture detection (tap / flick / drag tracking) and per-key
  rendering. Stateless about *what* a key produces; it reports intent up via callbacks.
- `flick_kana_keyboard.dart` — `FlickKanaKeyboard`, the whole keyboard. Owns the grid, mutates the bound
  `TextEditingController`, tracks katakana mode + multi-tap cycle state, and drives the live preview popup.

Tests mirror this layout under `test/core/widgets/flick_keyboard/`.

## The grid (`FlickKanaLayout.grid`, 5 columns × 4 rows, row-major)

```
[かな toggle] [あ] [か] [さ] [⌫ backspace]
[◄ cursor  ] [た] [な] [は] [► cursor    ]
[(empty)   ] [ま] [や] [ら] [␣ space     ]
[⌄ collapse] [小] [わ] [、] [➤ submit    ]
```

The center 3×4 block is kana keys (`FlickKanaCell`); the outer columns are control keys. Cells are a sealed type
(`FlickGridCell`): `FlickKanaCell`, `FlickModifierCell` (小), `FlickBackspaceCell`, `FlickCursorCell`,
`FlickKanaModeToggleCell`, `FlickSpaceCell`, `FlickCollapseCell`, `FlickSubmitCell`, `FlickEmptyCell`.

## Kana key model (`FlickKeyData`)

A key has a `center` (tap output) plus up to four nullable directional outputs. For the gojūon-row keys the
directions follow the standard Japanese flick layout: **up/right/down/left = the u/e/o/i-row characters**. So あ is
`center: あ, up: う, right: え, down: お, left: い`.

- `operator [](FlickDirection?)` — `null` ⇒ `center`; otherwise the directional char (may be null if absent).
- `cycleOrder` ⇒ `[center, left, up, right, down]` filtered to non-null = gojūon a-i-u-e-o order (used by multi-tap).
- `popupCandidates` ⇒ cross order (up, left, center, right, down) for the preview.

Special keys: や has only `up: ゆ, down: よ`; わ is `center: わ, up: ん, right: ー, down: ～, left: を`; 、 is
`center: 、, up: ！, right: 。, left: ？`.

## Gesture handling (`FlickKey`)

Raw pointer events (`Listener`), not `GestureDetector`, so flick tracking is precise:

- **Flick threshold** is `18.0` logical px. `_directionFor(offset)` returns null below it; above it, it picks a
  sector via `atan2` (rotated by π/4, quarter-turn sectors → right/down/left/up). If the key has no candidate in that
  direction it falls back to `null` (center), so there's never a dead selection.
- **Tap** (released below threshold) ⇒ `onKanaCommit(null, isFlick: false)`.
- **Flick** (released past threshold with a direction) ⇒ `onKanaCommit(direction, isFlick: true)`.
- During a drag it streams `onLiveStateChanged(pressed, direction, pastThreshold)` so the keyboard can show/update the
  preview popup. `HapticFeedback.selectionClick()` fires as the live direction changes.
- Non-kana interactive cells just call `onControlTap`; `FlickEmptyCell` renders its child with no interaction.

Rendering reflects state: disabled (faded), pressed ("depressed", recessed background), control-key tint
(`secondaryContainer`) vs. kana-key surface. A pressed kana key dims its own glyph to 0.3 opacity because the
candidates are shown in the popup above the finger.

## Multi-tap cycling (`FlickKanaKeyboard`)

Samsung-style: tapping the *same* kana key repeatedly within `_multiTapWindow` (300 ms) cycles through its
`cycleOrder` in place, replacing the last insertion (`_lastInsertionRange`) rather than appending. Tracked via
`_lastCommittedCell` / `_lastCommitTime` / `_cycleIndex`. Any flick, control action, or a tap on a different cell
resets the cycle (`_resetCycle`).

## The 小 modifier key

`flickModifierCycle` maps a kana to its next form when 小 is tapped, cycling dakuten / handakuten / small-kana:

- k/s/t rows: unvoiced ⇄ voiced (か⇄が).
- h row: 3-way unvoiced → voiced → p-sound → unvoiced (は→ば→ぱ→は).
- つ: 3-way つ→っ→づ→つ (it has both a small and a voiced form).
- vowels, や/ゆ/よ, わ: plain ⇄ small (あ⇄ぁ).

The key operates on the character *immediately before the cursor*. `_modifierResult()` computes what it would
produce; the key renders that character live (or 小 when nothing applies) and disables itself when there's no
applicable transform. Because the displayed glyph depends on text the user can change from outside (e.g. tapping to
move the cursor in the bound field), the keyboard listens to the controller and rebuilds on every change.

## Katakana mode

A boolean `_katakana` toggled by the かな/カナ key. Output is produced in hiragana then shifted with `toKatakana`.
Hiragana↔katakana is a flat code-point shift of `katakanaOffset` (0x60) over the kana ranges
(`hiraganaRangeStart..End`, `katakanaRangeStart..End`); everything else (ー, ～, 、。！？) passes through. The 小
modifier converts katakana back to hiragana for its lookup, then shifts the result forward again.

## Text mutation

The keyboard edits the bound `TextEditingController` directly at its current `selection` — no system input connection
is involved. `_insert` replaces the selection (or appends if the selection is invalid) and collapses the cursor after
the inserted text; `_replaceRange` backs the multi-tap in-place replacement; `_backspace` and `_moveCursor` operate on
the selection, supporting both a collapsed cursor and a range.

## Live preview popup

Rendered through an `OverlayPortal` (so it can extend above the keyboard's own bounds) positioned over the active
cell using the grid's `GlobalKey` render box. Before the drag passes the threshold it shows the full candidate cross;
once past it, a single large badge of the character that would commit if released now, tracking the live direction.
`_centeredGlyph` swaps fullwidth ASCII punctuation (！？ etc., U+FF01–FF5E) for its halfwidth equivalent in the badge
only, because the fullwidth glyph renders off-center at large size.

## Consumer API & integration

`FlickKanaKeyboard` props: `controller` (required), optional `onCollapse` / `onSubmit` (their cells render inert when
null, so a consumer can wire up only what's relevant), `height` (default 260), `enabled`. Disabled mirrors a disabled
`TextField`: every key greys out and ignores input.

`ReviewScreen` (`lib/src/features/review/review_screen.dart`) integrates it:

- The keyboard stays mounted at all times and is shown/hidden via a `SizeTransition` (200 ms) — this keeps a
  continuous size signal in both directions rather than swapping child widgets.
- While the flick keyboard is active the answer `TextField` is `readOnly` with `keyboardType: TextInputType.none` and
  `showCursor: true`, so the system keyboard never appears but the caret still does.
- Which keyboard shows for a reading quiz = `settings.flickKeyboardEnabled` XOR a per-question `_readingKeyboardSwapped`
  flag. `onCollapse` flips that flag (hiding the flick keyboard and opening the system keyboard); dismissing the system
  keyboard (detected via `didChangeMetrics`) flips it back. The swap resets for each new question.
- `onSubmit` is wired only when `settings.flickKeyboardSubmitEnabled` (the large Submit key is far less prone to
  accidental taps than the system Enter key, so it has its own setting separate from `keyboardSubmitEnabled`).

## Constraints

Mobile-first by design (iOS + Android). The widget assumes touch pointer input and a portrait-ish key grid; it is not
intended for desktop/web.
