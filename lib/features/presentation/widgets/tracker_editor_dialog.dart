import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/feedback/fusion_dialog.dart';
import '../../../core/theme/fusion_motion.dart';
import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../domain/milestone_catalog.dart';
import '../../models/tracker.dart';
import 'dashed_border.dart';
import 'streak_hero_card.dart' show HeroSceneBackdrop;
import 'timer_glyph.dart';

/// What the editor returns to the caller.
sealed class TrackerEditorResult {
  const TrackerEditorResult();
}

final class TrackerEditorSaved extends TrackerEditorResult {
  const TrackerEditorSaved(this.tracker);
  final Tracker tracker;
}

final class TrackerEditorDeleted extends TrackerEditorResult {
  const TrackerEditorDeleted(this.id);
  final String id;
}

/// Fusion-styled editor dialog for one timer (create or edit).
///
/// Same visual recipe as FusionDialog (blurred scrim + surface
/// card, border in dark, soft shadow in light) with a custom
/// body: icon picker, optional name, hero scene thumbnails,
/// milestone chips and the relapse date (any date & time).
class TrackerEditorDialog {
  TrackerEditorDialog._();

  /// [tracker] is the draft to edit. For a new timer the caller
  /// builds a default tracker (new id, droplet, peaks, start now)
  /// and passes [isNew]: true = "New timer" title, no delete link.
  static Future<TrackerEditorResult?> show(
    BuildContext context, {
    required Tracker tracker,
    bool isNew = false,
  }) {
    return showGeneralDialog<TrackerEditorResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss editor',
      barrierColor: Colors.transparent,
      transitionDuration: FusionMotion.normal,
      pageBuilder: (dialogContext, _, __) => _EditorView(
        tracker: tracker,
        isNew: isNew,
      ),
      transitionBuilder: _buildTransition,
    );
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

class _EditorView extends StatefulWidget {
  const _EditorView({required this.tracker, required this.isNew});

  final Tracker tracker;
  final bool isNew;

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView> {
  late final TextEditingController _nameController;

  /// Null = no icon: the timer shows the name only.
  late TimerGlyphId? _glyph;
  late HeroScene _scene;
  late Set<String> _disabled;
  late DateTime _startAt;

  static const List<String> _monthNames = [
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

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String _stamp(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year} · '
      '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

  /// Short chip label from the catalog definition ("1 D", "6 M", "1 Y").
  static String _chipLabel(MilestoneDefinition def) {
    if (def.days > 0) return '${def.days} D';
    if (def.months % 12 == 0) return '${def.months ~/ 12} Y';
    return '${def.months} M';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tracker.name ?? '');
    _glyph = widget.tracker.glyph;
    _scene = widget.tracker.scene;
    _disabled = {...widget.tracker.disabledMilestones};
    _startAt = widget.tracker.startAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Relapse on any date & time: Material pickers, clamped to now
  /// (a streak can never start in the future).
  Future<void> _pickRelapseDate() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null || !mounted) return;
    DateTime picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isAfter(now)) {
      picked = now;
    }
    setState(() => _startAt = picked);
  }

  Future<void> _confirmDelete() async {
    final String name = widget.tracker.name ?? 'this timer';
    final bool confirmed = await FusionDialog.confirm(
      context,
      title: 'Delete streak?',
      message: 'Delete $name?\nThe streak is lost and cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(TrackerEditorDeleted(widget.tracker.id));
    }
  }

  void _save() {
    final String name = _nameController.text.trim();
    Navigator.of(context).pop(
      TrackerEditorSaved(
        widget.tracker.copyWith(
          glyph: _glyph,
          scene: _scene,
          name: name.isEmpty ? null : name,
          startAt: _startAt,
          disabledMilestones: _disabled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    final bool isCompact = MediaQuery.sizeOf(context).shortestSide <= 600;
    final double maxWidth = tokens.dimension(
      isCompact
          ? 'component.dialog.maxWidthCompact'
          : 'component.dialog.maxWidthRegular',
    );

    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: tokens.dimension('component.dialog.scrimBlur'),
        sigmaY: tokens.dimension('component.dialog.scrimBlur'),
      ),
      child: Container(
        // effect.scrim, same as FusionDialog.
        color: ext.scrim,
        alignment: Alignment.center,
        // Keeps the dialog reachable when the keyboard opens.
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(
                tokens.dimension('component.dialog.padding'),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  tokens.dimension('component.dialog.radius'),
                ),
                border: isDark ? Border.all(color: ext.border) : null,
                boxShadow: isDark
                    ? null
                    : [
                        // effect.elevation.light
                        BoxShadow(
                          color:
                              const Color(0xFF12161B).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.isNew ? 'New streak' : 'Edit streak',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: tokens.dimension('component.dialog.titleSize'),
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  // The body scrolls if the screen is short.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          _SectionLabel(label: 'Icon', color: secondary),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final TimerGlyphId id in TimerGlyphId.values)
                                _IconTile(
                                  id: id,
                                  selected: id == _glyph,
                                  onTap: () => setState(() => _glyph = id),
                                ),
                              // "No icon": the timer can live without one.
                              _NoIconTile(
                                selected: _glyph == null,
                                onTap: () => setState(() => _glyph = null),
                              ),
                            ],
                          ),
                          _SectionLabel(
                            label: 'Name',
                            color: secondary,
                          ),
                          TextField(
                            controller: _nameController,
                            // Max 12 characters: keeps
                            // the tab and the hero header tidy.
                            maxLength: 12,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Wine, beer…',
                              hintStyle: TextStyle(
                                fontSize: 15,
                                color: secondary.withValues(alpha: 0.55),
                              ),
                              filled: true,
                              fillColor: ext.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: ext.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              counterStyle: TextStyle(
                                fontSize: 11,
                                color: secondary.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                          _SectionLabel(label: 'Card image', color: secondary),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final HeroScene scene in HeroScene.values)
                                _SceneThumb(
                                  scene: scene,
                                  brightness: theme.brightness,
                                  selected: scene == _scene,
                                  onTap: () => setState(() => _scene = scene),
                                ),
                            ],
                          ),
                          _SectionLabel(label: 'Milestones', color: secondary),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final MilestoneDefinition def
                                  in MilestoneCatalog.fixed)
                                _MilestoneChip(
                                  label: _chipLabel(def),
                                  off: _disabled.contains(def.id),
                                  onTap: () => setState(() {
                                    if (_disabled.contains(def.id)) {
                                      _disabled.remove(def.id);
                                    } else {
                                      _disabled.add(def.id);
                                    }
                                  }),
                                ),
                              const _LockedChip(label: '0.5 Y steps'),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Default: all on. Half-year milestones '
                              '(1.5 Y, 2 Y, 2.5 Y…) are always on.',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                          _SectionLabel(
                            label: 'Relapse on (any date & time)',
                            color: secondary,
                          ),
                          _DateField(
                            stamp: _stamp(_startAt),
                            onTap: _pickRelapseDate,
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogButton(
                          label: 'Cancel',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(
                        width: tokens.dimension('component.dialog.actionGap'),
                      ),
                      Expanded(
                        child: _DialogButton(
                          label: 'Save',
                          primary: true,
                          onTap: _save,
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isNew) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: GestureDetector(
                        onTap: _confirmDelete,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ext.danger,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final TimerGlyphId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    // No placeholder box around the unchosen icons: they are just
    // the gray glyph on the dialog surface. Only the selection
    // gets the cyan tint (mockup v0.3.4 "pick.sel").
    return Material(
      color: selected ? ext.stateActiveTint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: TimerGlyph(
              id: id,
              size: 20,
              color: selected ? ext.stateActive : secondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "no icon" option of the picker: dashed tile (suite "off"
/// style, like the "+" tab) unless selected, then it takes the
/// same cyan tint as a regular selected icon.
class _NoIconTile extends StatelessWidget {
  const _NoIconTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    return CustomPaint(
      foregroundPainter:
          selected ? null : DashedRoundedRectPainter(color: ext.border),
      child: Material(
        color: selected ? ext.stateActiveTint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                Icons.block_rounded,
                size: 18,
                color: selected ? ext.stateActive : secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneThumb extends StatelessWidget {
  const _SceneThumb({
    required this.scene,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });

  final HeroScene scene;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : ext.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 76,
              height: 52,
              child: HeroSceneBackdrop(scene: scene, brightness: brightness),
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({
    required this.label,
    required this.off,
    required this.onTap,
  });

  final String label;
  final bool off;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );

    if (off) {
      // Switched off: transparent with a dashed border (mockup).
      return CustomPaint(
        foregroundPainter: DashedRoundedRectPainter(color: ext.border),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: secondary.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: ext.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              color: secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedChip extends StatelessWidget {
  const _LockedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The recurring half-year series: always on, blue tint (mockup).
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.lock_rounded,
            size: 11,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.stamp, required this.onTap});

  final String stamp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return Material(
      color: ext.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            stamp,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 15,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return SizedBox(
      // component.button.height
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor:
              primary ? theme.colorScheme.primary : ext.surfaceVariant,
          foregroundColor: primary
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            // component.button.radius
            borderRadius: BorderRadius.circular(16),
            side: primary ? BorderSide.none : BorderSide(color: ext.border),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
