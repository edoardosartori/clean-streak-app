import 'package:flutter/material.dart';

@immutable
class FusionThemeExtension extends ThemeExtension<FusionThemeExtension> {
  final Color stateActive;
  final Color stateOnActive;
  final Color stateActiveTint;

  final Color characterLetter;
  final Color characterDigit;
  final Color characterSymbol;

  final Color success;
  final Color danger;

  final Color border;
  final Color surfaceVariant;
  final Color track;

  final Color scrim;

  const FusionThemeExtension({
    required this.stateActive,
    required this.stateOnActive,
    required this.stateActiveTint,
    required this.characterLetter,
    required this.characterDigit,
    required this.characterSymbol,
    required this.success,
    required this.danger,
    required this.border,
    required this.surfaceVariant,
    required this.track,
    required this.scrim,
  });

  @override
  FusionThemeExtension copyWith({
    Color? stateActive,
    Color? stateOnActive,
    Color? stateActiveTint,
    Color? characterLetter,
    Color? characterDigit,
    Color? characterSymbol,
    Color? success,
    Color? danger,
    Color? border,
    Color? surfaceVariant,
    Color? track,
    Color? scrim,
  }) {
    return FusionThemeExtension(
      stateActive: stateActive ?? this.stateActive,
      stateOnActive: stateOnActive ?? this.stateOnActive,
      stateActiveTint: stateActiveTint ?? this.stateActiveTint,
      characterLetter: characterLetter ?? this.characterLetter,
      characterDigit: characterDigit ?? this.characterDigit,
      characterSymbol: characterSymbol ?? this.characterSymbol,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      border: border ?? this.border,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      track: track ?? this.track,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  ThemeExtension<FusionThemeExtension> lerp(
    covariant ThemeExtension<FusionThemeExtension>? other,
    double t,
  ) {
    if (other is! FusionThemeExtension) {
      return this;
    }

    return FusionThemeExtension(
      stateActive: Color.lerp(stateActive, other.stateActive, t)!,
      stateOnActive: Color.lerp(stateOnActive, other.stateOnActive, t)!,
      stateActiveTint: Color.lerp(stateActiveTint, other.stateActiveTint, t)!,
      characterLetter: Color.lerp(characterLetter, other.characterLetter, t)!,
      characterDigit: Color.lerp(characterDigit, other.characterDigit, t)!,
      characterSymbol: Color.lerp(characterSymbol, other.characterSymbol, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      track: Color.lerp(track, other.track, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
