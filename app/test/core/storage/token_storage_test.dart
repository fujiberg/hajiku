import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/core/storage/token_storage.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
  });

  test('readToken returns null when nothing is stored', () async {
    final storage = TokenStorage();

    expect(await storage.readToken(), isNull);
  });

  test('saveToken persists the token for later reads', () async {
    final storage = TokenStorage();

    await storage.saveToken('abc-123');

    expect(await storage.readToken(), 'abc-123');
  });

  test('deleteToken removes the stored token', () async {
    final storage = TokenStorage();
    await storage.saveToken('abc-123');

    await storage.deleteToken();

    expect(await storage.readToken(), isNull);
  });
}
