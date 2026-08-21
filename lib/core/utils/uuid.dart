import 'dart:math';

/// RFC 4122 version-4 UUID generation.
///
/// Products, variant groups, promotions and the like are keyed by `uuid` in
/// Postgres, so client-minted identifiers (new rows created in the back-office,
/// demo-mode fixtures) must be well-formed or the insert is rejected with
/// `invalid input syntax for type uuid`.
abstract final class Uuid {
  static final Random _rng = Random.secure();

  /// A random v4 UUID, e.g. `f47ac10b-58cc-4372-a567-0e02b2c3d479`.
  static String v4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static final RegExp _pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Whether [value] is a syntactically valid UUID.
  static bool isValid(String? value) =>
      value != null && _pattern.hasMatch(value);
}
