import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cekicounter/src/app.dart';

void main() {
  testWidgets('Home page visible on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CekiCounterApp()));
    await tester.pumpAndSettle();
    expect(find.text('Ceki League'), findsOneWidget);
  });
}
