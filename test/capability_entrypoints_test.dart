import 'package:flutter_app_foundation/foundation_app.dart' as app;
import 'package:flutter_app_foundation/foundation_auth.dart' as auth;
import 'package:flutter_app_foundation/foundation_contracts.dart' as contracts;
import 'package:flutter_app_foundation/foundation_data.dart' as data;
import 'package:flutter_app_foundation/foundation_network.dart' as network;
import 'package:flutter_app_foundation/foundation_notifications.dart'
    as notifications;
import 'package:flutter_app_foundation/foundation_observability.dart'
    as observability;
import 'package:flutter_app_foundation/foundation_preset_connected.dart'
    as connected;
import 'package:flutter_app_foundation/foundation_preset_minimal.dart'
    as minimal;
import 'package:flutter_app_foundation/foundation_preset_offline.dart'
    as offline;
import 'package:flutter_app_foundation/foundation_security.dart' as security;
import 'package:flutter_app_foundation/foundation_sync.dart' as sync;
import 'package:flutter_app_foundation/foundation_telemetry.dart' as telemetry;
import 'package:flutter_app_foundation/foundation_testing.dart' as testing;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capability libraries expose independent public APIs', () {
    expect(app.AppEnvironment.test.name, 'test');
    expect(auth.AuthStatus.signedOut.name, 'signedOut');
    expect(data.InMemoryLocalDatabase, isNotNull);
    expect(network.HttpMethod.get.name, 'get');
    expect(notifications.NotificationPermission.granted.name, 'granted');
    expect(observability.LogLevel.info.name, 'info');
    expect(security.DataClassification.restricted.name, 'restricted');
    expect(sync.MutationOperation.create.name, 'create');
    expect(telemetry.TelemetryPurpose.reliability.name, 'reliability');
    expect(contracts.FakeClock(DateTime.utc(2026)).nowUtc().year, 2026);
    expect(testing.SequentialIdGenerator().next(), 'test-1');
  });

  test('curated presets expose their intended compositions', () {
    expect(minimal.AppEnvironment.production.name, 'production');
    expect(connected.AuthStatus.authenticated.name, 'authenticated');
    expect(
      connected.TelemetryPurpose.productAnalytics.name,
      'productAnalytics',
    );
    expect(offline.SyncPhase.offline.name, 'offline');
    expect(offline.InMemoryLocalDatabase, isNotNull);
    expect(offline.TelemetryPurpose.reliability.name, 'reliability');
  });
}
