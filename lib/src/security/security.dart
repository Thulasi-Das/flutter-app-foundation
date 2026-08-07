enum DeviceRiskSignal { rooted, jailbroken, debuggerAttached, insecureStorage }
enum DataClassification { public, operational, sensitivePersonal, restricted }

abstract interface class DeviceRiskProvider {
  Future<Set<DeviceRiskSignal>> signals();
}

abstract interface class PrivacyScreenController {
  Future<void> protectAppSwitcher(bool enabled);
}

abstract interface class ExpiringClipboard {
  Future<void> copy(String value, {required Duration expiresAfter});
  Future<void> clear();
}

abstract interface class LocalDataLifecycle {
  Future<void> exportUserData();
  Future<void> deleteUserData();
}

abstract interface class ExternalResourcePolicy {
  bool allowsWebUri(Uri uri);
  bool allowsImportedMimeType(String mimeType);
}

final class AllowlistExternalResourcePolicy implements ExternalResourcePolicy {
  AllowlistExternalResourcePolicy({
    required Set<String> webHosts,
    required Set<String> importedMimeTypes,
  })  : _webHosts = Set<String>.unmodifiable(webHosts),
        _mimeTypes = Set<String>.unmodifiable(importedMimeTypes);

  final Set<String> _webHosts;
  final Set<String> _mimeTypes;

  @override
  bool allowsWebUri(Uri uri) =>
      uri.scheme == 'https' && _webHosts.contains(uri.host.toLowerCase());

  @override
  bool allowsImportedMimeType(String mimeType) => _mimeTypes.contains(mimeType);
}
