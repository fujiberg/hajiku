import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/resources/resource_providers.dart';
import '../../core/settings/settings_controller.dart';
import '../review/review_session_controller.dart';
import 'models/lesson_session.dart';

/// Drives a single lesson browsing session: picks the first
/// `lessonsPerSession` available lessons, in the order WaniKani returns
/// them, and lets the user step through them one at a time.
class LessonSessionController extends AsyncNotifier<LessonSessionState> {
  @override
  Future<LessonSessionState> build() async {
    final resources = ref.watch(resourceServiceProvider);
    final allAssignments = await resources.getLessonAssignments();

    if (allAssignments.isEmpty) {
      return const LessonSessionState(items: [], currentIndex: 0);
    }

    final settings = await ref.watch(settingsControllerProvider.future);
    final assignments = allAssignments
        .take(settings.lessonsPerSession)
        .toList();

    final items = await fetchReviewItems(resources, assignments);

    return LessonSessionState(items: items, currentIndex: 0);
  }

  /// Moves to the previous lesson, if not already on the first one.
  void back() {
    final session = state.value;
    if (session == null || session.isFirst) return;
    state = AsyncData(session.copyWith(currentIndex: session.currentIndex - 1));
  }

  /// Moves to the next lesson, if not already on the last one.
  void next() {
    final session = state.value;
    if (session == null || session.isLast) return;
    state = AsyncData(session.copyWith(currentIndex: session.currentIndex + 1));
  }
}

final lessonSessionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      LessonSessionController,
      LessonSessionState
    >(LessonSessionController.new);
