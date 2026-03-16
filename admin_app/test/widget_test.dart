import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/main.dart';

void main() {
  testWidgets('Admin Control Center smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AdminControlCenter());

    // Verify that we show the Dashboard.
    expect(find.text('Dashboard'), findsWidgets);
  });
}
