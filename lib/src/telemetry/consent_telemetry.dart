import 'dart:async';
import 'dart:convert';

import '../testing/primitives.dart';

const String telemetryContractVersion = '1.0';

enum TelemetryPurpose {
  reliability,
  productAnalytics,
  productImprovement,
  personalization,
  commercialInsights,
}

enum TelemetryDataClass {
  operationalMetadata,
  deviceMetadata,
  usageAggregate,
  interaction,
  errorDiagnostic,
  accountContext,
  commercialProfile,
}

enum ConsentState { granted, denied, withdrawn }

enum ConsentSource { onboarding, privacySettings, api }

enum AttributeKind { string, integer, number, boolean }

enum CollectionOutcome {
  accepted,
  droppedDisabled,
  droppedNoConsent,
  droppedPrivacySignal,
  droppedInvalidEvent,
  sinkFailed,
}

enum ComplianceProfile {
  globalStrict,
  euEea,
  unitedKingdom,
  usCalifornia,
  india,
  brazil,
  canada,
  australia,
}

extension TelemetryPurposeWireName on TelemetryPurpose {
  String get wireName => switch (this) {
    TelemetryPurpose.reliability => 'reliability',
    TelemetryPurpose.productAnalytics => 'product_analytics',
    TelemetryPurpose.productImprovement => 'product_improvement',
    TelemetryPurpose.personalization => 'personalization',
    TelemetryPurpose.commercialInsights => 'commercial_insights',
  };
}

extension TelemetryDataClassWireName on TelemetryDataClass {
  String get wireName => switch (this) {
    TelemetryDataClass.operationalMetadata => 'operational_metadata',
    TelemetryDataClass.deviceMetadata => 'device_metadata',
    TelemetryDataClass.usageAggregate => 'usage_aggregate',
    TelemetryDataClass.interaction => 'interaction',
    TelemetryDataClass.errorDiagnostic => 'error_diagnostic',
    TelemetryDataClass.accountContext => 'account_context',
    TelemetryDataClass.commercialProfile => 'commercial_profile',
  };
}

extension ConsentStateWireName on ConsentState {
  String get wireName => name;
}

extension ConsentSourceWireName on ConsentSource {
  String get wireName => switch (this) {
    ConsentSource.onboarding => 'onboarding',
    ConsentSource.privacySettings => 'privacy_settings',
    ConsentSource.api => 'api',
  };
}

extension ComplianceProfileWireName on ComplianceProfile {
  String get wireName => switch (this) {
    ComplianceProfile.globalStrict => 'global_strict',
    ComplianceProfile.euEea => 'eu_eea',
    ComplianceProfile.unitedKingdom => 'united_kingdom',
    ComplianceProfile.usCalifornia => 'us_california',
    ComplianceProfile.india => 'india',
    ComplianceProfile.brazil => 'brazil',
    ComplianceProfile.canada => 'canada',
    ComplianceProfile.australia => 'australia',
  };
}

final class AttributeRule {
  const AttributeRule(
    this.kind, {
    this.maxLength = 128,
    this.allowedValues = const <Object?>{},
  });

  final AttributeKind kind;
  final int maxLength;
  final Set<Object?> allowedValues;

  bool accepts(Object? value) {
    if (maxLength < 1 || value == null) return false;
    final accepted = switch (kind) {
      AttributeKind.string => value is String,
      AttributeKind.integer => value is int,
      AttributeKind.number => value is num,
      AttributeKind.boolean => value is bool,
    };
    if (!accepted) return false;
    if (value is String && value.length > maxLength) return false;
    return allowedValues.isEmpty || allowedValues.contains(value);
  }
}

final class TelemetryEventSpec {
  TelemetryEventSpec({
    required this.name,
    required this.purpose,
    required this.dataClasses,
    required this.attributes,
    required this.retentionDays,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_.-]{2,63}$').hasMatch(name)) {
      throw ArgumentError('Event names must be stable machine-readable codes.');
    }
    if (retentionDays < 1 || retentionDays > 3650) {
      throw ArgumentError('retentionDays must be between 1 and 3650.');
    }
    if (dataClasses.isEmpty) {
      throw ArgumentError('At least one telemetry data class is required.');
    }
  }

  final String name;
  final TelemetryPurpose purpose;
  final Set<TelemetryDataClass> dataClasses;
  final Map<String, AttributeRule> attributes;
  final int retentionDays;
}

final class ConsentTelemetryEvent {
  ConsentTelemetryEvent({
    required this.eventId,
    required this.eventName,
    required this.purpose,
    required this.dataClasses,
    required this.attributes,
    required this.occurredAt,
    required this.subjectKey,
    this.sessionId,
    this.contractVersion = telemetryContractVersion,
  }) {
    if (eventId.isEmpty || eventName.isEmpty || subjectKey.isEmpty) {
      throw ArgumentError(
        'Event identity, name, and pseudonymous subject key are required.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(subjectKey)) {
      throw ArgumentError('subjectKey must be a scoped pseudonym.');
    }
    if (contractVersion != telemetryContractVersion) {
      throw ArgumentError('Unsupported telemetry contract $contractVersion.');
    }
    if (attributes.values.any(
      (value) =>
          value != null && value is! String && value is! num && value is! bool,
    )) {
      throw ArgumentError('Telemetry attributes must be JSON scalars.');
    }
    jsonEncode(toJson());
  }

  final String contractVersion;
  final String eventId;
  final String eventName;
  final TelemetryPurpose purpose;
  final Set<TelemetryDataClass> dataClasses;
  final Map<String, Object?> attributes;
  final DateTime occurredAt;
  final String subjectKey;
  final String? sessionId;

  Map<String, Object?> toJson() => <String, Object?>{
    'contractVersion': contractVersion,
    'eventId': eventId,
    'eventName': eventName,
    'purpose': purpose.wireName,
    'dataClasses': dataClasses.map((value) => value.wireName).toList()..sort(),
    'attributes': attributes,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'subjectKey': subjectKey,
    'sessionId': sessionId,
  };

  factory ConsentTelemetryEvent.fromJson(Map<String, Object?> json) =>
      ConsentTelemetryEvent(
        contractVersion: json['contractVersion']! as String,
        eventId: json['eventId']! as String,
        eventName: json['eventName']! as String,
        purpose: TelemetryPurpose.values.singleWhere(
          (value) => value.wireName == json['purpose'],
        ),
        dataClasses: List<Object?>.from(json['dataClasses']! as List)
            .map(
              (item) => TelemetryDataClass.values.singleWhere(
                (value) => value.wireName == item,
              ),
            )
            .toSet(),
        attributes: Map<String, Object?>.from(json['attributes']! as Map),
        occurredAt: DateTime.parse(json['occurredAt']! as String),
        subjectKey: json['subjectKey']! as String,
        sessionId: json['sessionId'] as String?,
      );
}

final class ConsentReceipt {
  ConsentReceipt({
    required this.subjectKey,
    required this.purpose,
    required this.state,
    required this.policyVersion,
    required this.noticeVersion,
    required this.decidedAt,
    required this.source,
    this.expiresAt,
  }) {
    if (subjectKey.isEmpty || policyVersion.isEmpty || noticeVersion.isEmpty) {
      throw ArgumentError(
        'Consent subject, policy version, and notice version are required.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(subjectKey)) {
      throw ArgumentError('subjectKey must be a scoped pseudonym.');
    }
    if (expiresAt != null && !expiresAt!.isAfter(decidedAt)) {
      throw ArgumentError('expiresAt must be later than decidedAt.');
    }
  }

  final String subjectKey;
  final TelemetryPurpose purpose;
  final ConsentState state;
  final String policyVersion;
  final String noticeVersion;
  final DateTime decidedAt;
  final ConsentSource source;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'subjectKey': subjectKey,
    'purpose': purpose.wireName,
    'state': state.wireName,
    'policyVersion': policyVersion,
    'noticeVersion': noticeVersion,
    'decidedAt': decidedAt.toUtc().toIso8601String(),
    'source': source.wireName,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };

  factory ConsentReceipt.fromJson(Map<String, Object?> json) => ConsentReceipt(
    subjectKey: json['subjectKey']! as String,
    purpose: TelemetryPurpose.values.singleWhere(
      (value) => value.wireName == json['purpose'],
    ),
    state: ConsentState.values.singleWhere(
      (value) => value.wireName == json['state'],
    ),
    policyVersion: json['policyVersion']! as String,
    noticeVersion: json['noticeVersion']! as String,
    decidedAt: DateTime.parse(json['decidedAt']! as String),
    source: ConsentSource.values.singleWhere(
      (value) => value.wireName == json['source'],
    ),
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt']! as String),
  );
}

final class PrivacySignals {
  const PrivacySignals({
    this.globalPrivacyControl = false,
    this.doNotSellOrShare = false,
  });

  final bool globalPrivacyControl;
  final bool doNotSellOrShare;
}

abstract interface class ConsentStore {
  FutureOr<ConsentReceipt?> current(
    String subjectKey,
    TelemetryPurpose purpose,
  );
  FutureOr<void> save(ConsentReceipt receipt);
}

abstract interface class ConsentTelemetrySink {
  FutureOr<void> emit(
    ConsentTelemetryEvent event, {
    required int retentionDays,
  });
  FutureOr<void> purge(String subjectKey, Set<TelemetryPurpose> purposes);
}

const Map<TelemetryPurpose, int> defaultTelemetryRetentionDays =
    <TelemetryPurpose, int>{
      TelemetryPurpose.reliability: 30,
      TelemetryPurpose.productAnalytics: 90,
      TelemetryPurpose.productImprovement: 90,
      TelemetryPurpose.personalization: 30,
      TelemetryPurpose.commercialInsights: 30,
    };

const Set<String> _euEeaCodes = <String>{
  'AT',
  'BE',
  'BG',
  'HR',
  'CY',
  'CZ',
  'DK',
  'EE',
  'FI',
  'FR',
  'DE',
  'GR',
  'HU',
  'IE',
  'IT',
  'LV',
  'LT',
  'LU',
  'MT',
  'NL',
  'PL',
  'PT',
  'RO',
  'SK',
  'SI',
  'ES',
  'SE',
  'IS',
  'LI',
  'NO',
};

final class ConsentTelemetryPolicy {
  const ConsentTelemetryPolicy({
    required this.profile,
    required this.policyVersion,
    required this.noticeVersion,
    required this.enabledPurposes,
    required this.consentRequired,
    required this.maximumRetentionDays,
    this.separateCommercialConsent = true,
    this.honorGlobalPrivacyControl = false,
    this.commercialInsightsDefaultEnabled = false,
  });

  final ComplianceProfile profile;
  final String policyVersion;
  final String noticeVersion;
  final Set<TelemetryPurpose> enabledPurposes;
  final Set<TelemetryPurpose> consentRequired;
  final Map<TelemetryPurpose, int> maximumRetentionDays;
  final bool separateCommercialConsent;
  final bool honorGlobalPrivacyControl;
  final bool commercialInsightsDefaultEnabled;

  factory ConsentTelemetryPolicy.forProfile({
    ComplianceProfile profile = ComplianceProfile.globalStrict,
    required String policyVersion,
    required String noticeVersion,
    bool enableCommercialInsights = false,
  }) {
    if (policyVersion.isEmpty || noticeVersion.isEmpty) {
      throw ArgumentError('Policy and notice versions are required.');
    }
    final enabled = <TelemetryPurpose>{...TelemetryPurpose.values};
    if (!enableCommercialInsights) {
      enabled.remove(TelemetryPurpose.commercialInsights);
    }
    return ConsentTelemetryPolicy(
      profile: profile,
      policyVersion: policyVersion,
      noticeVersion: noticeVersion,
      enabledPurposes: Set<TelemetryPurpose>.unmodifiable(enabled),
      consentRequired: Set<TelemetryPurpose>.unmodifiable(
        TelemetryPurpose.values,
      ),
      maximumRetentionDays: defaultTelemetryRetentionDays,
      honorGlobalPrivacyControl: profile == ComplianceProfile.usCalifornia,
    );
  }

  factory ConsentTelemetryPolicy.forCountry(
    String countryCode, {
    required String policyVersion,
    required String noticeVersion,
    bool enableCommercialInsights = false,
  }) {
    final code = countryCode.trim().toUpperCase();
    final profile = _euEeaCodes.contains(code)
        ? ComplianceProfile.euEea
        : switch (code) {
            'GB' || 'UK' => ComplianceProfile.unitedKingdom,
            'US-CA' => ComplianceProfile.usCalifornia,
            'IN' => ComplianceProfile.india,
            'BR' => ComplianceProfile.brazil,
            'CA' => ComplianceProfile.canada,
            'AU' => ComplianceProfile.australia,
            _ => ComplianceProfile.globalStrict,
          };
    return ConsentTelemetryPolicy.forProfile(
      profile: profile,
      policyVersion: policyVersion,
      noticeVersion: noticeVersion,
      enableCommercialInsights: enableCommercialInsights,
    );
  }
}

const List<String> _forbiddenAttributeFragments = <String>[
  'password',
  'secret',
  'token',
  'authorization',
  'cookie',
  'email',
  'phone',
  'address',
  'name',
  'message',
  'stack',
  'traceback',
  'content',
  'payload',
  'title',
  'note',
  'url',
  'query',
  'latitude',
  'longitude',
  'location',
  'contact',
  'credential',
  'ip_address',
  'user_id',
];

final class TelemetryEventRegistry {
  final Map<String, TelemetryEventSpec> _specs = <String, TelemetryEventSpec>{};

  void register(TelemetryEventSpec spec) {
    if (_specs.containsKey(spec.name)) {
      throw ArgumentError(
        'Telemetry event ${spec.name} is already registered.',
      );
    }
    for (final attribute in spec.attributes.keys) {
      final normalized = attribute.toLowerCase();
      if (_forbiddenAttributeFragments.any(normalized.contains)) {
        throw ArgumentError('Telemetry attribute $attribute is forbidden.');
      }
    }
    _specs[spec.name] = spec;
  }

  TelemetryEventSpec? get(String name) => _specs[name];
}

final class ConsentGatedTelemetry {
  const ConsentGatedTelemetry({
    required ConsentTelemetryPolicy policy,
    required TelemetryEventRegistry registry,
    required ConsentStore consents,
    required ConsentTelemetrySink sink,
    required Clock clock,
  }) : _policy = policy,
       _registry = registry,
       _consents = consents,
       _sink = sink,
       _clock = clock;

  final ConsentTelemetryPolicy _policy;
  final TelemetryEventRegistry _registry;
  final ConsentStore _consents;
  final ConsentTelemetrySink _sink;
  final Clock _clock;

  Future<CollectionOutcome> record(
    ConsentTelemetryEvent event, {
    PrivacySignals privacySignals = const PrivacySignals(),
  }) async {
    final spec = _registry.get(event.eventName);
    if (spec == null || !_validEvent(event, spec)) {
      return CollectionOutcome.droppedInvalidEvent;
    }
    if (!_policy.enabledPurposes.contains(event.purpose)) {
      return CollectionOutcome.droppedDisabled;
    }
    if (_blockedBySignal(event.purpose, privacySignals)) {
      return CollectionOutcome.droppedPrivacySignal;
    }
    if (_policy.consentRequired.contains(event.purpose)) {
      final receipt = await _consents.current(event.subjectKey, event.purpose);
      if (!_validConsent(receipt)) {
        return CollectionOutcome.droppedNoConsent;
      }
    }
    final retention =
        spec.retentionDays < _policy.maximumRetentionDays[event.purpose]!
        ? spec.retentionDays
        : _policy.maximumRetentionDays[event.purpose]!;
    try {
      await _sink.emit(event, retentionDays: retention);
    } on Object {
      return CollectionOutcome.sinkFailed;
    }
    return CollectionOutcome.accepted;
  }

  Future<void> withdraw(ConsentReceipt receipt) async {
    if (receipt.state != ConsentState.withdrawn) {
      throw ArgumentError('Withdrawal requires a withdrawn consent receipt.');
    }
    await _consents.save(receipt);
    await _sink.purge(receipt.subjectKey, <TelemetryPurpose>{receipt.purpose});
  }

  bool _validConsent(ConsentReceipt? receipt) {
    if (receipt == null || receipt.state != ConsentState.granted) return false;
    if (receipt.policyVersion != _policy.policyVersion ||
        receipt.noticeVersion != _policy.noticeVersion) {
      return false;
    }
    return receipt.expiresAt == null ||
        receipt.expiresAt!.isAfter(_clock.nowUtc());
  }

  bool _blockedBySignal(TelemetryPurpose purpose, PrivacySignals signals) {
    if (purpose != TelemetryPurpose.commercialInsights) return false;
    return signals.doNotSellOrShare ||
        (_policy.honorGlobalPrivacyControl && signals.globalPrivacyControl);
  }

  bool _validEvent(ConsentTelemetryEvent event, TelemetryEventSpec spec) {
    if (event.purpose != spec.purpose ||
        !_sameSet(event.dataClasses, spec.dataClasses) ||
        !_sameSet(
          event.attributes.keys.toSet(),
          spec.attributes.keys.toSet(),
        )) {
      return false;
    }
    return event.attributes.entries.every(
      (entry) => spec.attributes[entry.key]!.accepts(entry.value),
    );
  }
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

final class InMemoryConsentStore implements ConsentStore {
  final Map<String, ConsentReceipt> _receipts = <String, ConsentReceipt>{};

  String _key(String subject, TelemetryPurpose purpose) =>
      '$subject:${purpose.wireName}';

  @override
  ConsentReceipt? current(String subjectKey, TelemetryPurpose purpose) =>
      _receipts[_key(subjectKey, purpose)];

  @override
  void save(ConsentReceipt receipt) {
    _receipts[_key(receipt.subjectKey, receipt.purpose)] = receipt;
  }
}

final class InMemoryConsentTelemetrySink implements ConsentTelemetrySink {
  final List<(ConsentTelemetryEvent, int)> events =
      <(ConsentTelemetryEvent, int)>[];
  final List<(String, Set<TelemetryPurpose>)> purges =
      <(String, Set<TelemetryPurpose>)>[];

  @override
  void emit(ConsentTelemetryEvent event, {required int retentionDays}) {
    events.add((event, retentionDays));
  }

  @override
  void purge(String subjectKey, Set<TelemetryPurpose> purposes) {
    events.removeWhere(
      (item) =>
          item.$1.subjectKey == subjectKey &&
          purposes.contains(item.$1.purpose),
    );
    purges.add((subjectKey, Set<TelemetryPurpose>.unmodifiable(purposes)));
  }
}
