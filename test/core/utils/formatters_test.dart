import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('price', () {
      test('formats positive integer correctly', () {
        expect(Formatters.price(245), equals('\$245.00'));
      });

      test('formats positive decimal correctly', () {
        expect(Formatters.price(245.50), equals('\$245.50'));
        expect(Formatters.price(245.99), equals('\$245.99'));
        expect(Formatters.price(245.999), equals('\$246.00')); // Rounding
      });

      test('formats zero correctly', () {
        expect(Formatters.price(0), equals('\$0.00'));
      });

      test('formats negative integer correctly', () {
        expect(Formatters.price(-15), equals('-\$15.00'));
      });

      test('formats large numbers correctly with commas', () {
        expect(Formatters.price(1234567.89), equals('\$1,234,567.89'));
      });
    });

    group('priceTrim', () {
      test('trims trailing .00 for whole numbers', () {
        expect(Formatters.priceTrim(245), equals('\$245'));
        expect(Formatters.priceTrim(0), equals('\$0'));
      });

      test('keeps decimal for non-whole numbers', () {
        expect(Formatters.priceTrim(245.50), equals('\$245.50'));
        expect(Formatters.priceTrim(245.99), equals('\$245.99'));
      });

      test('formats negative numbers correctly', () {
        expect(Formatters.priceTrim(-15), equals('-\$15'));
        expect(Formatters.priceTrim(-15.5), equals('-\$15.50'));
      });
    });

    group('compact', () {
      test('formats numbers less than 1000 correctly', () {
        expect(Formatters.compact(999), equals('999'));
      });

      test('formats thousands correctly', () {
        expect(Formatters.compact(1000), equals('1K'));
        expect(Formatters.compact(1500), equals('1.5K'));
      });

      test('formats millions correctly', () {
        expect(Formatters.compact(1000000), equals('1M'));
        expect(Formatters.compact(2500000), equals('2.5M'));
      });

      test('formats zero correctly', () {
        expect(Formatters.compact(0), equals('0'));
      });

      test('formats negative numbers correctly', () {
        expect(Formatters.compact(-1500), equals('-1.5K'));
      });
    });

    group('date', () {
      test('formats date correctly', () {
        // We test with a specific DateTime to avoid local time zone issues in CI if possible,
        // but since toLocal() is used internally, we'll create a local DateTime to start with.
        final dt = DateTime(2023, 10, 15, 14, 30);
        expect(Formatters.date(dt), equals('Oct 15, 2023'));
      });
    });
  });
}
