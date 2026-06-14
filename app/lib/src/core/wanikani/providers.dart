import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'models/wanikani_user.dart';
import 'wanikani_api_client.dart';

/// API client authenticated with the currently stored token, if any.
final wanikaniApiClientProvider = Provider<WaniKaniApiClient>((ref) {
  final token = ref.watch(authControllerProvider).value;
  return WaniKaniApiClient(tokenProvider: () async => token);
});

/// The authenticated user's WaniKani profile.
final wanikaniUserProvider = FutureProvider<WaniKaniUser>((ref) {
  return ref.watch(wanikaniApiClientProvider).getUser();
});
