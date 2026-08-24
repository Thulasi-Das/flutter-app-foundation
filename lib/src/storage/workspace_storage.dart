import 'dart:async';
import 'dart:convert';

const String storageContractVersion = '1.0';

enum PrivacyMode { localOnly, directUserProvider, backendBrokered, managed }

enum DataLocation { device, userCloud, userInfrastructure, managedService }

enum StoreErrorCode {
  invalidConfiguration,
  authenticationFailed,
  permissionDenied,
  notFound,
  conflict,
  rateLimited,
  unavailable,
  unsupported,
  storeError,
}

final class StoreException implements Exception {
  const StoreException(this.code, {this.retryable = false});

  final StoreErrorCode code;
  final bool retryable;
}

extension StoreErrorCodeWireName on StoreErrorCode {
  String get wireName => switch (this) {
        StoreErrorCode.invalidConfiguration => 'invalid_configuration',
        StoreErrorCode.authenticationFailed => 'authentication_failed',
        StoreErrorCode.permissionDenied => 'permission_denied',
        StoreErrorCode.notFound => 'not_found',
        StoreErrorCode.conflict => 'conflict',
        StoreErrorCode.rateLimited => 'rate_limited',
        StoreErrorCode.unavailable => 'unavailable',
        StoreErrorCode.unsupported => 'unsupported',
        StoreErrorCode.storeError => 'store_error',
      };
}

final class StoreCapabilities {
  const StoreCapabilities({
    this.transactions = false,
    this.watch = false,
    this.pagination = true,
    this.attachments = false,
    this.offline = false,
    this.endToEndEncryption = false,
    this.multiDevice = false,
  });

  final bool transactions;
  final bool watch;
  final bool pagination;
  final bool attachments;
  final bool offline;
  final bool endToEndEncryption;
  final bool multiDevice;

  Map<String, Object?> toJson() => <String, Object?>{
        'transactions': transactions,
        'watch': watch,
        'pagination': pagination,
        'attachments': attachments,
        'offline': offline,
        'endToEndEncryption': endToEndEncryption,
        'multiDevice': multiDevice,
      };
}

final class StoreDescriptor {
  StoreDescriptor({
    required this.storeId,
    required this.workspaceId,
    required this.provider,
    required this.privacyMode,
    required this.dataLocation,
    this.displayName,
    this.configuration = const <String, Object?>{},
    this.secretReference,
    this.contractVersion = storageContractVersion,
  }) {
    if (storeId.isEmpty || workspaceId.isEmpty || provider.isEmpty) {
      throw ArgumentError('storeId, workspaceId, and provider are required.');
    }
    if (contractVersion != storageContractVersion) {
      throw ArgumentError('Unsupported storage contract $contractVersion.');
    }
    jsonEncode(configuration);
  }

  final String contractVersion;
  final String storeId;
  final String workspaceId;
  final String provider;
  final PrivacyMode privacyMode;
  final DataLocation dataLocation;
  final String? displayName;
  final Map<String, Object?> configuration;
  final String? secretReference;

  Map<String, Object?> toJson() => <String, Object?>{
        'contractVersion': contractVersion,
        'storeId': storeId,
        'workspaceId': workspaceId,
        'provider': provider,
        'privacyMode': privacyMode.wireName,
        'dataLocation': dataLocation.wireName,
        'displayName': displayName,
        'configuration': configuration,
        'secretReference': secretReference,
      };

  factory StoreDescriptor.fromJson(Map<String, Object?> json) =>
      StoreDescriptor(
        contractVersion: json['contractVersion']! as String,
        storeId: json['storeId']! as String,
        workspaceId: json['workspaceId']! as String,
        provider: json['provider']! as String,
        privacyMode: PrivacyMode.values.singleWhere(
          (value) => value.wireName == json['privacyMode'],
        ),
        dataLocation: DataLocation.values.singleWhere(
          (value) => value.wireName == json['dataLocation'],
        ),
        displayName: json['displayName'] as String?,
        configuration: Map<String, Object?>.from(
          json['configuration']! as Map,
        ),
        secretReference: json['secretReference'] as String?,
      );
}

extension on PrivacyMode {
  String get wireName => switch (this) {
        PrivacyMode.localOnly => 'local_only',
        PrivacyMode.directUserProvider => 'direct_user_provider',
        PrivacyMode.backendBrokered => 'backend_brokered',
        PrivacyMode.managed => 'managed',
      };
}

extension on DataLocation {
  String get wireName => switch (this) {
        DataLocation.device => 'device',
        DataLocation.userCloud => 'user_cloud',
        DataLocation.userInfrastructure => 'user_infrastructure',
        DataLocation.managedService => 'managed_service',
      };
}

final class WorkspaceRecord {
  WorkspaceRecord({
    required this.collection,
    required this.recordId,
    required this.values,
    required this.version,
    required this.updatedAt,
    this.deleted = false,
  }) {
    if (collection.isEmpty || recordId.isEmpty) {
      throw ArgumentError('collection and recordId are required.');
    }
    if (version < 0) throw ArgumentError('version cannot be negative.');
    jsonEncode(toJson());
  }

  final String collection;
  final String recordId;
  final Map<String, Object?> values;
  final int version;
  final DateTime updatedAt;
  final bool deleted;

  Map<String, Object?> toJson() => <String, Object?>{
        'collection': collection,
        'recordId': recordId,
        'values': values,
        'version': version,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deleted': deleted,
      };

  factory WorkspaceRecord.fromJson(Map<String, Object?> json) =>
      WorkspaceRecord(
        collection: json['collection']! as String,
        recordId: json['recordId']! as String,
        values: Map<String, Object?>.from(json['values']! as Map),
        version: json['version']! as int,
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        deleted: json['deleted'] as bool? ?? false,
      );
}

final class StoreQuery {
  StoreQuery({
    required this.collection,
    this.filters = const <String, Object?>{},
    this.cursor,
    this.limit = 100,
    this.includeDeleted = false,
  }) {
    if (collection.isEmpty) throw ArgumentError('collection is required.');
    if (limit < 1 || limit > 1000) {
      throw ArgumentError('limit must be between 1 and 1000.');
    }
  }

  final String collection;
  final Map<String, Object?> filters;
  final String? cursor;
  final int limit;
  final bool includeDeleted;
}

final class StorePage {
  const StorePage(this.records, {this.nextCursor});

  final List<WorkspaceRecord> records;
  final String? nextCursor;
}

abstract interface class WorkspaceStore {
  StoreDescriptor get descriptor;
  StoreCapabilities get capabilities;
  Future<bool> health();
  Future<WorkspaceRecord?> get(String collection, String recordId);
  Future<StorePage> list(StoreQuery query);
  Future<void> put(WorkspaceRecord record, {int? expectedVersion});
  Future<void> delete(
    String collection,
    String recordId, {
    int? expectedVersion,
  });
  Future<void> close();
}

abstract interface class StoreFactory {
  FutureOr<WorkspaceStore> create(
    StoreDescriptor descriptor,
    Map<String, String> secrets,
  );
}

typedef SecretLookup = FutureOr<Map<String, String>> Function(String reference);

final class StoreRegistry {
  final Map<String, StoreFactory> _factories = <String, StoreFactory>{};

  void register(String provider, StoreFactory factory) {
    final normalized = provider.trim().toLowerCase();
    if (normalized.isEmpty) throw ArgumentError('Provider cannot be empty.');
    if (_factories.containsKey(normalized)) {
      throw ArgumentError(
        'Storage provider $normalized is already registered.',
      );
    }
    _factories[normalized] = factory;
  }

  List<String> get providers => List<String>.unmodifiable(_factories.keys);

  Future<WorkspaceStore> create(
    StoreDescriptor descriptor, {
    SecretLookup? secretLookup,
    bool clientRuntime = true,
  }) async {
    validateStoreDescriptor(descriptor, clientRuntime: clientRuntime);
    final factory = _factories[descriptor.provider.trim().toLowerCase()];
    if (factory == null) throw const StoreException(StoreErrorCode.unsupported);
    var secrets = const <String, String>{};
    if (descriptor.secretReference case final reference?) {
      if (secretLookup == null) {
        throw const StoreException(StoreErrorCode.invalidConfiguration);
      }
      secrets = await secretLookup(reference);
    }
    return factory.create(descriptor, secrets);
  }
}

const Set<String> _localProviders = <String>{'local_file', 'local_sqlite'};
const Set<String> _sensitiveKeys = <String>{
  'password',
  'secret',
  'token',
  'api_key',
  'apikey',
  'access_token',
  'refresh_token',
};

bool _containsInlineSecret(Object? value, [String key = '']) {
  if (_sensitiveKeys.contains(key.toLowerCase())) return true;
  if (value is Map) {
    return value.entries.any(
      (entry) => _containsInlineSecret(entry.value, entry.key.toString()),
    );
  }
  if (value is Iterable) return value.any(_containsInlineSecret);
  return false;
}

void validateStoreDescriptor(
  StoreDescriptor descriptor, {
  bool clientRuntime = true,
}) {
  if (_containsInlineSecret(descriptor.configuration)) {
    throw ArgumentError(
      'Credentials must use secretReference, never inline configuration.',
    );
  }
  final provider = descriptor.provider.toLowerCase();
  switch (descriptor.privacyMode) {
    case PrivacyMode.localOnly:
      if (!_localProviders.contains(provider) ||
          descriptor.dataLocation != DataLocation.device) {
        throw ArgumentError(
          'localOnly stores require a local provider and device location.',
        );
      }
      if (descriptor.secretReference != null) {
        throw ArgumentError('localOnly stores cannot use remote credentials.');
      }
    case PrivacyMode.directUserProvider:
      if (_localProviders.contains(provider) ||
          (descriptor.dataLocation != DataLocation.userCloud &&
              descriptor.dataLocation != DataLocation.userInfrastructure)) {
        throw ArgumentError('Direct providers must be user owned.');
      }
    case PrivacyMode.backendBrokered:
      if (descriptor.dataLocation != DataLocation.userCloud &&
          descriptor.dataLocation != DataLocation.userInfrastructure) {
        throw ArgumentError('Brokered providers must target user-owned data.');
      }
    case PrivacyMode.managed:
      if (descriptor.dataLocation != DataLocation.managedService) {
        throw ArgumentError('Managed stores require managedService location.');
      }
  }
  if (clientRuntime &&
      provider == 'database' &&
      descriptor.privacyMode != PrivacyMode.backendBrokered) {
    throw ArgumentError(
      'Flutter clients must access external databases through '
      'a backend broker.',
    );
  }
}

final class ProviderOption {
  const ProviderOption(
    this.provider, {
    this.enabled = true,
    this.recommended = false,
    this.reason,
  });

  final String provider;
  final bool enabled;
  final bool recommended;
  final String? reason;
}

List<ProviderOption> visibleProviderOptions(List<ProviderOption> options) {
  final enabled = options.where((option) => option.enabled).toList();
  if (enabled.where((option) => option.recommended).length > 1) {
    throw ArgumentError('At most one provider may be recommended.');
  }
  return List<ProviderOption>.unmodifiable(enabled);
}

final class InMemoryWorkspaceStore implements WorkspaceStore {
  InMemoryWorkspaceStore(this.descriptor);

  @override
  final StoreDescriptor descriptor;
  @override
  final StoreCapabilities capabilities =
      const StoreCapabilities(transactions: true, offline: true);
  final Map<String, Map<String, WorkspaceRecord>> _records =
      <String, Map<String, WorkspaceRecord>>{};

  @override
  Future<bool> health() async => true;

  @override
  Future<WorkspaceRecord?> get(String collection, String recordId) async =>
      _records[collection]?[recordId];

  @override
  Future<StorePage> list(StoreQuery query) async {
    final records =
        (_records[query.collection]?.values ?? const <WorkspaceRecord>[])
        .where(
          (record) =>
              (query.includeDeleted || !record.deleted) &&
              query.filters.entries.every(
                (filter) => record.values[filter.key] == filter.value,
              ),
        )
        .toList()
      ..sort((left, right) => left.recordId.compareTo(right.recordId));
    final offset = int.tryParse(query.cursor ?? '0');
    if (offset == null || offset < 0) {
      throw const StoreException(StoreErrorCode.invalidConfiguration);
    }
    final start = offset > records.length ? records.length : offset;
    final requestedEnd = start + query.limit;
    final end = requestedEnd > records.length ? records.length : requestedEnd;
    return StorePage(
      records.sublist(start, end),
      nextCursor: end < records.length ? '$end' : null,
    );
  }

  @override
  Future<void> put(WorkspaceRecord record, {int? expectedVersion}) async {
    final current = _records[record.collection]?[record.recordId];
    if (expectedVersion != null && expectedVersion != current?.version) {
      throw const StoreException(StoreErrorCode.conflict);
    }
    (_records[record.collection] ??= <String, WorkspaceRecord>{})[
      record.recordId
    ] = record;
  }

  @override
  Future<void> delete(
    String collection,
    String recordId, {
    int? expectedVersion,
  }) async {
    final current = _records[collection]?[recordId];
    if (current == null) {
      if (expectedVersion != null) {
        throw const StoreException(StoreErrorCode.conflict);
      }
      return;
    }
    if (expectedVersion != null && expectedVersion != current.version) {
      throw const StoreException(StoreErrorCode.conflict);
    }
    _records[collection]?.remove(recordId);
  }

  @override
  Future<void> close() async {}
}
