import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:handover/app/app.dart';
import 'package:handover/providers/auth_provider.dart';
import 'package:handover/providers/handover_provider.dart';
import 'package:handover/providers/profile_provider.dart';
import 'package:handover/providers/theme_provider.dart';

void main() {
  testWidgets('Handover app initial render smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => HandoverProvider()),
        ],
        child: const HandoverApp(),
      ),
    );

    // Initial render should show HANDOVER splash
    expect(find.text('HANDOVER'), findsOneWidget);

    // Advance time past the timer and pump transition
    await tester.pump(const Duration(milliseconds: 2600));
  });
}
