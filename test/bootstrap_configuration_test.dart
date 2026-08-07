import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production configuration rejects non-TLS API', () {
    expect(
      () => AppConfiguration(
        environment: AppEnvironment.production,
        apiBaseUri: Uri.parse('http://api.example.test'),
        release: '1.0.0',
        buildNumber: '1',
        appId: 'example',
      ),
      throwsA(isA<ConfigurationException>()),
    );
  });

  test('bootstrap executes required steps in order', () async {
    final order = <String>[];
    final coordinator = BootstrapCoordinator(<StartupStep>[
      StartupStep(id: 'one', run: () async => order.add('one')),
      StartupStep(id: 'two', run: () async => order.add('two')),
    ]);

    final result = await coordinator.start();

    expect(order, <String>['one', 'two']);
    expect(result.phase, BootstrapPhase.ready);
    await coordinator.dispose();
  });

  test('bootstrap stops at a required failure', () async {
    var laterStepRan = false;
    final coordinator = BootstrapCoordinator(<StartupStep>[
      StartupStep(id: 'database', run: () async => throw StateError('failed')),
      StartupStep(id: 'session', run: () async => laterStepRan = true),
    ]);

    final result = await coordinator.start();

    expect(result.phase, BootstrapPhase.failed);
    expect(result.failure?.stepId, 'database');
    expect(laterStepRan, isFalse);
    await coordinator.dispose();
  });
}
