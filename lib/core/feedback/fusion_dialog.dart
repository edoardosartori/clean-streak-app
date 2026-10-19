import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/fusion_motion.dart';
import '../theme/fusion_tokens_scope.dart';
import '../theme/fusion_theme_extension.dart';
import 'fusion_toast.dart';

enum _FusionDialogActionStyle { primary, secondary, destructive }

class _FusionDialogAction {
  final String label;
  final _FusionDialogActionStyle style;
  final VoidCallback onTap;

  const _FusionDialogAction({
    required this.label,
    required this.style,
    required this.onTap,
  });
}

/// Fusion-styled modal dialog on a blurred scrim.
///
/// Adapts its width to the device display: 310 dp on phones,
/// 420 dp on tablets (token: component.dialog.maxWidth*).
class FusionDialog {
  FusionDialog._();

  /// Single-action dialog (info or error, depending on [variant]).
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'OK',
    FusionFeedbackVariant? variant,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss dialog',
      // The scrim (color + blur) is drawn by the dialog itself.
      barrierColor: Colors.transparent,
      transitionDuration: FusionMotion.normal,
      pageBuilder: (dialogContext, _, __) => _FusionDialogView(
        title: title,
        message: message,
        variant: variant,
        actions: [
          _FusionDialogAction(
            label: actionLabel,
            style: _FusionDialogActionStyle.primary,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
      transitionBuilder: _buildTransition,
    );
  }

  /// Cancel/confirm dialog. Returns true only if the confirm
  /// action is tapped. With [isDestructive] the confirm button
  /// uses the danger style (token: component.dialog.destructive).
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss dialog',
      barrierColor: Colors.transparent,
      transitionDuration: FusionMotion.normal,
      pageBuilder: (dialogContext, _, __) => _FusionDialogView(
        title: title,
        message: message,
        actions: [
          _FusionDialogAction(
            label: cancelLabel,
            style: _FusionDialogActionStyle.secondary,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          _FusionDialogAction(
            label: confirmLabel,
            style: isDestructive
                ? _FusionDialogActionStyle.destructive
                : _FusionDialogActionStyle.primary,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
      transitionBuilder: _buildTransition,
    );

    return result ?? false;
  }

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> _,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: FusionMotion.curve),
        ),
        child: child,
      ),
    );
  }
}

class _FusionDialogView extends StatelessWidget {
  final String title;
  final String message;
  final FusionFeedbackVariant? variant;
  final List<_FusionDialogAction> actions;

  const _FusionDialogView({
    required this.title,
    required this.message,
    required this.actions,
    this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);

    // Adapts to the device display: 310 dp on phones,
    // 420 dp on tablets (token: component.dialog.maxWidth*).
    final isCompact = MediaQuery.sizeOf(context).shortestSide <= 600;

    final maxWidth = tokens.dimension(
      isCompact
          ? 'component.dialog.maxWidthCompact'
          : 'component.dialog.maxWidthRegular',
    );

    final semanticPrefix = theme.brightness == Brightness.dark
        ? 'semantic.dark'
        : 'semantic.light';

    Widget? iconBadge;

    if (variant != null) {
      final (icon, color) = switch (variant!) {
        FusionFeedbackVariant.success => (Icons.check_rounded, ext.success),
        FusionFeedbackVariant.error => (
            Icons.error_outline_rounded,
            ext.danger
          ),
      };

      final badgeSize = tokens.dimension('component.dialog.iconBadgeSize');

      // Badge pattern: tint of the feedback color under the icon.
      iconBadge = Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: color,
          size: tokens.dimension('component.dialog.iconSize'),
        ),
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: tokens.dimension('component.dialog.scrimBlur'),
        sigmaY: tokens.dimension('component.dialog.scrimBlur'),
      ),
      child: Container(
        // effect.scrim: ink at 60% (dark) / 45% (light).
        color: ext.scrim,
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding:
                EdgeInsets.all(tokens.dimension('component.dialog.padding')),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(
                tokens.dimension('component.dialog.radius'),
              ),
              // Card style: subtle border in dark, soft shadow in light.
              border: theme.brightness == Brightness.dark
                  ? Border.all(color: ext.border)
                  : null,
              boxShadow: theme.brightness == Brightness.light
                  ? [
                      // effect.elevation.light
                      BoxShadow(
                        color: const Color(0xFF12161B).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (iconBadge != null) ...[
                  Center(child: iconBadge),
                  const SizedBox(height: 20), // primitive.space.xl
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: tokens.dimension('component.dialog.titleSize'),
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8), // primitive.space.sm
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: tokens.dimension('component.dialog.messageSize'),
                    color: tokens.color('$semanticPrefix.textSecondary'),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24), // primitive.space.2xl
                if (actions.length == 1)
                  _buildButton(context, actions.first)
                else
                  Row(
                    children: [
                      Expanded(child: _buildButton(context, actions.first)),
                      SizedBox(
                        width: tokens.dimension('component.dialog.actionGap'),
                      ),
                      Expanded(child: _buildButton(context, actions.last)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    _FusionDialogAction action,
  ) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    final (background, foreground, side) = switch (action.style) {
      // component.button.primary
      _FusionDialogActionStyle.primary => (
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
          BorderSide.none,
        ),
      // component.button.secondary
      _FusionDialogActionStyle.secondary => (
          ext.surfaceVariant,
          theme.colorScheme.onSurface,
          BorderSide(color: ext.border, width: 1),
        ),
      // component.dialog.destructive
      _FusionDialogActionStyle.destructive => (
          ext.danger,
          Colors.white,
          BorderSide.none,
        ),
    };

    return SizedBox(
      // component.button.height
      height: 52,
      child: FilledButton(
        onPressed: action.onTap,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            // component.button.radius
            borderRadius: BorderRadius.circular(16),
            side: side,
          ),
        ),
        child: Text(action.label),
      ),
    );
  }
}
