import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/flutter_app_foundation_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('state view exposes visible recovery action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      FoundationTestHarness(
        child: FoundationStateView(
          state: FoundationViewState.error,
          title: 'Could not sync',
          message: 'Your local work is safe.',
          actionLabel: 'Retry',
          onAction: () => retried = true,
        ),
      ),
    );

    expect(find.text('Could not sync'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    expect(retried, isTrue);
  });

  testWidgets('field keeps an explicit label at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const FoundationTestHarness(
        textScale: 2,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: FoundationTextField(label: 'Email address'),
        ),
      ),
    );
    expect(find.text('Email address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
