import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/subject_type_style.dart';
import '../../core/wanikani/models/wanikani_assignment.dart';
import '../../core/wanikani/models/wanikani_user.dart';
import '../../core/wanikani/providers.dart';
import '../lessons/lesson_screen.dart';
import '../review/review_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/review_forecast_chart.dart';
import 'widgets/srs_progress_chart.dart';

/// Landing screen shown once a WaniKani API token has been validated and
/// stored. Shows the user's level progress and entry points into lessons
/// and reviews.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(wanikaniUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('弾く Hajiku'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: user.when(
        data: (user) => _Dashboard(user: user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.user});

  final WaniKaniUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(wanikaniLevelProgressProvider);
    final levelStartedAt = ref.watch(wanikaniCurrentLevelStartedAtProvider);
    final reviewForecast = ref.watch(wanikaniReviewForecastProvider);
    final srsDistribution = ref.watch(wanikaniSrsDistributionProvider);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Level ${user.level}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(width: 8),
            Text(
              levelStartedAt.value == null
                  ? ''
                  : '· ${_daysAtLevel(levelStartedAt.value!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        Row(
          children: [
            Text('Welcome back, ${user.username}'),
            if (user.subscription.isLifetime) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.workspace_premium,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
        if (user.subscription.isFree)
          _SubscriptionBanner(
            message: 'Free plan · levels 1–3 only',
            icon: Icons.info_outline,
            isWarning: false,
          )
        else if (user.subscription.isLapsed)
          _SubscriptionBanner(
            message: 'Subscription inactive · reviews limited to levels 1–3',
            icon: Icons.warning_amber_outlined,
            isWarning: true,
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Lessons',
                count: ref.watch(wanikaniLessonCountProvider),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LessonScreen()),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionButton(
                label: 'Reviews',
                count: ref.watch(wanikaniReviewCountProvider),
                tonal: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ReviewScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('To level up', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        progress.when(
          data: (assignments) => _ProgressTiles(assignments: assignments),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('Failed to load progress: $error'),
        ),
        const SizedBox(height: 24),
        reviewForecast.when(
          data: (assignments) => ReviewForecastChart(assignments: assignments),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('Failed to load forecast: $error'),
        ),
        const SizedBox(height: 16),
        srsDistribution.when(
          data: (distribution) => SrsProgressChart(distribution: distribution),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('Failed to load SRS progress: $error'),
        ),
      ],
    );
  }

  String _daysAtLevel(DateTime startedAt) {
    final days = DateTime.now().difference(startedAt).inDays;
    return days == 0 ? 'started today' : '$days day${days == 1 ? '' : 's'}';
  }
}

/// A "Lessons" or "Reviews" entry point, labelled with the number of items
/// pending and disabled when there's nothing to do.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.count,
    required this.onPressed,
    this.tonal = false,
  });

  final String label;
  final AsyncValue<int> count;
  final VoidCallback onPressed;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final pending = count.value;
    final text = pending == null ? label : '$label ($pending)';
    final enabled = pending == null || pending > 0;

    return tonal
        ? FilledButton.tonal(
            onPressed: enabled ? onPressed : null,
            child: Text(text),
          )
        : FilledButton(
            onPressed: enabled ? onPressed : null,
            child: Text(text),
          );
  }
}

/// Shows, per subject type, how many items at the user's current level are
/// not yet Guru — an indication of what's still needed to level up.
class _ProgressTiles extends StatelessWidget {
  const _ProgressTiles({required this.assignments});

  final List<WaniKaniAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final totals = <WaniKaniSubjectType, int>{};
    final gurued = <WaniKaniSubjectType, int>{};

    for (final assignment in assignments) {
      // Kana vocabulary is shown together with regular vocabulary.
      final type = assignment.subjectType == WaniKaniSubjectType.kanaVocabulary
          ? WaniKaniSubjectType.vocabulary
          : assignment.subjectType;
      totals.update(type, (n) => n + 1, ifAbsent: () => 1);
      if (assignment.srsStage >= 5) {
        gurued.update(type, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    const types = [
      WaniKaniSubjectType.radical,
      WaniKaniSubjectType.kanji,
      WaniKaniSubjectType.vocabulary,
    ];

    return Row(
      children: [
        for (final type in types)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ProgressTile(
                type: type,
                gurued: gurued[type] ?? 0,
                total: totals[type] ?? 0,
              ),
            ),
          ),
      ],
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner({
    required this.message,
    required this.icon,
    required this.isWarning,
  });

  final String message;
  final IconData icon;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isWarning ? colorScheme.error : colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            message,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// A single subject-type tile, colored per WaniKani's item type convention.
class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.type,
    required this.gurued,
    required this.total,
  });

  final WaniKaniSubjectType type;
  final int gurued;
  final int total;

  static const _glyphSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final color = type.color;
    final watermarkColor = color.withValues(alpha: 0.4);
    final mutedColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: watermarkColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.glyph,
                style: TextStyle(
                  fontSize: _glyphSize,
                  fontWeight: FontWeight.bold,
                  color: watermarkColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$gurued',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/$total',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(type.label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

