import 'dart:convert';
import 'dart:io';

import 'workspace_storage.dart';

final class LocalFileWorkspaceStore implements WorkspaceStore {
  LocalFileWorkspaceStore(this.descriptor, Directory root)
      : _root = Directory('${root.path}/${_safeName(descriptor.workspaceId)}') {
    _root.createSync(recursive: true);
  }

  @override
  final StoreDescriptor descriptor;
  final Directory _root;

  @override
  final StoreCapabilities capabilities =
      const StoreCapabilities(offline: true);

  static String _safeName(String value) => base64Url
      .encode(utf8.encode(value))
      .replaceAll('=', '');

  File _file(String collection, String recordId) {
    final directory = Directory('${_root.path}/${_safeName(collection)}')
      ..createSync(recursive: true);
    return File('${directory.path}/${_safeName(recordId)}.json');
  }

  @override
  Future<bool> health() async => _root.exists();

  @override
  Future<WorkspaceRecord?> get(String collection, String recordId) async {
    final file = _file(collection, recordId);
    if (!await file.exists()) return null;
    final value = WorkspaceRecord.fromJson(
      Map<String, Object?>.from(jsonDecode(await file.readAsString()) as Map),
    );
    if (value.collection != collection || value.recordId != recordId) {
      return null;
    }
    return value;
  }

  @override
  Future<StorePage> list(StoreQuery query) async {
    final directory = _file(query.collection, 'unused').parent;
    final records = <WorkspaceRecord>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final record = WorkspaceRecord.fromJson(
        Map<String, Object?>.from(
          jsonDecode(await entity.readAsString()) as Map,
        ),
      );
      final matches = (query.includeDeleted || !record.deleted) &&
          query.filters.entries.every(
            (filter) => record.values[filter.key] == filter.value,
          );
      if (matches) records.add(record);
    }
    records.sort((left, right) => left.recordId.compareTo(right.recordId));
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
    final current = await get(record.collection, record.recordId);
    if (expectedVersion != null && expectedVersion != current?.version) {
      throw const StoreException(StoreErrorCode.conflict);
    }
    final file = _file(record.collection, record.recordId);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(record.toJson()), flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete(
    String collection,
    String recordId, {
    int? expectedVersion,
  }) async {
    final current = await get(collection, recordId);
    if (current == null) {
      if (expectedVersion != null) {
        throw const StoreException(StoreErrorCode.conflict);
      }
      return;
    }
    if (expectedVersion != null && expectedVersion != current.version) {
      throw const StoreException(StoreErrorCode.conflict);
    }
    await _file(collection, recordId).delete();
  }

  @override
  Future<void> close() async {}
}

final class LocalFileStoreFactory implements StoreFactory {
  const LocalFileStoreFactory();

  @override
  WorkspaceStore create(
    StoreDescriptor descriptor,
    Map<String, String> secrets,
  ) {
    final rootPath = descriptor.configuration['rootPath'];
    if (rootPath is! String || rootPath.isEmpty) {
      throw const StoreException(StoreErrorCode.invalidConfiguration);
    }
    return LocalFileWorkspaceStore(descriptor, Directory(rootPath));
  }
}
