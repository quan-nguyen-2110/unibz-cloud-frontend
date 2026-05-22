import 'package:flutter_test/flutter_test.dart';

import 'package:squadup/main.dart';

void main() {
  testWidgets('App opens feed', (WidgetTester tester) async {
    await tester.pumpWidget(const SquadUpApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Anyone'), findsOneWidget);
  });
}
