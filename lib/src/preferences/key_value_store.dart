import 'dart:convert';

/// Small, non-sensitive app preferences (theme, onboarding flags, last tab).
///
/// Never store credentials here; use `SecureStorage`. Adapters may wrap
/// `shared_preferences`, a file, or a database table.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

extension TypedKeyValueStore on KeyValueStore {
  Future<bool?> readBool(String key) async => switch (await read(key)) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  Future<void> writeBool(String key, {required bool value}) =>
      write(key, value.toString());

  Future<int?> readInt(String key) async {
    final value = await read(key);
    return value == null ? null : int.tryParse(value);
  }

  Future<void> writeInt(String key, int value) => write(key, value.toString());

  /// Returns null when the key is missing or holds malformed JSON.
  Future<Object?> readJson(String key) async {
    final value = await read(key);
    if (value == null) return null;
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJson(String key, Object? value) =>
      write(key, jsonEncode(value));
}

final class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String> initial = const {}])
    : _values = Map<String, String>.of(initial);

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.unmodifiable(_values);
}
