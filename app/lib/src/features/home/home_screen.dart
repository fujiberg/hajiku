import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/wanikani/providers.dart';

/// Landing screen shown once a WaniKani API token has been validated and
/// stored. Confirms the connection by displaying the user's profile.
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
            onPressed: () =>
                ref.read(authControllerProvider.notifier).disconnect(),
            icon: const Icon(Icons.logout),
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Center(
        child: user.when(
          data: (user) =>
              Text('Connected as ${user.username} (Level ${user.level})'),
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Text('Failed to load profile: $error'),
        ),
      ),
    );
  }
}
