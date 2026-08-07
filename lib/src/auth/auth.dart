import 'dart:async';
import 'dart:convert';

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
  const AuthSnapshot({
    required this.status,
    this.subject,
    this.errorCode,
  });

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
      final parsedExpiry = DateTime.parse(value['accessTokenExpiresAt']! as String);
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
        'accessTokenExpiresAt':
            tokens.accessTokenExpiresAt.toUtc().toIso8601String(),
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
  });

  final Uri authorizationEndpoint;
  final String clientId;
  final Uri redirectUri;
  final List<String> scopes;
  final String state;
  final String nonce;
  final String codeChallenge;
}

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
  })  : _oidc = oidc,
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
      _emit(AuthSnapshot(
        status: localOnlyWhenEmpty ? AuthStatus.localOnly : AuthStatus.signedOut,
      ));
      return _snapshot;
    }
    final current = await validTokens();
    if (current == null) {
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
      _emit(const AuthSnapshot(
        status: AuthStatus.signedOut,
        errorCode: 'authorization_failed',
      ));
      rethrow;
    }
  }

  Future<AuthTokens?> validTokens() => _activeTokenRequest ??=
      _readOrRefresh().whenComplete(() => _activeTokenRequest = null);

  Future<AuthTokens?> _readOrRefresh() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;
    if (!tokens.isExpiring(_clock.nowUtc(), refreshLeeway)) {
      _authenticated(tokens);
      return tokens;
    }
    _emit(const AuthSnapshot(status: AuthStatus.refreshing));
    try {
      final refreshed = await _oidc.refresh(tokens.refreshToken);
      await _tokenStore.save(refreshed);
      _authenticated(refreshed);
      return refreshed;
    } on Object {
      await _tokenStore.clear();
      _emit(const AuthSnapshot(
        status: AuthStatus.expired,
        errorCode: 'refresh_failed',
      ));
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
    _emit(AuthSnapshot(
      status: AuthStatus.authenticated,
      subject: _subjectReader?.subject(tokens),
    ));
  }

  void _emit(AuthSnapshot value) {
    _snapshot = value;
    _snapshots.add(value);
  }

  Future<void> dispose() => _snapshots.close();
}
