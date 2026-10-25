import 'package:flutter/material.dart';

import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/milestone_engine.dart';
import '../../models/tracker.dart';
import 'timer_glyph.dart';

/// "Milestones" card under the hero: last reached / in progress /
/// next — one row each, from MilestoneEngine over the active
/// milestones of the timer.
class MilestoneCard extends StatelessWidget {
  const MilestoneCard({super.key, required this.tracker});

  final Tracker tracker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    final MilestoneSnapshot snapshot = MilestoneEngine().snapshot(
      startAt: tracker.startAt,
      disabledMilestones: tracker.disabledMilestones,
    );

    return Container(
      // Fusion card: radius 16, padding 16, border in dark,
      // soft shadow in light.
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: ext.border) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF12161B).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Milestones',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (snapshot.lastReached != null) ...[
            _MilestoneRow(
              badgeColor: ext.success.withValues(alpha: 0.12),
              badgeChild: Icon(
                Icons.check_rounded,
                size: 14,
                color: ext.success,
              ),
              label: snapshot.lastReached!.definition.label,
              labelColor: secondary,
              trailing:
                  'Reached ${_shortDate(snapshot.lastReached!.reachedAt)}',
            ),
            const SizedBox(height: 7),
          ],
          if (snapshot.current != null) ...[
            _MilestoneRow(
              badgeColor: ext.stateActiveTint,
              badgeChild: TimerGlyph(
                id: TimerGlyphId.droplet,
                size: 14,
                color: ext.stateActive,
              ),
              label: snapshot.current!.definition.label,
              labelColor: theme.colorScheme.onSurface,
              trailing:
                  'In progress · ${_remaining(snapshot.current!.remaining)}',
            ),
            const SizedBox(height: 7),
          ],
          if (snapshot.next != null)
            _MilestoneRow(
              badgeColor: ext.surfaceVariant,
              badgeChild: TimerGlyph(
                id: TimerGlyphId.droplet,
                size: 14,
                color: secondary,
              ),
              label: snapshot.next!.definition.label,
              labelColor: secondary,
              trailing: _shortDate(snapshot.next!.targetDate),
            ),
        ],
      ),
    );
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Oct 15" — compact English date for the milestone rows.
  static String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  /// "in 3 d" / "in 5 h" / "in 12 m" (mockup format).
  static String _remaining(Duration r) {
    if (r.inDays >= 1) return 'in ${r.inDays} d';
    if (r.inHours >= 1) return 'in ${r.inHours} h';
    if (r.inMinutes >= 1) return 'in ${r.inMinutes} m';
    return 'in <1 m';
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.badgeColor,
    required this.badgeChild,
    required this.label,
    required this.labelColor,
    required this.trailing,
  });

  final Color badgeColor;
  final Widget badgeChild;
  final String label;
  final Color labelColor;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: badgeChild,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: labelColor),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 12,
            color: secondary,
          ),
        ),
      ],
    );
  }
}
