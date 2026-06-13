# Contributing to Hajiku

Thank you for your interest in contributing. This document covers conventions, workflow, and expectations.

## Development setup

1. Clone the repo and run `flutter pub get`
2. Copy `.env.example` to `.env` and add your WaniKani API token
3. Run on a physical device or emulator with `flutter run`

See the README for requirements.

## Workflow

- **Branch naming:** `feat/short-description`, `fix/short-description`, `chore/short-description`
- **One concern per PR** — keep pull requests focused and small
- **All changes go through a PR** — no direct pushes to `main`
- **Squash merges only** — keeps the main branch history clean

## Commit messages

Follow [Conventional Commits](https://www.conventionalcommits.org):

- feat: add flick input toggle in settings
- fix: correct reading answer normalisation for ん
- chore: update flutter sdk constraint
- docs: expand API notes in .claude/

Common prefixes: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `style`

## Code conventions

- Dart formatting enforced via `dart format` — run before committing
- Linting via `flutter analyze` — must pass with zero warnings
- See `.claude/conventions.md` for architecture and naming conventions (added as the project matures)

## Reporting issues

Use the issue templates. Include device, OS version, and app version where relevant.

## Questions

Open a `question` issue or start a discussion.
