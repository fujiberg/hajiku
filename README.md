# 弾く Hajiku

A cross-platform Flutter app for [WaniKani](https://www.wanikani.com) reviews and lessons.

> **Status: early development** — core flows (onboarding, home, reviews, lessons, settings) are working; many features still in progress.

## Why

WaniKani has no official mobile app. Third-party options all rely on the system keyboard, forcing manual switching between English and Japanese input during reviews. Hajiku solves this with a built-in 12-key flick kana input widget — no keyboard switching needed.

## Features

- Review and lesson queue powered by the WaniKani API v2
- Romaji-to-kana input for reviews — type romaji on the system keyboard, converted to kana automatically
- Built-in 12-key flick kana input (planned) — no system keyboard switching
- Offline queue with local caching (planned)
- Clean, focused UI optimised for mobile and tablet

## Platform

iOS and Android. The flick input is intentionally mobile-first.

## Getting started

> Full setup instructions will be added once the project reaches a functional state.

**Requirements**

- Flutter SDK (see `.flutter-version` for exact version)
- A WaniKani account with an API token

```bash
git clone https://github.com/fujiberg/hajiku.git
cd hajiku/app
flutter pub get
flutter run
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
