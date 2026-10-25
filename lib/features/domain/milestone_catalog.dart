import 'calendar_math.dart';

/// A milestone from the fixed catalog.
///
/// Milestones are expressed in [months] + [days] (calendar semantics, not
/// fixed durations): the target date is computed from the streak start.
///
/// [canDisable] is false ONLY for the recurring half-year milestones
/// (1.5 years and beyond): those are always on, by design decision.
class MilestoneDefinition {
  const MilestoneDefinition({
    required this.id,
    required this.months,
    this.days = 0,
    required this.canDisable,
  });

  /// Stable id, also used as per-timer toggle key ("1d", "6m", "2.5y").
  final String id;

  /// Whole calendar months from the streak start (0 for day milestones).
  final int months;

  /// Extra days after the months part (1, 2, 3 or 7 for day milestones).
  final int days;

  /// False only for the recurring half-year milestones.
  final bool canDisable;

  /// The moment the streak reaches this milestone.
  DateTime targetDateFrom(DateTime startAt) =>
      addMonths(startAt, months).add(Duration(days: days));

  /// English label for UI and notifications ("1 day", "6 months", "1.5 years").
  String get label {
    if (days > 0) return days == 1 ? '1 day' : '$days days';
    final int years = months ~/ 12;
    if (years == 0) return months == 1 ? '1 month' : '$months months';
    return months % 12 == 6
        ? '$years.5 years'
        : (years == 1 ? '1 year' : '$years years');
  }
}

/// The fixed milestone catalog.
///
/// Base set: 1, 2, 3, 7 days -> 1, 2, 3, 6, 9 months -> 1 year, then every
/// half year forever (1.5y, 2y, 2.5y, 3y, ...), generated lazily.
class MilestoneCatalog {
  const MilestoneCatalog._();

  /// The ten user-toggleable milestones, chronological.
  static const List<MilestoneDefinition> fixed = [
    MilestoneDefinition(id: '1d', months: 0, days: 1, canDisable: true),
    MilestoneDefinition(id: '2d', months: 0, days: 2, canDisable: true),
    MilestoneDefinition(id: '3d', months: 0, days: 3, canDisable: true),
    MilestoneDefinition(id: '7d', months: 0, days: 7, canDisable: true),
    MilestoneDefinition(id: '1m', months: 1, canDisable: true),
    MilestoneDefinition(id: '2m', months: 2, canDisable: true),
    MilestoneDefinition(id: '3m', months: 3, canDisable: true),
    MilestoneDefinition(id: '6m', months: 6, canDisable: true),
    MilestoneDefinition(id: '9m', months: 9, canDisable: true),
    MilestoneDefinition(id: '1y', months: 12, canDisable: true),
  ];

  /// First recurring milestone: 1.5 years = 18 months.
  static const int firstRecurringMonths = 18;

  /// Step of the recurring series: every half year.
  static const int recurringStepMonths = 6;

  /// All milestones in chronological order: the ten fixed ones, then the
  /// half-year series forever. Lazy: call with `take`/`elementAt`.
  static Iterable<MilestoneDefinition> ordered() sync* {
    yield* fixed;
    for (int m = firstRecurringMonths;; m += recurringStepMonths) {
      yield MilestoneDefinition(
          id: _recurringId(m), months: m, canDisable: false);
    }
  }

  static String _recurringId(int months) {
    final int years = months ~/ 12;
    return months % 12 == 6 ? '$years.5y' : '${years}y';
  }
}
