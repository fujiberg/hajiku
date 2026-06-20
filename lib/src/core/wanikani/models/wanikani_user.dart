/// The authenticated user's WaniKani profile, as returned by `GET /user`.
class WaniKaniUser {
  const WaniKaniUser({required this.username, required this.level});

  factory WaniKaniUser.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return WaniKaniUser(
      username: data['username'] as String,
      level: data['level'] as int,
    );
  }

  final String username;
  final int level;
}
