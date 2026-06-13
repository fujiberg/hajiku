import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../core/wanikani/wanikani_api_client.dart';
import '../../core/wanikani/wanikani_exception.dart';

/// Lets the user enter their WaniKani API token, validates it against the
/// API, and persists it on success.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onConnected});

  /// Called with the validated token once it has been saved to storage.
  final ValueChanged<String> onConnected;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _tokenController = TextEditingController();
  final _tokenStorage = TokenStorage();
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
      await _tokenStorage.saveToken(token);
      widget.onConnected(token);
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
              'Enter your WaniKani API token. You can generate one at '
              'wanikani.com/settings/personal_access_tokens.',
            ),
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
