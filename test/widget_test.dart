import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hajiku/src/app.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
  });

  testWidgets('HajikuApp shows onboarding when no token is stored', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HajikuApp()));
    await tester.pumpAndSettle();

    expect(find.text('Connect to WaniKani'), findsOneWidget);
  });
}
