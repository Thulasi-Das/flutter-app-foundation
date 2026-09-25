import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

import '../features/todos/todo_repository.dart';

/// The composition root: every dependency is constructed here, once, and
/// handed to widgets through `FoundationApp(services: ...)`.
///
/// Swap adapters here (secure storage, file preferences, a crash vendor)
/// without touching feature code.
final class AppServices {
  AppServices._({
    required this.preferences,
    required this.theme,
    required this.todos,
    required this.bootstrap,
  });

  factory AppServices.create() {
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    // Production apps: wrap shared_preferences or use FileKeyValueStore from
    // foundation_local_file_storage.dart with a path_provider directory.
    final preferences = InMemoryKeyValueStore();
    final theme = ThemeController(store: preferences);
    final TodoRepository todos = apiBaseUrl.isEmpty
        ? DemoTodoRepository()
        : HttpTodoRepository(
            NetworkClient(
              transport: HttpNetworkTransport(),
              ids: UuidV4Generator(),
              baseUri: Uri.parse(apiBaseUrl),
              appVersion: const String.fromEnvironment(
                'APP_RELEASE',
                defaultValue: 'dev',
              ),
            ),
          );
    final bootstrap = BootstrapCoordinator(
      <StartupStep>[
        StartupStep(id: 'preferences', run: theme.load, required: false),
      ],
      onStepFailed: (failure, {required fatal}) => crashReporter.recordError(
        failure.error,
        failure.stackTrace,
        fatal: fatal,
        source: 'bootstrap.${failure.stepId}',
      ),
    );
    return AppServices._(
      preferences: preferences,
      theme: theme,
      todos: todos,
      bootstrap: bootstrap,
    );
  }

  /// Replace with a vendor adapter (Sentry, Crashlytics, ...) in production.
  static const CrashReporter crashReporter = LoggingCrashReporter(
    StructuredLogger(sink: DebugLogSink(), clock: SystemClock()),
  );

  final KeyValueStore preferences;
  final ThemeController theme;
  final TodoRepository todos;
  final BootstrapCoordinator bootstrap;
}
