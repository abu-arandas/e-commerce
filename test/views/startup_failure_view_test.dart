import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/views/shared/startup_failure_view.dart';

void main() {
  testWidgets('explains the outage and invokes retry', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(home: StartupFailureView(onRetry: () => retried = true)),
    );

    expect(find.text('Store temporarily unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
