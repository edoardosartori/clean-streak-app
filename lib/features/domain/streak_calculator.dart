import 'calendar_math.dart';

/// Elapsed time of a streak: calendar Y/M/D + leftover h/m/s.
///
/// The h/m/s part is the remainder toward the next full day, exactly like
/// the Sober Time counter. All values are whole numbers >= 0.
class StreakBreakdown {
  const StreakBreakdown({
    required this.years,
    required this.months,
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final int years;
  final int months;
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  /// Short debug representation, e.g. "0Y 2M 4D 03:09:02".
  @override
  String toString() => '${years}Y ${months}M ${days}D '
      '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Computes how long a streak has been running since [startAt].
///
/// Pure domain class: the clock is injectable so tests can pin "now".
class StreakCalculator {
  StreakCalculator({DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  /// Current time provider. Tests inject a fixed one or pass `at` directly.
  final DateTime Function() clock;

  /// Calendar breakdown of the time elapsed between [startAt] and `now`.
  StreakBreakdown breakdown(DateTime startAt, [DateTime? at]) {
    final DateTime now = at ?? clock();
    assert(!now.isBefore(startAt), 'now must not be before startAt');

    final int months = _wholeMonths(startAt, now);
    final DateTime cursor = addMonths(startAt, months);
    final Duration remainder = now.difference(cursor);

    return StreakBreakdown(
      years: months ~/ 12,
      months: months % 12,
      days: remainder.inDays,
      hours: remainder.inHours % 24,
      minutes: remainder.inMinutes % 60,
      seconds: remainder.inSeconds % 60,
    );
  }

  /// Whole 24h days elapsed (for cumulative stats like "clean days").
  int totalDays(DateTime startAt, [DateTime? at]) {
    final DateTime now = at ?? clock();
    assert(!now.isBefore(startAt), 'now must not be before startAt');
    return now.difference(startAt).inDays;
  }

  /// Whole calendar months between [start] and [end], with overshoot
  /// correction so Jan 31 -> Mar 1 counts as 1 month (Feb 28), not 2.
  int _wholeMonths(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    if (months > 0 && addMonths(start, months).isAfter(end)) {
      months -= 1;
    }
    return months < 0 ? 0 : months;
  }
}
