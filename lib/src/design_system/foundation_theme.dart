import 'package:flutter/material.dart';

import 'design_tokens.dart';

abstract final class FoundationTheme {
  static ThemeData light({Color? seedColor, bool highContrast = false}) =>
      _theme(Brightness.light, FoundationColors.light, seedColor, highContrast);

  static ThemeData dark({Color? seedColor, bool highContrast = false}) =>
      _theme(Brightness.dark, FoundationColors.dark, seedColor, highContrast);

  static ThemeData _theme(
    Brightness brightness,
    FoundationColors tokens,
    Color? seedColor,
    bool highContrast,
  ) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seedColor ?? Color(tokens.primary),
          brightness: brightness,
          surface: Color(tokens.surface),
          error: Color(tokens.danger),
        ).copyWith(
          primary: Color(tokens.primary),
          onPrimary: Color(tokens.onPrimary),
          onSurface: Color(tokens.onSurface),
          outline: Color(tokens.outline),
        );
    final borderWidth = highContrast ? 2.0 : 1.0;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FoundationRadius.medium),
      borderSide: BorderSide(color: scheme.outline, width: borderWidth),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Color(tokens.background),
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(FoundationRadius.medium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FoundationRadius.small),
          ),
        ),
      ),
    );
  }
}
