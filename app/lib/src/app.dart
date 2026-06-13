import 'package:flutter/material.dart';

import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

class HajikuApp extends StatelessWidget {
  const HajikuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hajiku',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _RootScreen(),
    );
  }
}

/// Decides whether to show onboarding or the home screen based on whether a
/// WaniKani API token is already stored on-device.
class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  final _tokenStorage = TokenStorage();
  late Future<String?> _tokenFuture = _tokenStorage.readToken();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final token = snapshot.data;
        if (token == null) {
          return OnboardingScreen(
            onConnected: (token) => setState(() {
              _tokenFuture = Future.value(token);
            }),
          );
        }

        return HomeScreen(
          token: token,
          onDisconnected: () => setState(() {
            _tokenFuture = Future.value(null);
          }),
        );
      },
    );
  }
}
