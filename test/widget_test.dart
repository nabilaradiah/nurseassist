import 'package:flutter_test/flutter_test.dart';

import 'package:nurseassist/main.dart';

void main() {
  testWidgets('NurseAssist app builds without throwing', (WidgetTester tester) async {
    // NurseAssistApp always shows SplashScreen first, which is pure
    // animation (no Firebase calls in initState), so this is safe to pump
    // without a real Firebase test environment. Drain the splash screen's
    // timers (halo pulse at 3300ms, auto-navigate to LoginScreen at 4750ms)
    // and LoginScreen's own fade-in so no pending timers/tickers remain
    // when the test ends.
    await tester.pumpWidget(const NurseAssistApp());
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NurseAssistApp), findsOneWidget);
  });
}
