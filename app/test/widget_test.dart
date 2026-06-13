import 'package:flutter_test/flutter_test.dart';

import 'package:hajiku/src/app.dart';

void main() {
  testWidgets('HajikuApp renders the placeholder home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HajikuApp());

    expect(find.text('弾く Hajiku'), findsOneWidget);
  });
}
