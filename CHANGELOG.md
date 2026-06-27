# Changelog

## [0.2.0](https://github.com/fujiberg/hajiku/compare/v0.1.0...v0.2.0) (2026-06-27)


### Features

* add basic onboarding screen ([725010c](https://github.com/fujiberg/hajiku/commit/725010c6aef56ffebb711b4d872985150f2b3a23))
* add button for info on last item ([8528b2e](https://github.com/fujiberg/hajiku/commit/8528b2ea4ce8c04565dc4752b46a6cd38d61056b))
* add cache and editing for custom answers ([a823b32](https://github.com/fujiberg/hajiku/commit/a823b326bb12b0f451d2d93d0cb2e1c7257bd8e2))
* add caching ([5eb8165](https://github.com/fujiberg/hajiku/commit/5eb81658120834c13b4f9d9b2f00ee7621fe2b6e))
* add disclaimers and about ([6c78726](https://github.com/fujiberg/hajiku/commit/6c78726e8f90b29f09f98dcf55cc5f8308b649aa))
* add display of info after incorrect answer ([3472bc1](https://github.com/fujiberg/hajiku/commit/3472bc133fddf20cd09ae67904cfaea0124a3e24))
* add flick keyboard ([1ce1780](https://github.com/fujiberg/hajiku/commit/1ce1780b4db85ab8966ec7e825f0e2c8d70aa837))
* add icons ([81aa885](https://github.com/fujiberg/hajiku/commit/81aa8853bdde62a5360ae04cbd6a8d7b1a3f198d))
* add lessons ([b95557a](https://github.com/fujiberg/hajiku/commit/b95557aec430a41ad3e4b14a39b3b4aa1b24f264))
* add review session screen ([cc1d01f](https://github.com/fujiberg/hajiku/commit/cc1d01f4beca586fcd35eecffab2c866dc6a7ecf))
* add romaji to kana ([a263dfb](https://github.com/fujiberg/hajiku/commit/a263dfb12c7aa3c1d8792dc53433b8377cf877c6))
* add settings screen ([9ed11ad](https://github.com/fujiberg/hajiku/commit/9ed11ad072b6b9b9eccfff066f931604ad97a829))
* add statistics screen ([80f0f2e](https://github.com/fujiberg/hajiku/commit/80f0f2e95cb37b70da3a2bf26d4f0e8fb5e80b1c))
* add subscription notice ([053b490](https://github.com/fujiberg/hajiku/commit/053b49044434668971a11e09efdb1b0c99098cc2))
* add WaniKani API client skeleton and token storage ([f7af223](https://github.com/fujiberg/hajiku/commit/f7af223a334baad429814bdfd86e0d45bf740f2f))
* honor custom answers ([854d094](https://github.com/fujiberg/hajiku/commit/854d094c180def9bc00351cfbe8f603f330ac8a6))
* implement flick keyboard for reviews ([d9a1980](https://github.com/fujiberg/hajiku/commit/d9a1980cbd544f669fe7c6acc2e2f644575e41c2))
* improve input validation and answer matching ([20e53de](https://github.com/fujiberg/hajiku/commit/20e53de31529e6ee33ad5f9a68121e73326df3cd))
* improve onboarding screen ([117fd48](https://github.com/fujiberg/hajiku/commit/117fd48e4def25ba53c851311e90beb33d9262dc))
* improve summary screen ([16d7c93](https://github.com/fujiberg/hajiku/commit/16d7c93738464c00b5233b1ef260bf2182ddb5bd))
* imrpove progress view on home page ([f443f9a](https://github.com/fujiberg/hajiku/commit/f443f9a4ad38ffefba916d9f86d2cf85b03c86ed))
* invalid answer on incorrect reading in kanji ([34761e7](https://github.com/fujiberg/hajiku/commit/34761e715315965d94df1c99ed2946ee0a60d080))
* main view counters ([2ae860e](https://github.com/fujiberg/hajiku/commit/2ae860e4fed2a80b6808b8f8d318c9421a394de1))
* romaji-kana input and progress bar ([c22084d](https://github.com/fujiberg/hajiku/commit/c22084d51d5bc8dafea12dc773796f7463df7f6d))
* warn before abandoning session ([5028120](https://github.com/fujiberg/hajiku/commit/5028120933b1867259e9abd8dfc38f561ba864f4))


### Bug Fixes

* answer after failed API request ([7df9c06](https://github.com/fujiberg/hajiku/commit/7df9c0653e9e74fce3518d44aedbcfda5fb8419e))
* audio playback during review ([988caf4](https://github.com/fujiberg/hajiku/commit/988caf40ec345e9cef3ee9c9495e4fd38c57c7dc))
* buzz on invalid answer ([4e584b4](https://github.com/fujiberg/hajiku/commit/4e584b44568c0b97539e4ca335a06d1994785c28))
* flick popup visibility ([bf9d99f](https://github.com/fujiberg/hajiku/commit/bf9d99f5285805eff5e4d98c29b8f60324c0fd38))
* hide flick keyboard on incorrect answer ([03293dd](https://github.com/fujiberg/hajiku/commit/03293dd167f3a3d69f694dc4d2fe39d1cee6ffe2))
* incorrect answer scroll ([529c425](https://github.com/fujiberg/hajiku/commit/529c42527842cf3c826e71f058bc25f3e3992f56))
* invalid on missing kana in readings ([68d1fae](https://github.com/fujiberg/hajiku/commit/68d1fae91aca43c42364a07bbeef04a0c7b7a853))
* invalid on small kana mismatch ([3462fe1](https://github.com/fujiberg/hajiku/commit/3462fe1c38e91fbcb9acc96dd6c973da6a9315f1))
* keep keyboard open on correct answers ([4020bf8](https://github.com/fujiberg/hajiku/commit/4020bf8a6daf6a1159a80f130a62ad09bf3c82ed))
* prevent audio cutoff ([9f03df3](https://github.com/fujiberg/hajiku/commit/9f03df3f896d6bb441e4256c150774a80bb782f1))
* reload graph after finishing a session ([1a80d24](https://github.com/fujiberg/hajiku/commit/1a80d24d5e3c103c4ec1a929d1a06f7b8df3ac9c))
* svg rendering without css styling ([6d3215c](https://github.com/fujiberg/hajiku/commit/6d3215c3842d09d032a64363f456a609fc36941d))
* use svg for non-unicode radicals ([e45c786](https://github.com/fujiberg/hajiku/commit/e45c786472ba95aa678ba70a523f70208158d7d8))

## Changelog
