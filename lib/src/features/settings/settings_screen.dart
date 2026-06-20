import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
        const Divider(),
        const _SectionHeader('Haptic feedback'),
        SwitchListTile(
          title: const Text('Haptic feedback'),
          subtitle: const Text(
            'Quick buzz for correct answers, longer buzz for mistakes',
          ),
          value: settings.hapticFeedbackEnabled,
          onChanged: controller.setHapticFeedbackEnabled,
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
        const _SectionHeader('Keyboard'),
        SwitchListTile(
          title: const Text('Flick kana keyboard'),
          subtitle: const Text(
            'Use the built-in flick keyboard for reading quizzes instead of '
            'the system keyboard',
          ),
          value: settings.flickKeyboardEnabled,
          onChanged: controller.setFlickKeyboardEnabled,
        ),
        SwitchListTile(
          title: const Text('Submit with flick keyboard'),
          subtitle: const Text(
            'Lets the flick keyboard\'s Submit key submit an answer',
          ),
          value: settings.flickKeyboardSubmitEnabled,
          onChanged: controller.setFlickKeyboardSubmitEnabled,
        ),
        SwitchListTile(
          title: const Text('Submit with Enter key'),
          subtitle: const Text(
            'On the system keyboard. Turn off to require tapping Submit, to '
            'avoid accidentally submitting when you meant Backspace',
          ),
          value: settings.keyboardSubmitEnabled,
          onChanged: controller.setKeyboardSubmitEnabled,
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
        const Divider(),
        const _SectionHeader('About'),
        ListTile(
          titleAlignment: ListTileTitleAlignment.titleHeight,
          title: const Text('Educational content'),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'wanikani.com',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              const Text('copyright © Tofugu LLC'),
              const Text('Hajiku is not affiliated with Tofugu'),
            ],
          ),
          leading: const Icon(Icons.school_outlined),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => launchUrl(
            Uri.parse('https://www.wanikani.com'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        ListTile(
          titleAlignment: ListTileTitleAlignment.titleHeight,
          title: const Text('Hajiku is open source'),
          subtitle: Text(
            'github.com/fujiberg/hajiku',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          leading: const Icon(Icons.code),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => launchUrl(
            Uri.parse('https://github.com/fujiberg/hajiku'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        ListTile(
          titleAlignment: ListTileTitleAlignment.titleHeight,
          title: const Text('Feedback & issues'),
          subtitle: Text(
            'github.com/fujiberg/hajiku/issues',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          leading: const Icon(Icons.bug_report_outlined),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => launchUrl(
            Uri.parse('https://github.com/fujiberg/hajiku/issues'),
            mode: LaunchMode.externalApplication,
          ),
        ),
        ListTile(
          title: const Text('Open-source licenses'),
          leading: const Icon(Icons.description_outlined),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Hajiku',
            applicationLegalese: '© 2026 Fujiberg. MIT License.',
          ),
        ),
        const Divider(),
        const _SectionHeader('Developer'),
        SwitchListTile(
          title: const Text('Dry run mode'),
          subtitle: const Text(
            'Disable submission of review results to WaniKani — use this to '
            'test the review flow without affecting your SRS progress',
          ),
          value: !settings.submitReviewResultsEnabled,
          onChanged: (value) =>
              controller.setSubmitReviewResultsEnabled(!value),
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
