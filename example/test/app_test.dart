import 'package:flutter/material.dart';
import 'package:flutter_app_foundation_example/app/app.dart';
import 'package:flutter_app_foundation_example/app/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts, lists todos, and opens a detail page', (tester) async {
    await tester.pumpWidget(ExampleApp(services: AppServices.create()));
    await tester.pumpAndSettle();
    expect(find.text('Read the integration guide'), findsOneWidget);

    await tester.tap(find.byTooltip('Open Ship it'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as done'), findsOneWidget);

    await tester.tap(find.text('Mark as done'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as not done'), findsOneWidget);
  });

  testWidgets('settings switch the theme', (tester) async {
    final services = AppServices.create();
    await tester.pumpWidget(ExampleApp(services: services));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(services.theme.mode, ThemeMode.dark);
    expect(await services.preferences.read('foundation.theme_mode'), 'dark');
  });
}
