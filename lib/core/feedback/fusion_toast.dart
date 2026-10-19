import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/fusion_motion.dart';
import '../theme/fusion_tokens_scope.dart';
import '../theme/fusion_theme_extension.dart';

/// Visual variant of a feedback message.
enum FusionFeedbackVariant { success, error }

/// Fusion-styled transient feedback message.
///
/// Shows a centered toast on a scrim that dims the app behind.
/// The toast adapts its size and font to the device display and
/// dismisses itself after a while: a bottom bar shows the
/// remaining time. Tapping the toast dismisses it early.
class FusionToast {
  FusionToast._();

  /// Shows [message] as a toast, centered on screen and slightly
  /// above the exact center (token: component.toast.centerOffsetY).
  ///
  /// [duration] overrides the default token duration
  /// (component.toast.duration, 1500 ms).
  static void show(
    BuildContext context, {
    required String message,
    FusionFeedbackVariant variant = FusionFeedbackVariant.success,
    Duration? duration,
  }) {
    final tokens = FusionTokensScope.of(context);

    final effectiveDuration = duration ??
        Duration(
          milliseconds: tokens.dimension('component.toast.duration').round(),
        );

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FusionToastView(
        message: message,
        variant: variant,
        duration: effectiveDuration,
        onDismissed: entry.remove,
      ),
    );

    overlay.insert(entry);
  }
}

class _FusionToastView extends StatefulWidget {
  final String message;
  final FusionFeedbackVariant variant;
  final Duration duration;
  final VoidCallback onDismissed;

  const _FusionToastView({
    required this.message,
    required this.variant,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_FusionToastView> createState() => _FusionToastViewState();
}

class _FusionToastViewState extends State<_FusionToastView>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _progress;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: FusionMotion.fast,
    );

    // Drives the remaining-time bar: goes from full to empty
    // over the toast duration.
    _progress = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _timer = Timer(widget.duration, _dismiss);
        _progress.forward(from: 0);
      } else if (status == AnimationStatus.dismissed) {
        widget.onDismissed();
      }
    });

    _controller.forward();
  }

  void _dismiss() {
    if (_dismissed) {
      return;
    }

    _dismissed = true;
    _timer?.cancel();
    _controller.reverse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);

    // Adapts to the device display: compact on phones,
    // regular on tablets (token: component.toast.maxWidth*).
    final isCompact = MediaQuery.sizeOf(context).shortestSide <= 600;

    final semanticPrefix = theme.brightness == Brightness.dark
        ? 'semantic.dark'
        : 'semantic.light';

    final (icon, iconColor) = switch (widget.variant) {
      FusionFeedbackVariant.success => (Icons.check_rounded, ext.success),
      FusionFeedbackVariant.error => (Icons.error_outline_rounded, ext.danger),
    };

    return Positioned.fill(
      child: Stack(
        children: [
          // Scrim over the app behind (effect.scrim, no blur):
          // dims the page so the toast stands out. Taps pass
          // through to the app.
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _controller,
                child: ColoredBox(color: ext.scrim),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Transform.translate(
                offset: Offset(
                  0,
                  -tokens.dimension('component.toast.centerOffsetY'),
                ),
                child: FadeTransition(
                  opacity: _controller,
                  child: GestureDetector(
                    onTap: _dismiss,
                    // The toast sits in an Overlay, outside any
                    // Material/Scaffold: without this Material the
                    // debug build paints the classic yellow double
                    // underline under the text (missing
                    // DefaultTextStyle).
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        constraints: BoxConstraints(
                          maxWidth: tokens.dimension(
                            isCompact
                                ? 'component.toast.maxWidthCompact'
                                : 'component.toast.maxWidthRegular',
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                            tokens.dimension('component.toast.radius'),
                          ),
                          boxShadow: theme.brightness == Brightness.light
                              ? [
                                  // effect.elevation.light
                                  BoxShadow(
                                    color: const Color(0xFF12161B)
                                        .withValues(alpha: 0.08),
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
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.dimension(
                                  'component.toast.paddingHorizontal',
                                ),
                                vertical: tokens.dimension(
                                  'component.toast.paddingVertical',
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    color: iconColor,
                                    size: tokens.dimension(
                                      isCompact
                                          ? 'component.toast.iconSizeCompact'
                                          : 'component.toast.iconSize',
                                    ),
                                  ),
                                  SizedBox(
                                    width:
                                        tokens.dimension('component.toast.gap'),
                                  ),
                                  Flexible(
                                    child: Text(
                                      widget.message,
                                      style: TextStyle(
                                        fontSize: tokens.dimension(
                                          isCompact
                                              ? 'component.toast.fontSizeCompact'
                                              : 'component.toast.fontSize',
                                        ),
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurface,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Remaining-time bar (accent.symbol):
                            // empties from right to left as the
                            // toast approaches its expiry.
                            AnimatedBuilder(
                              animation: _progress,
                              builder: (context, _) {
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (1 - _progress.value)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                                  child: Container(
                                    height: tokens.dimension(
                                      'component.toast.progressBarHeight',
                                    ),
                                    color: tokens
                                        .color('$semanticPrefix.accent.symbol'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
