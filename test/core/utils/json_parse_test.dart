import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard_fashion/core/utils/json_parse.dart';

void main() {
  group('J (JSON Parse Utils)', () {
    group('str', () {
      test('returns empty string fallback when null', () {
        expect(J.str(null), '');
      });

      test('returns custom fallback when null', () {
        expect(J.str(null, 'default'), 'default');
      });

      test('returns string value', () {
        expect(J.str('hello'), 'hello');
      });

      test('converts non-string to string', () {
        expect(J.str(123), '123');
      });
    });

    group('strOrNull', () {
      test('returns null when null', () {
        expect(J.strOrNull(null), null);
      });

      test('returns string value', () {
        expect(J.strOrNull('hello'), 'hello');
      });

      test('converts non-string to string', () {
        expect(J.strOrNull(123), '123');
      });
    });

    group('toDouble', () {
      test('returns 0.0 fallback when null', () {
        expect(J.toDouble(null), 0.0);
      });

      test('returns custom fallback when null', () {
        expect(J.toDouble(null, 5.0), 5.0);
      });

      test('returns double when given double', () {
        expect(J.toDouble(12.5), 12.5);
      });

      test('returns double when given int', () {
        expect(J.toDouble(10), 10.0);
      });

      test('parses string to double', () {
        expect(J.toDouble('15.5'), 15.5);
      });

      test('returns fallback on parse error', () {
        expect(J.toDouble('abc'), 0.0);
      });

      test('returns custom fallback on parse error', () {
        expect(J.toDouble('abc', 5.0), 5.0);
      });
    });

    group('toDoubleOrNull', () {
      test('returns null when null', () {
        expect(J.toDoubleOrNull(null), null);
      });

      test('returns double when given double', () {
        expect(J.toDoubleOrNull(12.5), 12.5);
      });

      test('returns double when given int', () {
        expect(J.toDoubleOrNull(10), 10.0);
      });

      test('parses string to double', () {
        expect(J.toDoubleOrNull('15.5'), 15.5);
      });

      test('returns null on parse error', () {
        expect(J.toDoubleOrNull('abc'), null);
      });
    });

    group('toInt', () {
      test('returns 0 fallback when null', () {
        expect(J.toInt(null), 0);
      });

      test('returns custom fallback when null', () {
        expect(J.toInt(null, 5), 5);
      });

      test('returns int when given int', () {
        expect(J.toInt(10), 10);
      });

      test('returns int when given double', () {
        expect(J.toInt(10.5), 10);
      });

      test('parses string to int', () {
        expect(J.toInt('15'), 15);
      });

      test('returns fallback on parse error', () {
        expect(J.toInt('abc'), 0);
      });
    });

    group('toBool', () {
      test('returns false fallback when null', () {
        expect(J.toBool(null), false);
      });

      test('returns custom fallback when null', () {
        expect(J.toBool(null, true), true);
      });

      test('returns boolean when given boolean', () {
        expect(J.toBool(true), true);
      });

      test('parses "true" string (case insensitive)', () {
        expect(J.toBool('true'), true);
        expect(J.toBool('TrUe'), true);
      });

      test('parses "t" string (case insensitive)', () {
        expect(J.toBool('t'), true);
        expect(J.toBool('T'), true);
      });

      test('parses "1" string', () {
        expect(J.toBool('1'), true);
      });

      test('returns false for other strings', () {
        expect(J.toBool('false'), false);
        expect(J.toBool('0'), false);
        expect(J.toBool('abc'), false);
      });

      test('returns false for other numeric values', () {
        expect(J.toBool(0), false);
        expect(J.toBool(1), true);
      });
    });

    group('strList', () {
      test('returns empty list when null', () {
        expect(J.strList(null), []);
      });

      test('returns list of strings', () {
        expect(J.strList(['a', 'b']), ['a', 'b']);
      });

      test('converts non-string elements to strings', () {
        expect(J.strList([1, 2, true]), ['1', '2', 'true']);
      });

      test('returns empty list for non-list inputs', () {
        expect(J.strList('abc'), []);
        expect(J.strList(123), []);
      });
    });

    group('dateOrNull', () {
      test('returns null when null', () {
        expect(J.dateOrNull(null), null);
      });

      test('returns DateTime when given DateTime', () {
        final date = DateTime(2020);
        expect(J.dateOrNull(date), date);
      });

      test('parses ISO8601 string', () {
        expect(J.dateOrNull('2020-01-01T00:00:00Z'),
            DateTime.parse('2020-01-01T00:00:00Z'));
      });

      test('returns null on invalid string format', () {
        expect(J.dateOrNull('invalid'), null);
      });
    });

    group('date', () {
      test('returns epoch 0 when null', () {
        expect(J.date(null), DateTime.fromMillisecondsSinceEpoch(0));
      });

      test('parses ISO8601 string', () {
        expect(J.date('2020-01-01T00:00:00.000Z'),
            DateTime.parse('2020-01-01T00:00:00.000Z'));
      });

      test('returns epoch 0 on invalid string format', () {
        expect(J.date('invalid'), DateTime.fromMillisecondsSinceEpoch(0));
      });
    });
  });
}
