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
    required this.glyph,
    required this.scene,
    required this.startAt,
    this.name,
    this.disabledMilestones = const {},
  });

  final String id;
  final TimerGlyphId glyph;
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

  /// Sentinel so [copyWith] can set [name] back to null (the
  /// classic `name ?? this.name` could never clear it).
  static const Object _unset = Object();

  Tracker copyWith({
    String? id,
    TimerGlyphId? glyph,
    HeroScene? scene,
    DateTime? startAt,
    Object? name = _unset,
    Set<String>? disabledMilestones,
  }) {
    return Tracker(
      id: id ?? this.id,
      glyph: glyph ?? this.glyph,
      scene: scene ?? this.scene,
      startAt: startAt ?? this.startAt,
      name: identical(name, _unset) ? this.name : name as String?,
      disabledMilestones: disabledMilestones ?? this.disabledMilestones,
    );
  }
}
