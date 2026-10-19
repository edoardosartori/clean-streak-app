import 'package:flutter/material.dart';

import 'fusion_tokens.dart';

/// Exposes the loaded [FusionTokens] to any widget below it.
///
/// Wrap the [MaterialApp] so shared widgets (e.g. FusionToast,
/// FusionDialog) can read the token values they need at runtime.
class FusionTokensScope extends InheritedWidget {
  final FusionTokens tokens;

  const FusionTokensScope({
    super.key,
    required this.tokens,
    required super.child,
  });

  static FusionTokens of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FusionTokensScope>();

    if (scope == null) {
      throw FlutterError(
        'FusionTokensScope not found: wrap the app in a '
        'FusionTokensScope.',
      );
    }

    return scope.tokens;
  }

  @override
  bool updateShouldNotify(FusionTokensScope oldWidget) =>
      tokens != oldWidget.tokens;
}
