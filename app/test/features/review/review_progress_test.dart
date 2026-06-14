import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/wanikani/models/wanikani_assignment.dart';
import 'package:hajiku/src/core/wanikani/models/wanikani_subject.dart';
import 'package:hajiku/src/features/review/models/review_session.dart';
import 'package:hajiku/src/features/review/review_progress.dart';

void main() {
  WaniKaniSubject radicalSubject() => const WaniKaniSubject(
    id: 1,
    type: WaniKaniSubjectType.radical,
    characters: '一',
    slug: 'ground',
    meanings: [
      WaniKaniMeaning(meaning: 'Ground', primary: true, acceptedAnswer: true),
    ],
    auxiliaryMeanings: [],
    readings: [],
  );

  WaniKaniSubject kanjiSubject() => const WaniKaniSubject(
    id: 2,
    type: WaniKaniSubjectType.kanji,
    characters: '一',
    slug: 'one',
    meanings: [
      WaniKaniMeaning(meaning: 'One', primary: true, acceptedAnswer: true),
    ],
    auxiliaryMeanings: [],
    readings: [
      WaniKaniReading(reading: 'いち', primary: true, acceptedAnswer: true),
    ],
  );

  group('buildProgressGroups', () {
    test(
      'groups a two-type item by its first occurrence, in encounter order',
      () {
        final radical = ReviewItem(
          assignmentId: 100,
          subject: radicalSubject(),
        );
        final kanji = ReviewItem(assignmentId: 101, subject: kanjiSubject());

        final radicalMeaning = ReviewQuiz(
          item: radical,
          type: ReviewQuizType.meaning,
        );
        final kanjiReading = ReviewQuiz(
          item: kanji,
          type: ReviewQuizType.reading,
        );
        final kanjiMeaning = ReviewQuiz(
          item: kanji,
          type: ReviewQuizType.meaning,
        );

        // Reading happens to come first for the kanji in the shuffled queue.
        final groups = buildProgressGroups([
          kanjiReading,
          radicalMeaning,
          kanjiMeaning,
        ]);

        expect(groups, hasLength(2));

        expect(groups[0], hasLength(2));
        expect(groups[0][0].item, kanji);
        expect(groups[0][0].type, ReviewQuizType.reading);
        expect(groups[0][1].item, kanji);
        expect(groups[0][1].type, ReviewQuizType.meaning);

        expect(groups[1], hasLength(1));
        expect(groups[1][0].item, radical);
        expect(groups[1][0].type, ReviewQuizType.meaning);
      },
    );
  });

  group('progressSegmentColor', () {
    test('untouched segment is a light tint over the backdrop', () {
      final kanji = ReviewItem(assignmentId: 101, subject: kanjiSubject());
      final radical = ReviewItem(assignmentId: 100, subject: radicalSubject());
      final session = ReviewSessionState(
        queue: [ReviewQuiz(item: kanji, type: ReviewQuizType.meaning)],
        initialQueue: const [],
        totalItems: 2,
        completedItems: 0,
      );

      expect(
        progressSegmentColor(session, radical, ReviewQuizType.meaning),
        Colors.white.withValues(alpha: 0.35),
      );
    });

    test('current segment with no prior mistakes is white', () {
      final kanji = ReviewItem(assignmentId: 101, subject: kanjiSubject());
      final current = ReviewQuiz(item: kanji, type: ReviewQuizType.meaning);
      final session = ReviewSessionState(
        queue: [current],
        initialQueue: const [],
        totalItems: 1,
        completedItems: 0,
      );

      expect(
        progressSegmentColor(session, kanji, ReviewQuizType.meaning),
        Colors.white,
      );
    });

    test('revisiting a previously incorrect segment is bright amber', () {
      final kanji = ReviewItem(assignmentId: 101, subject: kanjiSubject())
        ..incorrectMeaningAnswers = 1;
      final current = ReviewQuiz(item: kanji, type: ReviewQuizType.meaning);
      final session = ReviewSessionState(
        queue: [current],
        initialQueue: const [],
        totalItems: 1,
        completedItems: 0,
      );

      expect(
        progressSegmentColor(session, kanji, ReviewQuizType.meaning),
        Colors.amber.shade200,
      );
    });

    test('a completed segment is green, regardless of other state', () {
      final kanji = ReviewItem(assignmentId: 101, subject: kanjiSubject())
        ..completedTypes.add(ReviewQuizType.meaning);
      final session = ReviewSessionState(
        queue: const [],
        initialQueue: const [],
        totalItems: 1,
        completedItems: 1,
      );

      expect(
        progressSegmentColor(session, kanji, ReviewQuizType.meaning),
        Colors.green.shade500,
      );
    });

    test('a just-answered incorrect segment turns bright red while feedback '
        'is shown, before becoming a pending retry', () {
      final kanji = ReviewItem(assignmentId: 101, subject: kanjiSubject())
        ..incorrectMeaningAnswers = 1;
      final current = ReviewQuiz(item: kanji, type: ReviewQuizType.meaning);
      final session = ReviewSessionState(
        queue: [current],
        initialQueue: const [],
        totalItems: 1,
        completedItems: 0,
        feedback: const ReviewAnswerFeedback(correct: false, answer: 'one'),
      );

      expect(
        progressSegmentColor(session, kanji, ReviewQuizType.meaning),
        Colors.red.shade400,
      );
    });

    test('a mistaken segment awaiting retry stays red', () {
      final kanji = ReviewItem(assignmentId: 101, subject: kanjiSubject())
        ..incorrectMeaningAnswers = 1;
      final radical = ReviewItem(assignmentId: 100, subject: radicalSubject());
      final current = ReviewQuiz(item: radical, type: ReviewQuizType.meaning);
      final session = ReviewSessionState(
        queue: [current],
        initialQueue: const [],
        totalItems: 2,
        completedItems: 0,
      );

      expect(
        progressSegmentColor(session, kanji, ReviewQuizType.meaning),
        Colors.red.shade400,
      );
    });
  });
}
