import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/app_state_widgets.dart';
import '../localization/foundation_strings.dart';
import '../observability/observability.dart';

/// Starts an app with production error handling installed.
///
/// - Flutter framework errors, uncaught async errors, and errors thrown while
///   building the root widget are sent to [crashReporter].
/// - In release builds, a widget that fails to build renders a neutral
///   placeholder instead of the red error screen.
/// - If [appBuilder] throws (for example invalid configuration), a minimal
///   failure screen is shown instead of a blank app.
///
/// ```dart
/// Future<void> main() => runFoundationApp(() async {
///   final config = AppConfiguration.fromCompileTime();
///   return MyApp(config: config);
/// });
/// ```
Future<void> runFoundationApp(
  FutureOr<Widget> Function() appBuilder, {
  CrashReporter? crashReporter,
  FoundationStrings strings = FoundationStrings.english,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final reporter = crashReporter ?? const _DebugConsoleCrashReporter();
  installFoundationErrorHandlers(reporter);
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const _ReleaseErrorPlaceholder();
  }
  Widget app;
  try {
    app = await appBuilder();
  } on Object catch (error, stackTrace) {
    await reporter.recordError(
      error,
      stackTrace,
      fatal: true,
      source: 'app_builder',
    );
    app = _StartupFailureApp(strings: strings);
  }
  runApp(app);
}

/// Routes framework and platform errors to [reporter] and returns a function
/// that restores the previous handlers (useful in tests).
VoidCallback installFoundationErrorHandlers(CrashReporter reporter) {
  final previousFlutterHandler = FlutterError.onError;
  final dispatcher = PlatformDispatcher.instance;
  final previousPlatformHandler = dispatcher.onError;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      reporter.recordError(
        details.exception,
        details.stack,
        fatal: false,
        source: details.library ?? 'flutter',
      ),
    );
  };
  dispatcher.onError = (error, stackTrace) {
    unawaited(
      reporter.recordError(error, stackTrace, fatal: true, source: 'platform'),
    );
    return true;
  };
  return () {
    FlutterError.onError = previousFlutterHandler;
    dispatcher.onError = previousPlatformHandler;
  };
}

final class _DebugConsoleCrashReporter implements CrashReporter {
  const _DebugConsoleCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? source,
  }) async {
    // Only debug builds print; production apps should pass a CrashReporter.
    if (kDebugMode) {
      debugPrint('Uncaught ${fatal ? 'fatal ' : ''}error ($source): $error');
      if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    }
  }
}

final class _ReleaseErrorPlaceholder extends StatelessWidget {
  const _ReleaseErrorPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.strings});

  final FoundationStrings strings;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: FoundationStateView(
        state: FoundationViewState.error,
        title: strings.fatalErrorTitle,
        message: strings.fatalErrorMessage,
      ),
    ),
  );
}
