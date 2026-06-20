import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/auth/auth_controller.dart';
import 'package:hajiku/src/core/storage/token_storage.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
  });

  test('build returns null when no token is stored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(authControllerProvider.future), isNull);
  });

  test('connect persists the token and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).connect('abc-123');

    expect(container.read(authControllerProvider).value, 'abc-123');
    expect(await container.read(tokenStorageProvider).readToken(), 'abc-123');
  });

  test('disconnect clears the token and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).connect('abc-123');

    await container.read(authControllerProvider.notifier).disconnect();

    expect(container.read(authControllerProvider).value, isNull);
    expect(await container.read(tokenStorageProvider).readToken(), isNull);
  });
}
