# Claude Code orientation

This file is the entry point for Claude Code. Read this first, then refer to `.claude/` for deeper topic-specific docs as they are added.

**Always check `.claude/` for documentation relevant to what you're about to work on before starting** — these docs capture design and constraints that aren't obvious from the code alone, and reading them first avoids re-deriving everything by parsing the codebase. **Keep this file and the `.claude/` docs up to date as the project changes**: when a change makes a doc inaccurate, fix the doc in the same change; when a new area becomes worth documenting, add a doc and link it under "Further reading".

## What this project is

Hajiku (弾く) is a Flutter app for WaniKani reviews and lessons. Its core differentiator is a built-in flick kana input widget, eliminating the need to switch system keyboards during reviews. It's wired into reading quizzes (reviews and lessons) behind a settings toggle ("Flick kana keyboard", on by default); when disabled, reading quizzes fall back to the system keyboard with a romaji-to-kana input formatter. iOS and Android only — the flick input is intentionally mobile-first.

## Stack

- **Flutter / Dart** — mobile first, iOS + Android
- **WaniKani API v2** — token-based auth, no backend
- **Local storage** — `flutter_secure_storage` for the WaniKani API token, `shared_preferences` for app settings. Offline queue/caching strategy still TBD.

## Repo structure

- `.flutter-version` — pinned Flutter SDK version
- `lib/main.dart` — entry point
- `lib/src/app.dart` — root `HajikuApp` widget (theme, routing)
- `lib/src/core/` — shared utilities, theming, constants
  - `auth/` — auth controller (API token state)
  - `storage/` — secure token storage
  - `romaji/` — romaji-to-kana conversion and input formatter
  - `settings/` — app settings (persisted via `shared_preferences`)
  - `wanikani/` — WaniKani API v2 client and models
  - `widgets/` — shared widgets (e.g. `TermInfoPanel`)
- `lib/src/features/` — feature modules, one directory per feature (added as built)
- `test/` — widget and unit tests

## Hard rules

- Never commit API tokens or secrets. The WaniKani API token is a user-entered runtime credential stored on-device (e.g. secure storage), not a build-time `.env` value
- No backend calls outside the designated API client layer
- `flutter analyze` must pass with zero warnings before any PR
- `dart format` enforced — run before committing

## Further reading

- `.claude/api-wanikani.md` — WaniKani API v2 notes
- `.claude/widget-flick-input.md` — flick kana keyboard design, gestures, and constraints
