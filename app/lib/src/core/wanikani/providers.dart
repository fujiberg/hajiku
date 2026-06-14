import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'models/wanikani_assignment.dart';
import 'models/wanikani_level_progression.dart';
import 'models/wanikani_user.dart';
import 'wanikani_api_client.dart';

/// API client authenticated with the currently stored token, if any.
final wanikaniApiClientProvider = Provider<WaniKaniApiClient>((ref) {
  final token = ref.watch(authControllerProvider).value;
  return WaniKaniApiClient(tokenProvider: () async => token);
});

/// The authenticated user's WaniKani profile.
final wanikaniUserProvider = FutureProvider<WaniKaniUser>((ref) {
  return ref.watch(wanikaniApiClientProvider).getUser();
});

/// Assignments for the user's current level that are not yet at Guru,
/// i.e. the items still needed to level up.
final wanikaniLevelProgressProvider = FutureProvider<List<WaniKaniAssignment>>((
  ref,
) async {
  final user = await ref.watch(wanikaniUserProvider.future);
  return ref.watch(wanikaniApiClientProvider).getAssignments(level: user.level);
});

/// When the user started their current level, or `null` if unavailable.
final wanikaniCurrentLevelStartedAtProvider = FutureProvider<DateTime?>((
  ref,
) async {
  final user = await ref.watch(wanikaniUserProvider.future);
  final progressions = await ref
      .watch(wanikaniApiClientProvider)
      .getLevelProgressions();

  WaniKaniLevelProgression? current;
  for (final progression in progressions) {
    if (progression.level == user.level) current = progression;
  }

  return current?.startedAt;
});

/// Number of lessons currently available to start.
final wanikaniLessonCountProvider = FutureProvider<int>((ref) {
  return ref
      .watch(wanikaniApiClientProvider)
      .getAssignmentCount(immediatelyAvailableForLessons: true);
});

/// Number of reviews currently available to start.
final wanikaniReviewCountProvider = FutureProvider<int>((ref) {
  return ref
      .watch(wanikaniApiClientProvider)
      .getAssignmentCount(immediatelyAvailableForReview: true);
});
