import 'dart:math';

import '../testing/primitives.dart';

/// Production [IdGenerator] producing RFC 4122 version 4 UUIDs from a
/// cryptographically secure random source.
final class UuidV4Generator implements IdGenerator {
  UuidV4Generator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  static final RegExp pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  @override
  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Produces URL-safe random strings for OAuth state, nonces, and verifiers.
String secureRandomString({int length = 43, Random? random}) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final source = random ?? Random.secure();
  return String.fromCharCodes(
    List<int>.generate(
      length,
      (_) => alphabet.codeUnitAt(source.nextInt(alphabet.length)),
    ),
  );
}
