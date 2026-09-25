import 'package:flutter_app_foundation/foundation_telemetry.dart';
import 'package:flutter_app_foundation/foundation_testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24);
  const subject = 'pseudonymous-installation-key';

  TelemetryEventSpec reliabilitySpec() => TelemetryEventSpec(
    name: 'app.exception',
    purpose: TelemetryPurpose.reliability,
    dataClasses: <TelemetryDataClass>{
      TelemetryDataClass.operationalMetadata,
      TelemetryDataClass.errorDiagnostic,
    },
    attributes: const <String, AttributeRule>{
      'exceptionType': AttributeRule(AttributeKind.string, maxLength: 64),
      'errorCode': AttributeRule(AttributeKind.string, maxLength: 64),
      'handled': AttributeRule(AttributeKind.boolean),
      'appVersion': AttributeRule(AttributeKind.string, maxLength: 32),
    },
    retentionDays: 60,
  );

  ConsentTelemetryEvent reliabilityEvent() => ConsentTelemetryEvent(
    eventId: 'event-1',
    eventName: 'app.exception',
    purpose: TelemetryPurpose.reliability,
    dataClasses: <TelemetryDataClass>{
      TelemetryDataClass.operationalMetadata,
      TelemetryDataClass.errorDiagnostic,
    },
    attributes: const <String, Object?>{
      'exceptionType': 'StateError',
      'errorCode': 'cache_unavailable',
      'handled': true,
      'appVersion': '1.2.3',
    },
    occurredAt: now,
    subjectKey: subject,
  );

  ConsentReceipt receipt(
    TelemetryPurpose purpose, [
    ConsentState state = ConsentState.granted,
  ]) => ConsentReceipt(
    subjectKey: subject,
    purpose: purpose,
    state: state,
    policyVersion: 'privacy-3',
    noticeVersion: 'notice-5',
    decidedAt: now,
    source: ConsentSource.privacySettings,
    expiresAt: now.add(const Duration(days: 180)),
  );

  test('wire values match Django telemetry contract', () {
    final event = reliabilityEvent().toJson();
    expect(event['contractVersion'], '1.0');
    expect(event['purpose'], 'reliability');
    expect(event['dataClasses'], <String>[
      'error_diagnostic',
      'operational_metadata',
    ]);
    expect(
      receipt(TelemetryPurpose.productAnalytics).toJson()['purpose'],
      'product_analytics',
    );
    final decodedEvent = ConsentTelemetryEvent.fromJson(
      reliabilityEvent().toJson(),
    );
    final decodedReceipt = ConsentReceipt.fromJson(
      receipt(TelemetryPurpose.reliability).toJson(),
    );
    expect(decodedEvent.eventName, reliabilityEvent().eventName);
    expect(decodedReceipt.noticeVersion, 'notice-5');
  });

  test('default denies then accepts exact purpose consent', () async {
    final registry = TelemetryEventRegistry()..register(reliabilitySpec());
    final consents = InMemoryConsentStore();
    final sink = InMemoryConsentTelemetrySink();
    final collector = ConsentGatedTelemetry(
      policy: ConsentTelemetryPolicy.forProfile(
        policyVersion: 'privacy-3',
        noticeVersion: 'notice-5',
      ),
      registry: registry,
      consents: consents,
      sink: sink,
      clock: FakeClock(now),
    );

    expect(
      await collector.record(reliabilityEvent()),
      CollectionOutcome.droppedNoConsent,
    );
    consents.save(receipt(TelemetryPurpose.productAnalytics));
    expect(
      await collector.record(reliabilityEvent()),
      CollectionOutcome.droppedNoConsent,
    );
    consents.save(receipt(TelemetryPurpose.reliability));
    expect(
      await collector.record(reliabilityEvent()),
      CollectionOutcome.accepted,
    );
    expect(sink.events.single.$2, 30);
  });

  test('registry rejects content and credential-shaped attributes', () {
    for (final attribute in <String>[
      'email',
      'stackTrace',
      'noteTitle',
      'accessToken',
    ]) {
      expect(
        () => TelemetryEventRegistry().register(
          TelemetryEventSpec(
            name: 'unsafe.event',
            purpose: TelemetryPurpose.productAnalytics,
            dataClasses: <TelemetryDataClass>{TelemetryDataClass.interaction},
            attributes: <String, AttributeRule>{
              attribute: const AttributeRule(AttributeKind.string),
            },
            retentionDays: 30,
          ),
        ),
        throwsArgumentError,
      );
    }
  });

  test('subject key rejects email and short raw identifier', () {
    for (final unsafeSubject in <String>['user@example.com', 'user-123']) {
      expect(
        () => ConsentTelemetryEvent(
          eventId: 'unsafe-subject',
          eventName: 'app.exception',
          purpose: TelemetryPurpose.reliability,
          dataClasses: reliabilityEvent().dataClasses,
          attributes: reliabilityEvent().attributes,
          occurredAt: now,
          subjectKey: unsafeSubject,
        ),
        throwsArgumentError,
      );
    }
  });

  test('withdrawal immediately blocks and requests purpose purge', () async {
    final registry = TelemetryEventRegistry()..register(reliabilitySpec());
    final consents = InMemoryConsentStore()
      ..save(receipt(TelemetryPurpose.reliability));
    final sink = InMemoryConsentTelemetrySink();
    final collector = ConsentGatedTelemetry(
      policy: ConsentTelemetryPolicy.forProfile(
        policyVersion: 'privacy-3',
        noticeVersion: 'notice-5',
      ),
      registry: registry,
      consents: consents,
      sink: sink,
      clock: FakeClock(now),
    );
    await collector.record(reliabilityEvent());
    await collector.withdraw(
      receipt(TelemetryPurpose.reliability, ConsentState.withdrawn),
    );

    expect(sink.events, isEmpty);
    expect(
      await collector.record(reliabilityEvent()),
      CollectionOutcome.droppedNoConsent,
    );
  });

  test(
    'California profile blocks commercial event on privacy signal',
    () async {
      final spec = TelemetryEventSpec(
        name: 'commercial.eligibility_evaluated',
        purpose: TelemetryPurpose.commercialInsights,
        dataClasses: <TelemetryDataClass>{
          TelemetryDataClass.accountContext,
          TelemetryDataClass.commercialProfile,
        },
        attributes: const <String, AttributeRule>{
          'featureKey': AttributeRule(AttributeKind.string),
          'tierBand': AttributeRule(AttributeKind.string),
          'eligible': AttributeRule(AttributeKind.boolean),
        },
        retentionDays: 30,
      );
      final registry = TelemetryEventRegistry()..register(spec);
      final consents = InMemoryConsentStore()
        ..save(receipt(TelemetryPurpose.commercialInsights));
      final collector = ConsentGatedTelemetry(
        policy: ConsentTelemetryPolicy.forCountry(
          'US-CA',
          policyVersion: 'privacy-3',
          noticeVersion: 'notice-5',
          enableCommercialInsights: true,
        ),
        registry: registry,
        consents: consents,
        sink: InMemoryConsentTelemetrySink(),
        clock: FakeClock(now),
      );
      final event = ConsentTelemetryEvent(
        eventId: 'event-commercial-1',
        eventName: spec.name,
        purpose: spec.purpose,
        dataClasses: spec.dataClasses,
        attributes: const <String, Object?>{
          'featureKey': 'advanced_reports',
          'tierBand': 'starter',
          'eligible': true,
        },
        occurredAt: now,
        subjectKey: subject,
      );
      expect(
        await collector.record(
          event,
          privacySignals: const PrivacySignals(globalPrivacyControl: true),
        ),
        CollectionOutcome.droppedPrivacySignal,
      );
    },
  );

  test('commercial insights are disabled by every default profile', () {
    for (final profile in ComplianceProfile.values) {
      final policy = ConsentTelemetryPolicy.forProfile(
        profile: profile,
        policyVersion: 'privacy-3',
        noticeVersion: 'notice-5',
      );
      expect(
        policy.enabledPurposes,
        isNot(contains(TelemetryPurpose.commercialInsights)),
      );
      expect(policy.commercialInsightsDefaultEnabled, false);
    }
  });
}
