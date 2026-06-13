# Claude Code orientation

This file is the entry point for Claude Code. Read this first, then refer to `.claude/` for deeper topic-specific docs as they are added.

## What this project is

Hajiku (弾く) is a Flutter app for WaniKani reviews and lessons. The core differentiator is a built-in 12-key flick kana input widget, eliminating the need to switch system keyboards during reviews. iOS and Android only — the flick input is intentionally mobile-first.

## Stack

- **Flutter / Dart** — mobile first, iOS + Android
- **WaniKani API v2** — token-based auth, no backend
- **Local storage** — TBD (SQLite or Hive) for offline queue and caching

## Repo structure

- `.flutter-version` — pinned Flutter SDK version
- `app/` — Flutter project root; run all `flutter`/`dart` commands from here
  - `lib/main.dart` — entry point
  - `lib/src/app.dart` — root `HajikuApp` widget (theme, routing)
  - `lib/src/core/` — shared utilities, theming, constants
  - `lib/src/features/` — feature modules, one directory per feature (added as built)
  - `test/` — widget and unit tests

## Hard rules

- Never commit API tokens or secrets. The WaniKani API token is a user-entered runtime credential stored on-device (e.g. secure storage), not a build-time `.env` value
- No backend calls outside the designated API client layer
- `flutter analyze` must pass with zero warnings before any PR
- `dart format` enforced — run before committing

## Further reading

- `.claude/conventions.md` — coding conventions and naming (added as project matures)
- `.claude/api-wanikani.md` — WaniKani API v2 notes (added when API layer is built)
- `.claude/widget-flick-input.md` — flick keyboard design and constraints (added when widget is built)
