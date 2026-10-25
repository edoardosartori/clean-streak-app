/// Calendar arithmetic shared by the domain layer.
///
/// Semantics: "1 month" means the same day-of-month of the
/// next month, clamped when the target month is shorter
/// (Jan 31 + 1 month = Feb 28/29).
library;

/// Returns [date] shifted forward by [months], clamping the day.
DateTime addMonths(DateTime date, int months) {
  final int totalMonths = date.month - 1 + months;
  final int year = date.year + totalMonths ~/ 12;
  final int month = totalMonths % 12 + 1;
  final int daysInTargetMonth = DateTime(year, month + 1, 0).day;
  final int day = date.day <= daysInTargetMonth ? date.day : daysInTargetMonth;

  return DateTime(
    year,
    month,
    day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
