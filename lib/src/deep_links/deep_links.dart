abstract interface class DeepLinkSignatureVerifier {
  Future<bool> verify(Uri uri);
}

final class DeepLinkPolicy {
  DeepLinkPolicy({
    required Set<String> allowedSchemes,
    required Set<String> allowedHosts,
    required Set<String> allowedPathPrefixes,
  })  : allowedSchemes = Set<String>.unmodifiable(allowedSchemes),
        allowedHosts = Set<String>.unmodifiable(allowedHosts),
        allowedPathPrefixes = Set<String>.unmodifiable(allowedPathPrefixes);

  final Set<String> allowedSchemes;
  final Set<String> allowedHosts;
  final Set<String> allowedPathPrefixes;

  bool allows(Uri uri) {
    if (!allowedSchemes.contains(uri.scheme.toLowerCase())) return false;
    if (uri.host.isNotEmpty && !allowedHosts.contains(uri.host.toLowerCase())) {
      return false;
    }
    return allowedPathPrefixes.any(uri.path.startsWith);
  }
}

abstract interface class DeepLinkHandler {
  Future<bool> handle(Uri uri);
}

final class ValidatingDeepLinkHandler implements DeepLinkHandler {
  const ValidatingDeepLinkHandler({
    required this.policy,
    required this.onAccepted,
    this.signatureVerifier,
  });

  final DeepLinkPolicy policy;
  final DeepLinkSignatureVerifier? signatureVerifier;
  final Future<void> Function(Uri uri) onAccepted;

  @override
  Future<bool> handle(Uri uri) async {
    if (!policy.allows(uri)) return false;
    if (signatureVerifier != null && !await signatureVerifier!.verify(uri)) {
      return false;
    }
    await onAccepted(uri);
    return true;
  }
}
