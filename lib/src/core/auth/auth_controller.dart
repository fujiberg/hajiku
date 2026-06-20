import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';

/// Holds the WaniKani API token for the current session, backed by
/// [TokenStorage]. A `null` value means no token is configured.
class AuthController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(tokenStorageProvider).readToken();

  /// Persists [token] and marks the session as connected.
  Future<void> connect(String token) async {
    await ref.read(tokenStorageProvider).saveToken(token);
    state = AsyncData(token);
  }

  /// Clears the stored token and marks the session as disconnected.
  Future<void> disconnect() async {
    await ref.read(tokenStorageProvider).deleteToken();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, String?>(
  AuthController.new,
);
