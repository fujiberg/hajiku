import 'package:flutter/material.dart';

import 'models/review_session.dart';

/// Groups [initialQueue] into the segments shown by the review progress bar:
/// one group per review item, in the order each item is first encountered.
/// Items needing both a meaning and a reading quiz get a two-segment group
/// (in first-encountered order); items needing only one get a single-segment
/// group.
List<List<ReviewQuiz>> buildProgressGroups(List<ReviewQuiz> initialQueue) {
  final groups = <List<ReviewQuiz>>[];
  final seen = <ReviewItem>{};
  for (final quiz in initialQueue) {
    if (!seen.add(quiz.item)) continue;
    final required = quiz.item.requiredTypes;
    if (required.length == 1) {
      groups.add([quiz]);
    } else {
      final otherType = required.firstWhere((type) => type != quiz.type);
      groups.add([quiz, ReviewQuiz(item: quiz.item, type: otherType)]);
    }
  }
  return groups;
}

/// The color for the progress bar segment representing [item]'s [type]
/// quiz, based on whether it's been answered correctly, is currently being
/// asked, or has previously been answered incorrectly.
Color progressSegmentColor(
  ReviewSessionState session,
  ReviewItem item,
  ReviewQuizType type,
) {
  final incorrectAnswers = type == ReviewQuizType.meaning
      ? item.incorrectMeaningAnswers
      : item.incorrectReadingAnswers;
  final current = session.current;
  final isCurrent =
      current != null && current.item == item && current.type == type;

  if (item.completedTypes.contains(type)) return Colors.green.shade500;
  if (isCurrent && session.feedback == null) {
    return incorrectAnswers > 0 ? Colors.amber.shade200 : Colors.white;
  }
  if (incorrectAnswers > 0) return Colors.red.shade400;
  return Colors.white.withValues(alpha: 0.35);
}
