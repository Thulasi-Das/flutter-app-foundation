import 'dart:async';

import 'package:flutter/widgets.dart';

import '../accessibility/accessibility.dart';
import '../lifecycle/lifecycle.dart';

/// [LifecycleMonitor] backed by Flutter's [AppLifecycleListener].
final class FlutterLifecycleMonitor implements LifecycleMonitor {
  FlutterLifecycleMonitor()
    : _current = _map(
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      ) {
    _listener = AppLifecycleListener(
      onStateChange: (state) {
        _current = _map(state);
        _changes.add(_current);
      },
    );
  }

  late final AppLifecycleListener _listener;
  final StreamController<ApplicationLifecycle> _changes =
      StreamController<ApplicationLifecycle>.broadcast();
  ApplicationLifecycle _current;

  @override
  ApplicationLifecycle get current => _current;

  @override
  Stream<ApplicationLifecycle> get changes => _changes.stream;

  static ApplicationLifecycle _map(AppLifecycleState state) => switch (state) {
    AppLifecycleState.detached => ApplicationLifecycle.detached,
    AppLifecycleState.resumed => ApplicationLifecycle.resumed,
    AppLifecycleState.inactive => ApplicationLifecycle.inactive,
    AppLifecycleState.hidden => ApplicationLifecycle.hidden,
    AppLifecycleState.paused => ApplicationLifecycle.paused,
  };

  Future<void> dispose() {
    _listener.dispose();
    return _changes.close();
  }
}

/// [AccessibilityPreferencesSource] reading the platform's accessibility
/// features and text scale.
final class FlutterAccessibilityPreferencesSource
    with WidgetsBindingObserver
    implements AccessibilityPreferencesSource {
  FlutterAccessibilityPreferencesSource() : _current = _read() {
    WidgetsBinding.instance.addObserver(this);
  }

  final StreamController<AccessibilityPreferences> _changes =
      StreamController<AccessibilityPreferences>.broadcast();
  AccessibilityPreferences _current;

  @override
  AccessibilityPreferences get current => _current;

  @override
  Stream<AccessibilityPreferences> get changes => _changes.stream;

  static AccessibilityPreferences _read() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final features = dispatcher.accessibilityFeatures;
    return AccessibilityPreferences(
      reduceMotion: features.disableAnimations || features.reduceMotion,
      highContrast: features.highContrast,
      boldText: features.boldText,
      textScale: dispatcher.textScaleFactor.clamp(0.8, 3).toDouble(),
    );
  }

  void _refresh() {
    _current = _read();
    _changes.add(_current);
  }

  @override
  void didChangeAccessibilityFeatures() => _refresh();

  @override
  void didChangeTextScaleFactor() => _refresh();

  Future<void> dispose() {
    WidgetsBinding.instance.removeObserver(this);
    return _changes.close();
  }
}
