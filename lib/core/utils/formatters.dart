import 'package:intl/intl.dart';

/// Shared display formatters (currency, dates, stock text).
abstract final class Formatters {
  static final NumberFormat _usd =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');
  static final NumberFormat _compact = NumberFormat.compact();
  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy · h:mm a');

  static String price(num value) => _usd.format(value);

  /// Price without trailing `.00` when whole (e.g. "$245" vs "$245.50").
  static String priceTrim(num value) {
    final s = _usd.format(value);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  static String compact(num value) => _compact.format(value);
  static String date(DateTime dt) => _date.format(dt.toLocal());
  static String dateTime(DateTime dt) => _dateTime.format(dt.toLocal());

  static String stockLabel(int qty, {int lowThreshold = 5}) {
    if (qty <= 0) return 'Sold out';
    if (qty <= lowThreshold) return 'Only $qty left';
    return 'In stock';
  }
}
