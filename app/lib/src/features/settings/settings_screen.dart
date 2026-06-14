import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/settings/models/app_settings.dart';
import '../../core/settings/settings_controller.dart';
import '../onboarding/onboarding_screen.dart';

/// Lets the user customize lesson/review behavior and manage their WaniKani
/// connection.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        data: (settings) => _SettingsList(settings: settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load settings: $error')),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);

    return ListView(
      children: [
        const _SectionHeader('Lessons & reviews'),
        ListTile(
          title: const Text('Lessons per session'),
          subtitle: Slider(
            value: settings.lessonsPerSession.toDouble(),
            min: 3,
            max: 15,
            divisions: 12,
            label: '${settings.lessonsPerSession}',
            onChanged: (value) =>
                controller.setLessonsPerSession(value.round()),
          ),
          trailing: Text('${settings.lessonsPerSession}'),
        ),
        ListTile(
          title: const Text('Reviews per session'),
          subtitle: Slider(
            value: settings.reviewsPerSession.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            label: '${settings.reviewsPerSession}',
            onChanged: (value) =>
                controller.setReviewsPerSession(value.round()),
          ),
          trailing: Text('${settings.reviewsPerSession}'),
        ),
        const Divider(),
        const _SectionHeader('Review experience'),
        SwitchListTile(
          title: const Text('Haptic feedback'),
          subtitle: const Text(
            'Quick buzz for correct answers, longer buzz for mistakes',
          ),
          value: settings.hapticFeedbackEnabled,
          onChanged: controller.setHapticFeedbackEnabled,
        ),
        SwitchListTile(
          title: const Text('Auto-advance'),
          subtitle: const Text(
            'Continue to the next question after a correct answer',
          ),
          value: settings.autoAdvanceEnabled,
          onChanged: controller.setAutoAdvanceEnabled,
        ),
        SwitchListTile(
          title: const Text('Vocabulary audio'),
          subtitle: const Text('Play pronunciation after answering'),
          value: settings.vocabAudioEnabled,
          onChanged: controller.setVocabAudioEnabled,
        ),
        SwitchListTile(
          title: const Text('Submit with Enter key'),
          subtitle: const Text(
            'Turn off to require tapping Submit, to avoid accidentally '
            'submitting when you meant Backspace',
          ),
          value: settings.keyboardSubmitEnabled,
          onChanged: controller.setKeyboardSubmitEnabled,
        ),
        SwitchListTile(
          title: const Text('Haptic feedback for invalid answers'),
          subtitle: const Text(
            'Vibrate when Submit is pressed with an empty answer',
          ),
          value: settings.invalidInputHapticFeedbackEnabled,
          onChanged: controller.setInvalidInputHapticFeedbackEnabled,
        ),
        const Divider(),
        const _SectionHeader('Developer'),
        SwitchListTile(
          title: const Text('Submit review results to WaniKani'),
          subtitle: const Text(
            'Turn off to test the review flow with sample data without '
            'affecting your WaniKani SRS progress',
          ),
          value: settings.submitReviewResultsEnabled,
          onChanged: controller.setSubmitReviewResultsEnabled,
        ),
        const Divider(),
        const _SectionHeader('Account'),
        ListTile(
          title: const Text('Change API token'),
          leading: const Icon(Icons.key_outlined),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
          ),
        ),
        ListTile(
          title: const Text('Log out'),
          leading: const Icon(Icons.logout),
          onTap: () => ref.read(authControllerProvider.notifier).disconnect(),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
