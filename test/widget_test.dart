import 'package:flutter_test/flutter_test.dart';
import 'package:elitemeet_app/main.dart';

void main() {
  testWidgets('EliteMeet app loads successfully', (WidgetTester tester) async {
    // Build the app.
    await tester.pumpWidget(const EliteMeetApp());

    // Verify that the root widget is loaded.
    expect(find.byType(EliteMeetApp), findsOneWidget);
  });
}