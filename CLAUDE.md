# Claude Code orientation

This file is the entry point for Claude Code. Read this first, then refer to `.claude/` for deeper topic-specific docs as they are added.

## What this project is

Hajiku (弾く) is a Flutter app for WaniKani reviews and lessons. The core differentiator is a built-in 12-key flick kana input widget, eliminating the need to switch system keyboards during reviews. iOS and Android only — the flick input is intentionally mobile-first.

## Stack

- **Flutter / Dart** — mobile first, iOS + Android
- **WaniKani API v2** — token-based auth, no backend
- **Local storage** — TBD (SQLite or Hive) for offline queue and caching

## Repo structure

> To be expanded once the Flutter project is scaffolded.

## Hard rules

- Never commit API tokens or secrets — use `.env` (gitignored)
- No backend calls outside the designated API client layer
- `flutter analyze` must pass with zero warnings before any PR
- `dart format` enforced — run before committing

## Further reading

- `.claude/conventions.md` — coding conventions and naming (added as project matures)
- `.claude/api-wanikani.md` — WaniKani API v2 notes (added when API layer is built)
- `.claude/widget-flick-input.md` — flick keyboard design and constraints (added when widget is built)
