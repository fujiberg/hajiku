import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../cache/cache_providers.dart';
import '../theme/srs_stage_style.dart';
import 'http_cache_store.dart';
import 'models/wanikani_assignment.dart';
import 'models/wanikani_level_progression.dart';
import 'models/wanikani_user.dart';
import 'wanikani_api_client.dart';

/// Shared store backing the API client's conditional (`ETag`) GET requests.
/// A single instance so cached responses are reused across calls, and so the
/// resource service can clear it when purging the cache.
final httpCacheStoreProvider = Provider<HttpCacheStore>(
  (ref) => InMemoryHttpCacheStore(),
);

/// API client authenticated with the currently stored token, if any.
final wanikaniApiClientProvider = Provider<WaniKaniApiClient>((ref) {
  final token = ref.watch(authControllerProvider).value;
  return WaniKaniApiClient(
    tokenProvider: () async => token,
    cacheStore: ref.watch(httpCacheStoreProvider),
    statsRecorder: ref.watch(cacheStatsRecorderProvider),
  );
});

/// The authenticated user's WaniKani profile.
final wanikaniUserProvider = FutureProvider<WaniKaniUser>((ref) {
  return ref.watch(wanikaniApiClientProvider).getUser();
});

/// All assignments for the user's current level, across all SRS stages.
/// Used to show Guru'd vs total progress per subject type.
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

/// Upcoming reviews due within the next 24 hours (including any overdue),
/// used to chart the review queue's growth over time.
final wanikaniReviewForecastProvider = FutureProvider<List<WaniKaniAssignment>>(
  (ref) {
    return ref
        .watch(wanikaniApiClientProvider)
        .getUpcomingReviewAssignments(
          before: DateTime.now().add(const Duration(hours: 24)),
        );
  },
);

/// Counts, across all levels, of assignments in each [SrsStageBucket].
final wanikaniSrsDistributionProvider =
    FutureProvider<Map<SrsStageBucket, int>>((ref) async {
      final client = ref.watch(wanikaniApiClientProvider);
      final counts = await Future.wait(
        SrsStageBucket.values.map(
          (bucket) => client.getAssignmentCount(srsStages: bucket.stages),
        ),
      );
      return Map.fromIterables(SrsStageBucket.values, counts);
    });
