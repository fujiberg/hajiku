/// Subscription details from the WaniKani `/user` endpoint.
class WaniKaniSubscription {
  const WaniKaniSubscription({
    required this.active,
    required this.maxLevelGranted,
    required this.type,
    this.periodEndsAt,
  });

  factory WaniKaniSubscription.fromJson(Map<String, dynamic> json) {
    final rawDate = json['period_ends_at'] as String?;
    return WaniKaniSubscription(
      active: json['active'] as bool,
      maxLevelGranted: json['max_level_granted'] as int,
      type: json['type'] as String,
      periodEndsAt: rawDate != null ? DateTime.parse(rawDate) : null,
    );
  }

  /// Whether the subscription is currently active.
  final bool active;

  /// The highest WaniKani level the user may access (3 for free/lapsed, 60 for paid).
  final int maxLevelGranted;

  /// One of: "free", "recurring", "lifetime", "unknown".
  final String type;

  final DateTime? periodEndsAt;

  bool get isLifetime => type == 'lifetime';
  bool get isFree => type == 'free';
  bool get isLapsed => !active && !isFree && !isLifetime;
}

/// The authenticated user's WaniKani profile, as returned by `GET /user`.
class WaniKaniUser {
  const WaniKaniUser({
    required this.username,
    required this.level,
    required this.subscription,
  });

  factory WaniKaniUser.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return WaniKaniUser(
      username: data['username'] as String,
      level: data['level'] as int,
      subscription: WaniKaniSubscription.fromJson(
        data['subscription'] as Map<String, dynamic>,
      ),
    );
  }

  final String username;
  final int level;
  final WaniKaniSubscription subscription;
}
