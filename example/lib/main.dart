import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

import 'app/app.dart';
import 'app/services.dart';

/// Run with defaults (in-memory demo data):
///   flutter run
///
/// Or against a JSON API that serves `GET /todos` and `GET /todos/{id}`:
///   flutter run --dart-define=API_BASE_URL=https://jsonplaceholder.typicode.com
Future<void> main() => runFoundationApp(() async {
  final services = AppServices.create();
  return ExampleApp(services: services);
}, crashReporter: AppServices.crashReporter);
