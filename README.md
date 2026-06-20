# 弾く Hajiku

A cross-platform Flutter app for [WaniKani](https://www.wanikani.com) reviews and lessons.

> **Status: early development** — core flows (onboarding, home, reviews, lessons, settings) are working; many features still in progress.

## Why

WaniKani has no official mobile app. Third-party options all rely on the system keyboard, forcing manual switching between English and Japanese input during reviews. Hajiku solves this with a built-in 12-key flick kana input widget — no keyboard switching needed.

## Features

- Built-in 12-key flick kana input — type kana directly during reviews, no system keyboard switching (on by default, toggleable in settings)
- Romaji-to-kana fallback — when the flick keyboard is disabled, type romaji on the system keyboard and have it converted to kana automatically
- Review and lesson queue powered by the WaniKani API v2
- Home dashboard with level progress, an upcoming-review forecast, and SRS stage distribution
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
cd hajiku
flutter pub get
flutter run
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

## Disclaimer

Hajiku is an unofficial third-party app and is not affiliated with, endorsed by, or in any way connected to [Tofugu LLC](https://www.tofugu.com) or [WaniKani](https://www.wanikani.com). All educational content (kanji, vocabulary, radicals, and mnemonics) is copyright © Tofugu LLC and is accessed via the WaniKani API under their [terms of service](https://www.wanikani.com/terms).
