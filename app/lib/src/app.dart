import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
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
class _RootScreen extends ConsumerWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return switch (authState) {
      AsyncData(value: final token) =>
        token == null ? const OnboardingScreen() : const HomeScreen(),
      AsyncError(:final error) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
