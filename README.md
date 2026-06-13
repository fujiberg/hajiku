# 弾く Hajiku

A cross-platform Flutter app for [WaniKani](https://www.wanikani.com) reviews and lessons.

> **Status: early development** — not yet functional.

## Why

WaniKani has no official mobile app. Third-party options all rely on the system keyboard, forcing manual switching between English and Japanese input during reviews. Hajiku solves this with a built-in 12-key flick kana input widget — no keyboard switching needed.

## Features (planned)

- Review and lesson queue powered by the WaniKani API v2
- Built-in 12-key flick kana input — no system keyboard switching
- Offline queue with local caching
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
cd hajiku
flutter pub get
flutter run
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
