enum AppEnvironment { development, staging, production, test }

final class ConfigurationException implements Exception {
  const ConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'ConfigurationException: $message';
}

final class AppConfiguration {
  AppConfiguration({
    required this.environment,
    required this.apiBaseUri,
    required this.release,
    required this.buildNumber,
    required this.appId,
    this.minimumSupportedVersion,
    this.telemetryEnabled = false,
    this.attributes = const <String, String>{},
  }) {
    if (!apiBaseUri.hasScheme || !apiBaseUri.hasAuthority) {
      throw const ConfigurationException('apiBaseUri must be absolute.');
    }
    if (environment == AppEnvironment.production &&
        apiBaseUri.scheme != 'https') {
      throw const ConfigurationException(
        'Production API endpoints must use HTTPS.',
      );
    }
    if (appId.trim().isEmpty || release.trim().isEmpty) {
      throw const ConfigurationException('appId and release are required.');
    }
  }

  factory AppConfiguration.fromCompileTime() {
    const environmentName = String.fromEnvironment(
      'APP_ENVIRONMENT',
      defaultValue: 'development',
    );
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const release = String.fromEnvironment('APP_RELEASE', defaultValue: 'dev');
    const buildNumber = String.fromEnvironment(
      'APP_BUILD_NUMBER',
      defaultValue: '0',
    );
    const appId = String.fromEnvironment('APP_ID');
    const telemetryEnabled = bool.fromEnvironment('TELEMETRY_ENABLED');

    if (apiBaseUrl.isEmpty || appId.isEmpty) {
      throw const ConfigurationException(
        'API_BASE_URL and APP_ID must be supplied with --dart-define.',
      );
    }

    return AppConfiguration(
      environment: AppEnvironment.values.firstWhere(
        (value) => value.name == environmentName,
        orElse: () => throw const ConfigurationException(
          'Unsupported APP_ENVIRONMENT: $environmentName',
        ),
      ),
      apiBaseUri: Uri.parse(apiBaseUrl),
      release: release,
      buildNumber: buildNumber,
      appId: appId,
      telemetryEnabled: telemetryEnabled,
    );
  }

  final AppEnvironment environment;
  final Uri apiBaseUri;
  final String release;
  final String buildNumber;
  final String appId;
  final String? minimumSupportedVersion;
  final bool telemetryEnabled;
  final Map<String, String> attributes;

  AppConfiguration mergeApprovedRemote(RemoteConfiguration remote) {
    return AppConfiguration(
      environment: environment,
      apiBaseUri: apiBaseUri,
      release: release,
      buildNumber: buildNumber,
      appId: appId,
      minimumSupportedVersion:
          remote.minimumSupportedVersion ?? minimumSupportedVersion,
      telemetryEnabled: telemetryEnabled && remote.telemetryAllowed,
      attributes: <String, String>{...attributes, ...remote.attributes},
    );
  }
}

final class RemoteConfiguration {
  const RemoteConfiguration({
    this.minimumSupportedVersion,
    this.telemetryAllowed = true,
    this.attributes = const <String, String>{},
  });

  final String? minimumSupportedVersion;
  final bool telemetryAllowed;
  final Map<String, String> attributes;
}

abstract interface class RemoteConfigurationSource {
  Future<RemoteConfiguration> load();
}
