final class FoundationColors {
  const FoundationColors({
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.onSurface,
    required this.background,
    required this.outline,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final int primary;
  final int onPrimary;
  final int surface;
  final int onSurface;
  final int background;
  final int outline;
  final int success;
  final int warning;
  final int danger;

  static const light = FoundationColors(
    primary: 0xFF3157D5,
    onPrimary: 0xFFFFFFFF,
    surface: 0xFFFFFFFF,
    onSurface: 0xFF161A22,
    background: 0xFFF7F8FC,
    outline: 0xFFD9DEE9,
    success: 0xFF16845B,
    warning: 0xFF9A6700,
    danger: 0xFFC9363E,
  );

  static const dark = FoundationColors(
    primary: 0xFF9AAEFF,
    onPrimary: 0xFF0A2267,
    surface: 0xFF1A1D27,
    onSurface: 0xFFF0F1F6,
    background: 0xFF11131A,
    outline: 0xFF3A3F4F,
    success: 0xFF62D6A5,
    warning: 0xFFFFC45A,
    danger: 0xFFFF8E94,
  );
}

abstract final class FoundationSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class FoundationRadius {
  static const double small = 6;
  static const double medium = 10;
  static const double large = 16;
  static const double pill = 999;
}

abstract final class FoundationMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration deliberate = Duration(milliseconds: 360);
}
