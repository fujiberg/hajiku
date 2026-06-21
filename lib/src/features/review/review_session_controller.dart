import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/resources/resource_providers.dart';
import '../../core/resources/resource_service.dart';
import '../../core/romaji/romaji_converter.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/wanikani/models/wanikani_assignment.dart';
import '../../core/wanikani/wanikani_exception.dart';
import 'models/review_session.dart';

/// Fetches the subjects for [assignments] and pairs each with its assignment
/// into a [ReviewItem], in the given order. Assignments whose subject can't be
/// fetched are dropped. Shared by the review and lesson session controllers.
///
/// Subjects come from the resource service's cache (populated by the home
/// screen's preparation step), so this is a fast, network-free load.
Future<List<ReviewItem>> fetchReviewItems(
  ResourceService resources,
  List<WaniKaniAssignment> assignments,
) async {
  final subjectIds = assignments.map((a) => a.subjectId).toList();
  final (subjects, materialsById) = await (
    resources.subjectsFor(subjectIds, revalidate: false),
    resources.studyMaterialsFor(subjectIds),
  ).wait;
  final subjectsById = {for (final subject in subjects) subject.id: subject};
  return [
    for (final assignment in assignments)
      if (subjectsById[assignment.subjectId] case final subject?)
        ReviewItem(
          assignmentId: assignment.id,
          subject: subject,
          meaningSynonyms:
              materialsById[subject.id]?.meaningSynonyms ?? const [],
        ),
  ];
}

/// One-shot "seed" slot for starting a review session from a fixed,
/// already-fetched set of items (e.g. the lesson quiz) instead of fetching
/// due reviews from WaniKani. Set just before navigating to [ReviewScreen],
/// and consumed/cleared by [ReviewSessionController.build].
///
/// This is intentionally a plain static holder rather than a provider:
/// Riverpod disallows a provider from writing to another provider's state
/// while it is still building, which a consume-during-build pattern would
/// require.
abstract final class PendingLessonQuizItems {
  static List<ReviewItem>? _items;

  /// Seeds the next review session with [items].
  static void seed(List<ReviewItem> items) => _items = items;

  /// Returns the seeded items, if any, and clears them.
  static List<ReviewItem>? consume() {
    final items = _items;
    _items = null;
    return items;
  }
}

/// Drives a single review session: builds the initial quiz queue, checks
/// answers, and reports completed items back to WaniKani.
class ReviewSessionController extends AsyncNotifier<ReviewSessionState> {
  @override
  Future<ReviewSessionState> build() async {
    final seeded = PendingLessonQuizItems.consume();
    if (seeded != null) {
      return _stateFor(seeded);
    }

    final resources = ref.watch(resourceServiceProvider);
    final allAssignments = await resources.getReviewAssignments();

    if (allAssignments.isEmpty) return const ReviewSessionState.empty();

    final settings = await ref.watch(settingsControllerProvider.future);
    allAssignments.shuffle(Random());
    final assignments = allAssignments
        .take(settings.reviewsPerSession)
        .toList();

    return _stateFor(await fetchReviewItems(resources, assignments));
  }

  /// Builds the initial session state for [items], or an empty session if
  /// there are none.
  ReviewSessionState _stateFor(List<ReviewItem> items) {
    if (items.isEmpty) return const ReviewSessionState.empty();
    final queue = buildQuizQueue(items);
    return ReviewSessionState(
      queue: queue,
      initialQueue: List.of(queue),
      totalItems: items.length,
      completedItems: 0,
    );
  }

  /// Validates [input] and, if valid, checks it against the current quiz and
  /// records the result as feedback. Does not advance the queue — call [next]
  /// once the user has seen the result.
  SubmitResult submitAnswer(String input) {
    final session = state.value;
    if (session == null || session.feedback != null) {
      return SubmitResult.invalidInput;
    }

    final quiz = session.current;
    if (quiz == null) return SubmitResult.invalidInput;

    final bool correct;
    if (quiz.type == ReviewQuizType.reading) {
      final normalized = _normalizeReading(input);
      if (normalized.isEmpty || !_isAllKana(normalized)) {
        return SubmitResult.invalidInput;
      }
      correct = quiz.item.subject.acceptedReadings.contains(normalized);
      if (!correct) {
        final collapsedInput = _collapseSmallKana(normalized);
        if (quiz.item.subject.acceptedReadings.any(
          (r) => _collapseSmallKana(r) == collapsedInput,
        )) {
          return SubmitResult.invalidInput;
        }
        final characters = quiz.item.subject.characters;
        if (characters != null) {
          final runs = _kanaRuns(characters);
          final answerHiragana = _toHiragana(normalized);
          if (runs.isNotEmpty && !runs.every(answerHiragana.contains)) {
            return SubmitResult.invalidInput;
          }
        }
      }
    } else {
      final normalized = _normalizeMeaning(input);
      if (normalized.isEmpty || _containsKana(normalized)) {
        return SubmitResult.invalidInput;
      }
      correct =
          quiz.item.subject.acceptedMeanings.any(
            (meaning) => _meaningMatches(normalized, meaning),
          ) ||
          quiz.item.meaningSynonyms.any(
            (synonym) => _meaningMatches(normalized, synonym),
          );
      // If incorrect, check whether the input is romaji for an accepted reading.
      // If so, the user typed a reading instead of a meaning — treat as invalid
      // rather than wrong. This check must come after the correctness check so
      // that meanings that happen to romanise to a reading (e.g. "sensei") are
      // still accepted.
      if (!correct) {
        final asKana = RomajiConverter.convert(normalized, isFinal: true).kana;
        if (quiz.item.subject.acceptedReadings.contains(asKana)) {
          return SubmitResult.invalidInput;
        }
      }
    }

    if (correct) {
      quiz.item.completedTypes.add(quiz.type);
    } else if (quiz.type == ReviewQuizType.meaning) {
      quiz.item.incorrectMeaningAnswers++;
    } else {
      quiz.item.incorrectReadingAnswers++;
    }

    state = AsyncData(
      session.copyWith(
        feedback: ReviewAnswerFeedback(correct: correct),
        hasCorrectAnswer: session.hasCorrectAnswer || correct,
      ),
    );

    return correct ? SubmitResult.correct : SubmitResult.incorrect;
  }

  /// Advances past the current quiz's feedback. Quizzes answered
  /// incorrectly are re-queued at a random later position to be retried.
  Future<void> next() async {
    final session = state.value;
    if (session == null || session.feedback == null) return;

    final quiz = session.queue.first;
    final remaining = session.queue.skip(1).toList();
    var completedItems = session.completedItems;
    final justCompleted = session.feedback!.correct && quiz.item.isComplete;

    if (session.feedback!.correct) {
      if (justCompleted) completedItems++;
    } else {
      // Re-queue at a random later position, but never immediately next, so
      // the user gets at least one other question before a retry.
      final retryQuiz = ReviewQuiz(item: quiz.item, type: quiz.type);
      final insertIndex = remaining.isEmpty
          ? 0
          : 1 + Random().nextInt(remaining.length);
      remaining.insert(insertIndex, retryQuiz);
    }

    state = AsyncData(
      session.copyWith(
        queue: remaining,
        completedItems: completedItems,
        clearFeedback: true,
      ),
    );

    if (justCompleted) {
      try {
        await _submitReview(quiz.item);
      } on WaniKaniException {
        // Reporting to WaniKani is best-effort: the local session has
        // already advanced and shouldn't be blocked by a failed sync.
      }
    }
  }

  /// Converts katakana code points to their hiragana equivalents (offset 0x60).
  String _toHiragana(String s) => String.fromCharCodes(
    s.runes.map((r) => (r >= 0x30A1 && r <= 0x30F6) ? r - 0x60 : r),
  );

  /// Returns each maximal run of kana characters in [s], converted to
  /// hiragana. Used to check that okurigana visible in the subject's
  /// characters are also present in the user's answer.
  List<String> _kanaRuns(String s) {
    final runs = <String>[];
    final buf = StringBuffer();
    for (final r in s.runes) {
      final isKana =
          (r >= 0x3041 && r <= 0x3096) || (r >= 0x30A1 && r <= 0x30F6);
      if (isKana) {
        buf.writeCharCode((r >= 0x30A1 && r <= 0x30F6) ? r - 0x60 : r);
      } else {
        if (buf.isNotEmpty) {
          runs.add(buf.toString());
          buf.clear();
        }
      }
    }
    if (buf.isNotEmpty) runs.add(buf.toString());
    return runs;
  }

  static const _smallToLarge = {
    'ぁ': 'あ', 'ぃ': 'い', 'ぅ': 'う', 'ぇ': 'え', 'ぉ': 'お',
    'っ': 'つ',
    'ゃ': 'や', 'ゅ': 'ゆ', 'ょ': 'よ',
    'ゎ': 'わ', 'ゕ': 'か', 'ゖ': 'け',
    'ァ': 'ア', 'ィ': 'イ', 'ゥ': 'ウ', 'ェ': 'エ', 'ォ': 'オ',
    'ッ': 'ツ',
    'ャ': 'ヤ', 'ュ': 'ユ', 'ョ': 'ヨ',
    'ヮ': 'ワ', 'ヵ': 'カ', 'ヶ': 'ケ',
  };

  String _collapseSmallKana(String s) =>
      s.split('').map((ch) => _smallToLarge[ch] ?? ch).join();

  /// Strips all whitespace from a reading input.
  String _normalizeReading(String input) => input.replaceAll(RegExp(r'\s'), '');

  /// Returns true if every character in [input] is hiragana or katakana.
  bool _isAllKana(String input) => input.runes.every(
    (r) =>
        (r >= 0x3040 && r <= 0x309F) || // hiragana
        (r >= 0x30A0 && r <= 0x30FF),
  ); // katakana

  /// Returns true if [input] contains any hiragana or katakana character.
  bool _containsKana(String input) => input.runes.any(
    (r) => (r >= 0x3040 && r <= 0x309F) || (r >= 0x30A0 && r <= 0x30FF),
  );

  /// Strips punctuation and collapses internal whitespace for a meaning input.
  String _normalizeMeaning(String input) => input
      .replaceAll(RegExp(r"[^\w\s]"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Returns true if [answer] is close enough to [accepted] to count as
  /// correct. Allowed Levenshtein distance scales with answer length:
  ///   ≤ 3 chars → exact, 4–7 chars → 1, 8+ chars → 2.
  /// Answers containing digits are always matched exactly (e.g. "10000" must
  /// not be accepted for "100000").
  bool _meaningMatches(String answer, String accepted) {
    final a = answer.toLowerCase();
    final b = accepted.toLowerCase();
    if (a == b) return true;
    if (accepted.contains(RegExp(r'\d'))) return false;
    final threshold = a.length <= 3
        ? 0
        : a.length <= 7
        ? 1
        : 2;
    if (threshold == 0) return false;
    return _levenshtein(a, b) <= threshold;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final row = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var prev = row[0];
      row[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final temp = row[j];
        row[j] = a[i - 1] == b[j - 1]
            ? prev
            : 1 + [prev, row[j], row[j - 1]].reduce((x, y) => x < y ? x : y);
        prev = temp;
      }
    }
    return row[b.length];
  }

  Future<void> _submitReview(ReviewItem item) async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (!settings.submitReviewResultsEnabled) return;

    // This runs after the session has advanced, and (with auto-advance) from a
    // delayed callback - the auto-dispose provider may have been disposed in
    // the meantime, e.g. if the user left the screen. Reading another provider
    // through a disposed ref throws, so bail out instead.
    if (!ref.mounted) return;

    await ref
        .read(resourceServiceProvider)
        .submitReview(
          assignmentId: item.assignmentId,
          incorrectMeaningAnswers: item.incorrectMeaningAnswers,
          incorrectReadingAnswers: item.incorrectReadingAnswers,
        );
  }
}

final reviewSessionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ReviewSessionController,
      ReviewSessionState
    >(ReviewSessionController.new);
