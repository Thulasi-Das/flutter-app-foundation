import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../core/secure_ids.dart';
import '../network/network.dart';
import '../secure_storage/secure_storage.dart';
import '../testing/primitives.dart';

enum AuthStatus {
  unknown,
  localOnly,
  authenticating,
  authenticated,
  refreshing,
  expired,
  signedOut,
}

final class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    this.idToken,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final String? idToken;

  bool isExpiring(DateTime now, Duration leeway) =>
      !accessTokenExpiresAt.isAfter(now.add(leeway));
}

final class AuthSnapshot {
  const AuthSnapshot({required this.status, this.subject, this.errorCode});

  final AuthStatus status;
  final String? subject;
  final String? errorCode;
}

abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
}

final class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._storage);

  static const _tokenEnvelope = 'auth.token_envelope';

  final SecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final encoded = await _storage.read(_tokenEnvelope);
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded) as Map<String, Object?>;
      final parsedExpiry = DateTime.parse(
        value['accessTokenExpiresAt']! as String,
      );
      return AuthTokens(
        accessToken: value['accessToken']! as String,
        refreshToken: value['refreshToken']! as String,
        accessTokenExpiresAt: parsedExpiry.toUtc(),
        idToken: value['idToken'] as String?,
      );
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(
      _tokenEnvelope,
      jsonEncode(<String, Object?>{
        'accessToken': tokens.accessToken,
        'refreshToken': tokens.refreshToken,
        'accessTokenExpiresAt': tokens.accessTokenExpiresAt
            .toUtc()
            .toIso8601String(),
        if (tokens.idToken != null) 'idToken': tokens.idToken,
      }),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(_tokenEnvelope);
  }
}

final class OidcAuthorizationRequest {
  const OidcAuthorizationRequest({
    required this.authorizationEndpoint,
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    required this.state,
    required this.nonce,
    required this.codeChallenge,
    this.codeVerifier,
    this.additionalParameters = const <String, String>{},
  });

  /// Creates a request with freshly generated `state`, `nonce`, and an S256
  /// PKCE verifier/challenge pair.
  ///
  /// Keep the returned request until the redirect arrives: the [OidcClient]
  /// needs [codeVerifier] for the token exchange and must reject a callback
  /// whose `state` differs from [state].
  factory OidcAuthorizationRequest.withPkce({
    required Uri authorizationEndpoint,
    required String clientId,
    required Uri redirectUri,
    List<String> scopes = const <String>['openid', 'profile', 'offline_access'],
    Map<String, String> additionalParameters = const <String, String>{},
  }) {
    final verifier = secureRandomString(length: 64);
    return OidcAuthorizationRequest(
      authorizationEndpoint: authorizationEndpoint,
      clientId: clientId,
      redirectUri: redirectUri,
      scopes: List<String>.unmodifiable(scopes),
      state: secureRandomString(length: 32),
      nonce: secureRandomString(length: 32),
      codeChallenge: pkceS256Challenge(verifier),
      codeVerifier: verifier,
      additionalParameters: additionalParameters,
    );
  }

  final Uri authorizationEndpoint;
  final String clientId;
  final Uri redirectUri;
  final List<String> scopes;
  final String state;
  final String nonce;
  final String codeChallenge;

  /// The PKCE secret. Never send it to the authorization endpoint.
  final String? codeVerifier;
  final Map<String, String> additionalParameters;

  /// The URL to open in the system browser (never an embedded web view).
  Uri get authorizationUri => authorizationEndpoint.replace(
    queryParameters: <String, String>{
      ...authorizationEndpoint.queryParameters,
      ...additionalParameters,
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri.toString(),
      'scope': scopes.join(' '),
      'state': state,
      'nonce': nonce,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    },
  );

  /// Validates an authorization redirect and returns its `code`.
  ///
  /// Throws [OidcCallbackException] for provider errors, a mismatched
  /// `state` (possible CSRF), or a missing code.
  String authorizationCodeFrom(Uri callback) {
    final params = callback.queryParameters;
    if (params['error'] case final error?) {
      throw OidcCallbackException(error, params['error_description']);
    }
    if (params['state'] != state) {
      throw const OidcCallbackException('state_mismatch');
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const OidcCallbackException('missing_code');
    }
    return code;
  }
}

final class OidcCallbackException implements Exception {
  const OidcCallbackException(this.code, [this.description]);

  final String code;
  final String? description;

  @override
  String toString() => 'OidcCallbackException($code)';
}

/// RFC 7636 S256 code challenge for [verifier].
String pkceS256Challenge(String verifier) => base64Url
    .encode(crypto.sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

abstract interface class OidcClient {
  Future<AuthTokens> authorize(OidcAuthorizationRequest request);
  Future<AuthTokens> refresh(String refreshToken);
  Future<void> revoke(String refreshToken);
}

abstract interface class SubjectReader {
  String? subject(AuthTokens tokens);
}

final class AuthCoordinator {
  AuthCoordinator({
    required OidcClient oidc,
    required TokenStore tokenStore,
    required Clock clock,
    SubjectReader? subjectReader,
    this.refreshLeeway = const Duration(minutes: 2),
  }) : _oidc = oidc,
       _tokenStore = tokenStore,
       _clock = clock,
       _subjectReader = subjectReader;

  final OidcClient _oidc;
  final TokenStore _tokenStore;
  final Clock _clock;
  final SubjectReader? _subjectReader;
  final Duration refreshLeeway;
  final StreamController<AuthSnapshot> _snapshots =
      StreamController<AuthSnapshot>.broadcast(sync: true);
  AuthSnapshot _snapshot = const AuthSnapshot(status: AuthStatus.unknown);
  Future<AuthTokens?>? _activeTokenRequest;

  AuthSnapshot get snapshot => _snapshot;
  Stream<AuthSnapshot> get snapshots => _snapshots.stream;

  Future<AuthSnapshot> restore({bool localOnlyWhenEmpty = true}) async {
    final tokens = await _tokenStore.read();
    if (tokens == null) {
      _emit(
        AuthSnapshot(
          status: localOnlyWhenEmpty
              ? AuthStatus.localOnly
              : AuthStatus.signedOut,
        ),
      );
      return _snapshot;
    }
    final current = await validTokens();
    // A transient refresh failure keeps the stored session.
    if (current == null && await _tokenStore.read() == null) {
      _emit(const AuthSnapshot(status: AuthStatus.expired));
    }
    return _snapshot;
  }

  Future<AuthTokens> signIn(OidcAuthorizationRequest request) async {
    _emit(const AuthSnapshot(status: AuthStatus.authenticating));
    try {
      final tokens = await _oidc.authorize(request);
      await _tokenStore.save(tokens);
      _authenticated(tokens);
      return tokens;
    } on Object {
      _emit(
        const AuthSnapshot(
          status: AuthStatus.signedOut,
          errorCode: 'authorization_failed',
        ),
      );
      rethrow;
    }
  }

  Future<AuthTokens?> validTokens() => _activeTokenRequest ??= _readOrRefresh()
      .whenComplete(() => _activeTokenRequest = null);

  /// Refreshes even when the stored access token has not expired, for example
  /// after the server rejected it with `401`. Concurrent callers share one
  /// refresh.
  Future<AuthTokens?> forceRefresh() => _activeTokenRequest ??= _readOrRefresh(
    force: true,
  ).whenComplete(() => _activeTokenRequest = null);

  Future<AuthTokens?> _readOrRefresh({bool force = false}) async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;
    if (!force && !tokens.isExpiring(_clock.nowUtc(), refreshLeeway)) {
      _authenticated(tokens);
      return tokens;
    }
    final previous = _snapshot;
    _emit(const AuthSnapshot(status: AuthStatus.refreshing));
    try {
      final refreshed = await _oidc.refresh(tokens.refreshToken);
      await _tokenStore.save(refreshed);
      _authenticated(refreshed);
      return refreshed;
    } on Object catch (error) {
      if (error is ApiFailure && error.retryable) {
        // Offline, timeouts, and server errors must not sign the user out; the
        // refresh token is kept so a later attempt can succeed.
        _emit(
          AuthSnapshot(
            status: AuthStatus.authenticated,
            subject: previous.subject ?? _subjectReader?.subject(tokens),
            errorCode: 'refresh_unavailable',
          ),
        );
        return null;
      }
      await _tokenStore.clear();
      _emit(
        const AuthSnapshot(
          status: AuthStatus.expired,
          errorCode: 'refresh_failed',
        ),
      );
      return null;
    }
  }

  Future<void> signOut() async {
    final tokens = await _tokenStore.read();
    await _tokenStore.clear();
    _emit(const AuthSnapshot(status: AuthStatus.signedOut));
    if (tokens != null) {
      try {
        await _oidc.revoke(tokens.refreshToken);
      } on Object {
        // Local sign-out remains authoritative when remote revocation is down.
      }
    }
  }

  void useLocalOnly() =>
      _emit(const AuthSnapshot(status: AuthStatus.localOnly));

  void _authenticated(AuthTokens tokens) {
    _emit(
      AuthSnapshot(
        status: AuthStatus.authenticated,
        subject: _subjectReader?.subject(tokens),
      ),
    );
  }

  void _emit(AuthSnapshot value) {
    if (value.status == _snapshot.status &&
        value.subject == _snapshot.subject &&
        value.errorCode == _snapshot.errorCode) {
      return;
    }
    _snapshot = value;
    _snapshots.add(value);
  }

  Future<void> dispose() => _snapshots.close();
}

/// Connects an [AuthCoordinator] to [NetworkClient]: supplies fresh access
/// tokens and performs one forced refresh when the server answers `401`.
final class AuthCoordinatorTokenProvider
    implements RefreshableAccessTokenProvider {
  const AuthCoordinatorTokenProvider(this._coordinator);

  final AuthCoordinator _coordinator;

  @override
  Future<String?> accessToken() async =>
      (await _coordinator.validTokens())?.accessToken;

  @override
  Future<String?> refreshAccessToken() async =>
      (await _coordinator.forceRefresh())?.accessToken;
}
