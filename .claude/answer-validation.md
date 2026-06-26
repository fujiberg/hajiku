# Answer validation

Answer validation lives entirely in `ReviewSessionController.submitAnswer` (and its private helpers). The UI receives a `SubmitResult` enum (`invalidInput` / `correct` / `incorrect`) and reacts accordingly — it does not re-implement any validation logic itself.

## Reading quizzes

1. Strip all whitespace (including mid-string spaces).
2. Reject as `invalidInput` if any character falls outside hiragana (U+3040–309F) or katakana (U+30A0–30FF).
3. Match exactly against `acceptedReadings` (hiragana strings from the WaniKani API).
4. If no match, check whether the input matches any accepted reading when all small kana are collapsed to their large equivalents (e.g. っ→つ, ゃ→や). If so, reject as `invalidInput` — the user typed the wrong size variant, not a wrong answer. Dakuten (voiced consonants) are unaffected by this check.
5. If still no match, extract the maximal kana runs from `subject.characters` (converting katakana → hiragana) and check that every run appears as a substring in the answer (also converted to hiragana). If any run is missing, reject as `invalidInput` — the user omitted kana that were visible in the subject itself (e.g. typing おおき for 大きい where い is right there). Works correctly for mixed words: 走り書き produces runs ["り","き"], each checked independently.
6. For kanji only: collect the reading types (on'yomi / kun'yomi / nanori) of all accepted readings, then check whether the answer matches any reading whose type is absent from that set. If so, reject as `invalidInput` — the user entered a valid reading of the wrong type (e.g. kun'yomi when on'yomi is expected).

## Meaning quizzes

1. Strip punctuation, collapse runs of whitespace to a single space, trim.
2. Reject as `invalidInput` if the result is empty or contains any kana character.
3. Match against each entry in `acceptedMeanings` using `_meaningMatches`:
   - Always require an exact match (case-insensitive) first.
   - If the accepted answer contains any digit, stop there — no fuzzy matching. ("1000" must not accept "10000".)
   - Otherwise apply Levenshtein tolerance to forgive small typos in English:
     - answer ≤ 3 chars → exact only
     - answer 4–7 chars → distance ≤ 1
     - answer 8+ chars → distance ≤ 2
4. If the answer is incorrect, run it through the romaji-to-kana converter and check if the result matches an accepted reading. If it does, return `invalidInput` — the user typed a reading instead of a meaning. This check is intentionally after step 3 so that meanings that happen to romanise to a reading (e.g. "sensei") are still accepted as correct.

## UI reactions (`_submit` in `_QuizBody`)

| Result         | Reaction                                                                                              |
| -------------- | ----------------------------------------------------------------------------------------------------- |
| `invalidInput` | Shake animation + heavy haptic (`invalidInputHapticFeedbackEnabled`)                                  |
| `correct`      | Light haptic (`hapticFeedbackEnabled`) + audio playback for reading quizzes + auto-advance if enabled |
| `incorrect`    | Heavy haptic (`hapticFeedbackEnabled`)                                                                |
