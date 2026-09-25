import 'package:flutter/material.dart';

import '../design_system/foundation_theme.dart';

final class FoundationTestHarness extends StatelessWidget {
  const FoundationTestHarness({
    required this.child,
    this.brightness = Brightness.light,
    this.textScale = 1,
    super.key,
  });

  final Widget child;
  final Brightness brightness;
  final double textScale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: FoundationTheme.light(),
    darkTheme: FoundationTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
}
