import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/cache/cache_providers.dart';
import '../../core/cache/cache_stats.dart';
import '../../core/resources/resource_providers.dart';
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
        const _SectionHeader('Voice audio & storage'),
        SwitchListTile(
          title: const Text('Cache voice audio'),
          subtitle: const Text(
            'Download pronunciation audio to play offline. Turn off to stream '
            'it on demand and save space',
          ),
          value: settings.cacheVoiceData,
          onChanged: controller.setCacheVoiceData,
        ),
        SwitchListTile(
          title: const Text('Voice over Wi-Fi only'),
          subtitle: Text(
            settings.cacheVoiceData
                ? 'Only download audio automatically on Wi-Fi. Tapping a play '
                      'button still works on mobile data'
                : 'Only play audio automatically on Wi-Fi. Tapping a play '
                      'button still works on mobile data',
          ),
          value: settings.voiceWifiOnly,
          onChanged: controller.setVoiceWifiOnly,
        ),
        const _CacheStatsView(),
        ListTile(
          title: const Text('Clear cached data'),
          subtitle: const Text(
            'Remove downloaded subjects and audio, and reset these statistics',
          ),
          leading: const Icon(Icons.delete_outline),
          onTap: () => _confirmPurge(context, ref),
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

  /// Confirms, then deletes all cached subjects and audio. The home screen
  /// re-downloads what's needed the next time it prepares a session.
  Future<void> _confirmPurge(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cached data?'),
        content: const Text(
          'Downloaded subjects and audio will be removed. They will be '
          'fetched again the next time you start lessons or reviews.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(resourceServiceProvider).purge();
    // Re-prepare the cache: this re-downloads what's needed and, via the
    // dependency in cacheContentsProvider, refreshes the statistics below.
    ref.invalidate(cachePreparationProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared — re-downloading…')),
      );
    }
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

/// Compact, informational view of what's cached and how the cache has
/// performed since it was last cleared. The contents (terms/voices) are a
/// snapshot; the request counters update live.
class _CacheStatsView extends ConsumerWidget {
  const _CacheStatsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(cacheContentsProvider);
    final recorder = ref.watch(cacheStatsRecorderProvider);

    return ValueListenableBuilder<CacheStats>(
      valueListenable: recorder.listenable,
      builder: (context, stats, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              contents.maybeWhen(
                data: (c) => Column(
                  children: [
                    _StatRow(label: 'Terms cached', value: '${c.terms}'),
                    _StatRow(
                      label: 'Voices cached',
                      value: c.voices == 0
                          ? '0'
                          : '${c.voices} · ${_formatBytes(c.voiceBytes)}',
                    ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              _StatRow(
                label: 'Cache hits (spared calls)',
                value: '${stats.cacheHits}',
              ),
              _StatRow(
                label: 'Network requests',
                value: '${stats.networkRequests}',
              ),
              _StatRow(label: 'Re-fetched', value: '${stats.fetched}'),
              _StatRow(
                label: 'Uncacheable requests',
                value: '${stats.uncacheable}',
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// A single label/value row in the cache statistics view.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
