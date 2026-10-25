import 'package:flutter/foundation.dart';

/// The 16 fixed timer glyphs of the v1 set (line-art, suite style).
/// Fixed by design decision: no custom icons in v1.
enum TimerGlyphId {
  droplet,
  flame,
  wineGlass,
  cigarette,
  candy,
  coffee,
  phone,
  dice,
  pill,
  burger,
  tv,
  gamepad,
  shoppingBag,
  dumbbell,
  cookie,
  card,
}

/// The 8 hero card scenes. Every timer always has one (no "None"
/// option in v1); each scene has a dark (night) and light (day)
/// variant picked automatically by the theme.
enum HeroScene { peaks, ocean, forest, city, desert, lake, snow, aurora }

/// A habit tracker with its running streak.
@immutable
class Tracker {
  const Tracker({
    required this.id,
    this.glyph,
    required this.scene,
    required this.startAt,
    this.name,
    this.disabledMilestones = const {},
  });

  final String id;

  /// Optional glyph: a timer can have no icon at all. Without an
  /// icon the tab and the hero show the name only (and a generic
  /// "Timer" label when the name is missing too).
  final TimerGlyphId? glyph;
  final HeroScene scene;

  /// Optional label: without a name only the glyph is shown
  /// (in the tab and in the hero).
  final String? name;

  /// When the current streak started.
  final DateTime startAt;

  /// Milestone ids switched off for this timer. The recurring
  /// half-year milestones (1.5y, 2y, ...) can never be disabled;
  /// MilestoneEngine ignores them here by design.
  final Set<String> disabledMilestones;

  /// Sentinels so [copyWith] can set [name] and [glyph] back to
  /// null (the classic `x ?? this.x` could never clear them).
  static const Object _unset = Object();

  Tracker copyWith({
    String? id,
    Object? glyph = _unset,
    HeroScene? scene,
    DateTime? startAt,
    Object? name = _unset,
    Set<String>? disabledMilestones,
  }) {
    return Tracker(
      id: id ?? this.id,
      glyph: identical(glyph, _unset) ? this.glyph : glyph as TimerGlyphId?,
      scene: scene ?? this.scene,
      startAt: startAt ?? this.startAt,
      name: identical(name, _unset) ? this.name : name as String?,
      disabledMilestones: disabledMilestones ?? this.disabledMilestones,
    );
  }
}
