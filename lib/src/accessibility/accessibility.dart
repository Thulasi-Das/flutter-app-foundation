final class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.reduceMotion = false,
    this.highContrast = false,
    this.boldText = false,
    this.textScale = 1,
  }) : assert(textScale >= 0.8 && textScale <= 3);

  final bool reduceMotion;
  final bool highContrast;
  final bool boldText;
  final double textScale;
}

abstract interface class AccessibilityPreferencesSource {
  AccessibilityPreferences get current;
  Stream<AccessibilityPreferences> get changes;
}

const double minimumAccessibleTouchTarget = 48;
