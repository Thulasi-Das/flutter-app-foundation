import 'package:flutter/material.dart';

import '../preferences/key_value_store.dart';

/// Holds the user's theme mode and optionally persists it.
///
/// ```dart
/// final theme = ThemeController(store: preferences);
/// await theme.load(); // e.g. as a bootstrap step
/// ```
final class ThemeController extends ChangeNotifier {
  ThemeController({
    ThemeMode initial = ThemeMode.system,
    KeyValueStore? store,
    this.storageKey = 'foundation.theme_mode',
  }) : _mode = initial,
       _store = store;

  final KeyValueStore? _store;
  final String storageKey;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// Restores the persisted mode. Unknown stored values are ignored.
  Future<void> load() async {
    final stored = await _store?.read(storageKey);
    final restored = ThemeMode.values.where((mode) => mode.name == stored);
    if (restored.isNotEmpty && restored.first != _mode) {
      _mode = restored.first;
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _store?.write(storageKey, mode.name);
  }
}
