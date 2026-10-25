import 'package:clean_streak/features/domain/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final StreakCalculator calc = StreakCalculator();

  group('StreakCalculator.breakdown', () {
    test('exactly four days', () {
      final b = calc.breakdown(
        DateTime(2026, 10, 12, 20, 47),
        DateTime(2026, 10, 16, 20, 47),
      );
      expect(b.years, 0);
      expect(b.months, 0);
      expect(b.days, 4);
      expect(b.hours, 0);
      expect(b.minutes, 0);
      expect(b.seconds, 0);
    });

    test('four days with leftover h/m/s', () {
      final b = calc.breakdown(
        DateTime(2026, 10, 12, 10, 0, 0),
        DateTime(2026, 10, 16, 13, 30, 15),
      );
      expect(b.days, 4);
      expect(b.hours, 3);
      expect(b.minutes, 30);
      expect(b.seconds, 15);
    });

    test('one month and one day', () {
      final b = calc.breakdown(
        DateTime(2026, 10, 12, 8, 0),
        DateTime(2026, 11, 13, 8, 0),
      );
      expect(b.months, 1);
      expect(b.days, 1);
    });

    test('across the year boundary', () {
      final b = calc.breakdown(
        DateTime(2026, 11, 12, 8, 0),
        DateTime(2027, 1, 13, 8, 0),
      );
      expect(b.years, 0);
      expect(b.months, 2);
      expect(b.days, 1);
    });

    test('exactly one year', () {
      final b = calc.breakdown(
        DateTime(2026, 10, 12, 20, 47),
        DateTime(2027, 10, 12, 20, 47),
      );
      expect(b.years, 1);
      expect(b.months, 0);
      expect(b.days, 0);
      expect(b.hours, 0);
    });

    test('Jan 31 -> Mar 1 counts as 1 month 1 day (clamped to Feb 28)', () {
      final b = calc.breakdown(
        DateTime(2027, 1, 31, 12, 0),
        DateTime(2027, 3, 1, 12, 0),
      );
      expect(b.months, 1);
      expect(b.days, 1);
    });

    test('leap year: Feb 29 -> Mar 30 counts as 1 month 1 day', () {
      final b = calc.breakdown(
        DateTime(2028, 2, 29, 10, 0),
        DateTime(2028, 3, 30, 10, 0),
      );
      expect(b.months, 1);
      expect(b.days, 1);
    });
  });

  group('StreakCalculator.totalDays', () {
    test('whole days elapsed', () {
      expect(
        calc.totalDays(
          DateTime(2026, 10, 12, 20, 47),
          DateTime(2026, 10, 16, 20, 47),
        ),
        4,
      );
    });

    test('incomplete day does not count', () {
      expect(
        calc.totalDays(
          DateTime(2026, 10, 12, 20, 47),
          DateTime(2026, 10, 16, 19, 47),
        ),
        3,
      );
    });
  });
}
