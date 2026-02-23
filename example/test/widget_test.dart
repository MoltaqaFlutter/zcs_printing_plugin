import 'package:flutter_test/flutter_test.dart';
import 'package:zcs_printing_example/main.dart';

void main() {
  testWidgets('Example app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('ZCS Printing Example'), findsOneWidget);
    
    // Verify that status text is displayed
    expect(find.textContaining('Status'), findsOneWidget);
  });
}
