/// Defensive JSON coercion helpers. Postgres/Supabase can return numeric columns
/// as either `num` or `String` depending on driver/serialisation, so we never
/// assume a concrete type.
abstract final class J {
  static String str(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static String? strOrNull(dynamic v) => v?.toString();

  static double toDouble(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static double? toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static bool toBool(dynamic v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == 't' || s == '1';
  }

  static List<String> strList(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  static DateTime? dateOrNull(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static DateTime date(dynamic v) => dateOrNull(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
