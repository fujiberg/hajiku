import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../core/wanikani/models/wanikani_user.dart';
import '../../core/wanikani/wanikani_api_client.dart';

/// Landing screen shown once a WaniKani API token has been validated and
/// stored. Confirms the connection by displaying the user's profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.token,
    required this.onDisconnected,
  });

  final String token;

  /// Called after the stored token has been cleared.
  final VoidCallback onDisconnected;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WaniKaniApiClient _client = WaniKaniApiClient(
    tokenProvider: () async => widget.token,
  );
  late final Future<WaniKaniUser> _userFuture = _client.getUser();

  Future<void> _disconnect() async {
    await TokenStorage().deleteToken();
    widget.onDisconnected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('弾く Hajiku'),
        actions: [
          IconButton(
            onPressed: _disconnect,
            icon: const Icon(Icons.logout),
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<WaniKaniUser>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Failed to load profile: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const CircularProgressIndicator();
            }
            final user = snapshot.data!;
            return Text('Connected as ${user.username} (Level ${user.level})');
          },
        ),
      ),
    );
  }
}
