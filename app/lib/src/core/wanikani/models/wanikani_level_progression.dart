/// A user's progress through a single level, as returned by
/// `GET /level_progressions`.
class WaniKaniLevelProgression {
  const WaniKaniLevelProgression({
    required this.level,
    required this.startedAt,
  });

  factory WaniKaniLevelProgression.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final startedAt = data['started_at'] as String?;
    return WaniKaniLevelProgression(
      level: data['level'] as int,
      startedAt: startedAt == null ? null : DateTime.parse(startedAt),
    );
  }

  final int level;

  /// When the user unlocked the first item of this level, or `null` if
  /// they haven't started it yet.
  final DateTime? startedAt;
}
