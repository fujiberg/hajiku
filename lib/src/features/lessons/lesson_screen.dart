import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/resources/resource_providers.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/wanikani/wanikani_exception.dart';
import '../../core/widgets/term_info_panel.dart';
import '../review/models/review_session.dart';
import '../review/review_screen.dart';
import '../review/review_session_controller.dart';
import 'lesson_session_controller.dart';
import 'models/lesson_session.dart';

/// Lets the user browse the lessons picked for this session one at a time,
/// then start a review-style quiz over them.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(lessonSessionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lessons')),
      body: session.when(
        data: (session) {
          if (session.items.isEmpty) return const _EmptyState();
          return _LessonBrowseBody(session: session);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load lessons: $error')),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No lessons available right now.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the current lesson's information and sticky navigation buttons.
class _LessonBrowseBody extends ConsumerWidget {
  const _LessonBrowseBody({required this.session});

  final LessonSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = session.current!.subject;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TermInfoPanel(subject: subject),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: session.isFirst
                        ? null
                        : () => ref
                              .read(lessonSessionControllerProvider.notifier)
                              .back(),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: session.isLast
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () =>
                              _startQuiz(context, ref, session.items),
                          child: const Text('Start quiz'),
                        )
                      : FilledButton(
                          onPressed: () => ref
                              .read(lessonSessionControllerProvider.notifier)
                              .next(),
                          child: const Text('Next'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startQuiz(
    BuildContext context,
    WidgetRef ref,
    List<ReviewItem> items,
  ) async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (settings.submitReviewResultsEnabled) {
      final resources = ref.read(resourceServiceProvider);
      await Future.wait(
        items.map((item) async {
          try {
            await resources.startAssignment(item.assignmentId);
          } on WaniKaniException {
            // Starting an assignment is best-effort: if it fails, the quiz
            // still runs locally, and the later review submission for this
            // item is similarly best-effort.
          }
        }),
      );
    }

    PendingLessonQuizItems.seed(items);

    if (!context.mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              const ReviewScreen(title: 'Lessons', isLessonQuiz: true),
        ),
      ),
    );
  }
}
