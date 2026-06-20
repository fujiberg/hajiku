# WaniKani API v2 notes

Notes on how Hajiku talks to the [WaniKani API v2](https://docs.api.wanikani.com). The client lives at
`lib/src/core/wanikani/wanikani_api_client.dart`.

## Auth and headers

- Every request sends `Authorization: Bearer <token>` and `Wanikani-Revision: 20170710`.
- The token comes from `_tokenProvider` (backed by `flutter_secure_storage` via `core/storage/token_storage.dart`). If
  it's missing/empty, the client throws `WaniKaniAuthException` without making a request.
- A `401` response also throws `WaniKaniAuthException` — used to detect a revoked/invalid token.
- Any other non-2xx response throws `WaniKaniApiException(statusCode, message)`.
- Both exceptions implement the sealed `WaniKaniException` (`wanikani_exception.dart`), so callers can catch one type
  for "auth problem, send the user back to onboarding" vs. "API problem, best-effort/ignore".

## Pagination

List endpoints (`assignments`, `subjects`, `level_progressions`) are paginated. `_getAllPages` / the manual
while-loops follow `pages.next_url` until it's `null`, concatenating `data` from every page. Callers always get the
full result set — there's no partial-page API in this client.

## Endpoints in use

- `GET /user` → `getUser()` — validates the token and returns username/level (`WaniKaniUser`).
- `GET /assignments` → `getAssignments({level, srsStages})` — assignments for a given level, defaulting to SRS
  stages 0-4 (everything below Guru, i.e. still needed to level up).
- `GET /assignments?immediately_available_for_review=true` → `getReviewAssignments()`.
- `GET /assignments?immediately_available_for_lessons=true` → `getLessonAssignments()`.
- `GET /assignments?per_page=1&immediately_available_for_lessons=...&immediately_available_for_review=...` →
  `getAssignmentCount(...)` — reads `total_count` from the response to get a count without fetching `data`.
- `GET /subjects?ids=...` → `getSubjects(ids)` — returns `[]` without a request if `ids` is empty (radicals,
  kanji, vocabulary as `WaniKaniSubject`).
- `GET /level_progressions` → `getLevelProgressions()`.
- `POST /reviews` → `submitReview({assignmentId, incorrectMeaningAnswers, incorrectReadingAnswers})` — submits a
  completed review, advancing or resetting the assignment's SRS stage.
- `PUT /assignments/{id}/start` → `startAssignment(assignmentId)` — marks a lesson's assignment as started. Required
  before a review result can be submitted for an item that came from a lesson (an assignment with no `started_at`
  can't receive a review).

## Subject model quirks (`models/wanikani_subject.dart`)

- `characters` is nullable — some radicals have no Unicode representation. Use `displayText` (`characters ?? slug`)
  for anything shown to the user.
- `acceptedMeanings` / `acceptedReadings` are derived getters: meanings/readings with `accepted_answer == true`,
  plus whitelisted `auxiliary_meanings`. Use these for answer checking, not the raw `meanings`/`readings` lists.
- `primaryMeaning` / `primaryReading` pick the entry with `primary == true` (falling back to the first entry) — used
  for "the correct answer was X" feedback.
- `readings` is empty for radicals; `contextSentences` and `pronunciationAudios` are empty for radicals and kanji
  (only vocabulary has them).
- Mnemonic text (`meaningMnemonic`/`readingMnemonic`) contains WaniKani's markup tags (e.g. `<radical>`,
  `<meaning>`) — rendered by `core/widgets/wanikani_markup_text.dart`, not plain text.

## Error handling pattern

Best-effort calls (e.g. starting assignments before a lesson quiz, submitting a review result) catch
`WaniKaniException` and continue rather than failing the whole flow — a failed `start`/`submitReview` for one item
shouldn't block the rest of the session. Auth failures during the main data-fetch path (building a review/lesson
session) are allowed to propagate so the UI can prompt re-authentication.
