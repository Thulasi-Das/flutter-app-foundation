import 'dart:io';

import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_app_foundation/foundation_local_file_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed helpers round-trip through the in-memory store', () async {
    final store = InMemoryKeyValueStore();
    await store.writeBool('onboarded', value: true);
    await store.writeInt('launches', 3);
    await store.writeJson('filters', <String, Object?>{'done': false});
    await store.write('broken', '{');

    expect(await store.readBool('onboarded'), isTrue);
    expect(await store.readInt('launches'), 3);
    expect(await store.readJson('filters'), <String, Object?>{'done': false});
    expect(await store.readJson('broken'), isNull);
    await store.delete('launches');
    expect((await store.readAll()).containsKey('launches'), isFalse);
  });

  group('FileKeyValueStore', () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync('prefs'));
    tearDown(() => directory.deleteSync(recursive: true));

    test(
      'persists across instances and serializes concurrent writes',
      () async {
        final file = File('${directory.path}/nested/prefs.json');
        final store = FileKeyValueStore(file);
        await Future.wait(<Future<void>>[
          for (var i = 0; i < 20; i++) store.write('key$i', 'value$i'),
        ]);
        await store.delete('key0');

        final reopened = FileKeyValueStore(file);
        final values = await reopened.readAll();
        expect(values, hasLength(19));
        expect(values['key19'], 'value19');
        expect(File('${file.path}.tmp').existsSync(), isFalse);
      },
    );

    test('treats a corrupt file as empty and recovers on write', () async {
      final file = File('${directory.path}/prefs.json')
        ..writeAsStringSync('{not json');
      final store = FileKeyValueStore(file);
      expect(await store.read('theme'), isNull);
      await store.write('theme', 'dark');
      expect(await FileKeyValueStore(file).read('theme'), 'dark');
    });
  });
}
