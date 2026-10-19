import 'package:flutter/material.dart';

import 'fusion_theme_extension.dart';
import 'fusion_tokens.dart';

class FusionTheme {
  FusionTheme._();

  static ThemeData dark(
    FusionTokens tokens,
  ) {
    return _build(
      tokens,
      brightness: Brightness.dark,
      semanticPrefix: 'semantic.dark',
    );
  }

  static ThemeData light(
    FusionTokens tokens,
  ) {
    return _build(
      tokens,
      brightness: Brightness.light,
      semanticPrefix: 'semantic.light',
    );
  }

  static ThemeData _build(
    FusionTokens tokens, {
    required Brightness brightness,
    required String semanticPrefix,
  }) {
    final primary = tokens.color('$semanticPrefix.action.primary');

    final background = tokens.color('$semanticPrefix.background');

    final surface = tokens.color('$semanticPrefix.surface');

    final text = tokens.color('$semanticPrefix.textPrimary');

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: tokens.color(
          '$semanticPrefix.action.onPrimary',
        ),
        secondary: primary,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),
      extensions: [
        FusionThemeExtension(
          stateActive: tokens.color('$semanticPrefix.state.active'),
          stateOnActive: tokens.color('$semanticPrefix.state.onActive'),
          stateActiveTint: tokens.color('$semanticPrefix.state.activeTint'),
          characterLetter: tokens.color('$semanticPrefix.character.letter'),
          characterDigit: tokens.color('$semanticPrefix.character.digit'),
          characterSymbol: tokens.color('$semanticPrefix.character.symbol'),
          success: tokens.color('$semanticPrefix.feedback.success'),
          danger: tokens.color('$semanticPrefix.feedback.danger'),
          border: tokens.color('$semanticPrefix.border'),
          surfaceVariant: tokens.color('$semanticPrefix.surfaceVariant'),
          track: tokens.color('$semanticPrefix.track'),
          scrim: tokens.color('$semanticPrefix.scrim'),
        ),
      ],
    );
  }
}
