final class FeatureFlag<T extends Object> {
  const FeatureFlag({required this.key, required this.safeDefault});
  final String key;
  final T safeDefault;
}

abstract interface class FeatureFlagSource {
  Future<Object?> value(String key);
}

final class FeatureFlagResolver {
  FeatureFlagResolver({
    required FeatureFlagSource source,
    this.debugOverrides = const <String, Object>{},
    this.allowDebugOverrides = false,
  }) : _source = source;

  final FeatureFlagSource _source;
  final Map<String, Object> debugOverrides;
  final bool allowDebugOverrides;

  Future<T> resolve<T extends Object>(FeatureFlag<T> flag) async {
    final value = allowDebugOverrides && debugOverrides.containsKey(flag.key)
        ? debugOverrides[flag.key]
        : await _source.value(flag.key);
    return value is T ? value : flag.safeDefault;
  }
}

final class InMemoryFeatureFlagSource implements FeatureFlagSource {
  const InMemoryFeatureFlagSource([this.values = const <String, Object>{}]);
  final Map<String, Object> values;
  @override
  Future<Object?> value(String key) async => values[key];
}
