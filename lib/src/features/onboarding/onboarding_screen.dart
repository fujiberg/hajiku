import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/wanikani/wanikani_api_client.dart';
import '../../core/wanikani/wanikani_exception.dart';

/// Lets the user enter their WaniKani API token, validates it against the
/// API, and persists it on success.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Enter your WaniKani API token.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final client = WaniKaniApiClient(tokenProvider: () async => token);

    try {
      await client.getUser();
      await ref.read(authControllerProvider.notifier).connect(token);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on WaniKaniAuthException {
      setState(() => _errorMessage = 'That token was rejected by WaniKani.');
    } on WaniKaniApiException catch (e) {
      setState(
        () => _errorMessage = 'WaniKani request failed (${e.statusCode}).',
      );
    } catch (e) {
      setState(() => _errorMessage = 'Could not reach WaniKani: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to WaniKani')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Hajiku requires a WaniKani account. A free account gives access '
              'to levels 1–3; a subscription unlocks all 60 levels.',
            ),
            const SizedBox(height: 4),
            _LinkButton(
              label: 'Sign up at wanikani.com',
              url: 'https://www.wanikani.com',
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your WaniKani API token below. You can generate one in '
              'your WaniKani personal access token settings.',
            ),
            const SizedBox(height: 4),
            _LinkButton(
              label: 'Open token settings',
              url: 'https://www.wanikani.com/settings/personal_access_tokens',
            ),
            const SizedBox(height: 8),
            const Text('Enable these permissions when creating your token:'),
            const SizedBox(height: 4),
            const _ScopeChips(),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'API token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _connect(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _connect,
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeChips extends StatelessWidget {
  const _ScopeChips();

  static const _scopes = ['assignments:start', 'reviews:create'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final scope in _scopes)
          Chip(
            label: Text(
              scope,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new, size: 14),
        label: Text(label),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
