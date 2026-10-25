import 'package:flutter/material.dart';

import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../models/tracker.dart';
import 'timer_glyph.dart';

/// Shown when the last tracker has been deleted: invites to
/// create a new one.
class EmptyTrackers extends StatelessWidget {
  const EmptyTrackers({super.key, required this.onNewTimer});

  final VoidCallback onNewTimer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ext.surfaceVariant,
            ),
            alignment: Alignment.center,
            child: TimerGlyph(
              id: TimerGlyphId.droplet,
              size: 26,
              color: ext.stateActive,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No timers yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your first tracker to start a streak.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: secondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onNewTimer,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('New timer'),
            ),
          ),
        ],
      ),
    );
  }
}
