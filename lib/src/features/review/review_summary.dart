import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/subject_type_style.dart';
import '../../core/wanikani/models/wanikani_assignment.dart';
import '../../core/wanikani/providers.dart';
import 'models/review_session.dart';

/// Session summary shown after all review quizzes are answered. Displays a
/// per-type breakdown and overall first-try accuracy, and calls out a level-up
/// if the user's WaniKani level increased during this session.
///
/// There's intentionally no "next reviews/lessons" shortcut here: finishing a
/// session can change what's available, so the user returns to the home screen
/// (via "Done"), which re-prepares the cache before another session.
class ReviewSummary extends ConsumerWidget {
  const ReviewSummary({super.key, required this.items, this.priorLevel});

  final List<ReviewItem> items;

  /// The user's level at the start of the session. If the current level is
  /// higher, a level-up banner is shown.
  final int? priorLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLevel = ref.watch(wanikaniUserProvider).value?.level;
    final leveledUp =
        priorLevel != null &&
        currentLevel != null &&
        currentLevel > priorLevel!;

    final total = items.length;
    final firstTryTotal = items.where(_isFirstTry).length;
    final overallPct = total == 0 ? 0 : firstTryTotal * 100 ~/ total;

    final groups = <WaniKaniSubjectType, List<ReviewItem>>{};
    for (final item in items) {
      final type = item.subject.type == WaniKaniSubjectType.kanaVocabulary
          ? WaniKaniSubjectType.vocabulary
          : item.subject.type;
      groups.putIfAbsent(type, () => []).add(item);
    }

    const orderedTypes = [
      WaniKaniSubjectType.radical,
      WaniKaniSubjectType.kanji,
      WaniKaniSubjectType.vocabulary,
    ];

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leveledUp) ...[
                    _LevelUpBanner(level: currentLevel),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Session complete!',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$total item${total == 1 ? '' : 's'} reviewed',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  for (final type in orderedTypes)
                    if (groups.containsKey(type)) ...[
                      _TypeRow(type: type, items: groups[type]!),
                      const SizedBox(height: 8),
                    ],
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall first try',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$overallPct%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottomInset),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ),
      ],
    );
  }
}

bool _isFirstTry(ReviewItem item) =>
    item.incorrectMeaningAnswers == 0 && item.incorrectReadingAnswers == 0;

class _LevelUpBanner extends StatelessWidget {
  const _LevelUpBanner({required this.level});

  final int? level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF00AAFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00AAFF).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Text(
            '🎉',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Level up!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00AAFF),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (level != null)
            Text(
              'You reached level $level',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.items});

  final WaniKaniSubjectType type;
  final List<ReviewItem> items;

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final firstTry = items.where(_isFirstTry).length;
    final pct = count == 0 ? 0 : firstTry * 100 ~/ count;
    final color = type.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            type.glyph,
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '$count item${count == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 44,
            child: Text(
              '$pct%',
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
