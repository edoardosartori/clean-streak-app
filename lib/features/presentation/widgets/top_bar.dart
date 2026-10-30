import 'package:flutter/material.dart';

import '../../../core/theme/fusion_motion.dart';
import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../models/tracker.dart';
import '../state/app_state.dart';
import '../state/tracker_controller.dart';
import 'dashed_border.dart';
import 'timer_glyph.dart';

/// Top bar of the home: the timer tabs (tap or swipe), the "+"
/// tab that opens the editor, the cloud backup chip and the
/// theme toggle.
///
/// Long-press on a timer tab picks it up: a floating copy of the
/// chip follows the finger horizontally while the other chips
/// slide aside live; dropping it reorders the tabs (the order
/// persists in Hive and travels in the Drive backup). A
/// long-press WITHOUT moving opens the editor for that tracker
/// (the old entry point). The "+" tab is never draggable.
///
/// When the selection changes (also from the swipe below) the
/// strip auto-scrolls to keep the selected tab in view.
class TopBar extends StatefulWidget {
  const TopBar({
    super.key,
    required this.controller,
    this.isDarkMode,
    this.onToggleTheme,
    this.onNewTimer,
    this.onEditTimer,
    this.onBackupTap,
    this.isBackupConnected = false,
  });

  final TrackerController controller;

  /// Theme state owned by main.dart (pw-generator pattern).
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  /// Tap on the "+" tab: create a new timer.
  final VoidCallback? onNewTimer;

  /// Long-press without moving on a timer tab: edit that tracker.
  final ValueChanged<Tracker>? onEditTimer;

  /// Tap on the cloud chip: open the backup sheet (step 5).
  /// Null = the chip is not shown (no backup service wired).
  final VoidCallback? onBackupTap;

  /// Signed-in state: the chip icon uses the active color.
  final bool isBackupConnected;

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final ScrollController _scrollController = ScrollController();

  /// Attached to whichever chip is currently selected: after a
  /// selection change the strip scrolls to keep it in view.
  final GlobalKey _selectedChipKey = GlobalKey(debugLabel: 'selected-tab');

  /// One key per tab slot (drag reorder step): the chip sizes are
  /// read once when a chip is picked up, so the swap thresholds
  /// match the real chip widths (the tabs are not equal).
  final List<GlobalKey> _chipKeys = <GlobalKey>[];

  /// Drag reorder state. [_dragIndex] is the slot where the drag
  /// started, [_dragSlot] the slot the chip currently sits in (it
  /// swaps live while the finger crosses the other chips).
  ///
  /// CRITICAL (lesson learned on the device): the widget shape at
  /// every slot stays IDENTICAL during the drag. Reparenting the
  /// pressed chip (e.g. into an overlay) destroys the element
  /// that owns the active long-press gesture: no move events, no
  /// release event, chip stuck lifted forever. Instead the
  /// in-row chip just turns invisible (it keeps its slot and the
  /// gesture alive) and a floating CLONE follows the finger.
  static const double _chipGap = 8;
  static const double _dragDeadZone = 8;

  int? _dragIndex;
  int? _dragSlot;
  double _dragDx = 0;
  double _lastFingerDx = 0;
  bool _dragMoved = false;
  List<double> _dragWidths = const <double>[];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revealSelected);
  }

  @override
  void didUpdateWidget(TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_revealSelected);
      widget.controller.addListener(_revealSelected);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revealSelected);
    _scrollController.dispose();
    super.dispose();
  }

  /// The selection changed (swipe or tab tap): after the frame
  /// the chip with the key is the new selected one, then the
  /// strip scrolls to it. alignment 0.5 = centered.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? chip = _selectedChipKey.currentContext;
      if (chip == null) return;
      Scrollable.ensureVisible(
        chip,
        duration: FusionMotion.normal,
        curve: FusionMotion.curve,
        alignment: 0.5,
      );
    });
  }

  /// The finger picked up the chip at [slot]: measure every chip
  /// (the swap thresholds need the real widths) and lift it.
  void _onDragStart(LongPressStartDetails details, int slot) {
    final int count = widget.controller.value.trackers.length;
    if (slot < 0 || slot >= count) {
      return;
    }
    _lastFingerDx = details.globalPosition.dx;
    setState(() {
      _dragIndex = slot;
      _dragSlot = slot;
      _dragDx = 0;
      _dragMoved = false;
      _dragWidths = <double>[
        for (int i = 0; i < count; i++)
          _chipKeys[i].currentContext?.size?.width ?? 0,
      ];
    });
  }

  void _onDragUpdate(LongPressMoveUpdateDetails details) {
    if (_dragSlot == null) {
      return;
    }
    final double delta = details.globalPosition.dx - _lastFingerDx;
    _lastFingerDx = details.globalPosition.dx;
    setState(() {
      _dragDx += delta;
      // Small jitter (or a vertical slip) must not turn the
      // pick-up into a move: the first 8 px are the dead zone.
      if (!_dragMoved && _dragDx.abs() >= _dragDeadZone) {
        _dragMoved = true;
      }
      if (_dragMoved) {
        _applySwaps();
      }
    });
  }

  /// While the finger moves, the dragged chip swaps slot with a
  /// neighbour as soon as its centre passes the neighbour centre
  /// (the ReorderableListView rule, on a horizontal strip). The
  /// dx correction keeps the clone exactly under the finger: the
  /// swap changes the slot base by the same amount.
  void _applySwaps() {
    if (_dragSlot == null || _dragWidths.length < 2) {
      return;
    }
    final double draggedW = _dragWidths[_dragSlot!];
    bool swapped = true;
    while (swapped) {
      swapped = false;
      final int slot = _dragSlot!;
      if (slot + 1 < _dragWidths.length &&
          _dragDx > (draggedW + _dragWidths[slot + 1]) / 2 + _chipGap) {
        _dragDx -= _dragWidths[slot + 1] + _chipGap;
        _swapDragWidths(slot, slot + 1);
        swapped = true;
      } else if (slot > 0 &&
          -_dragDx > (draggedW + _dragWidths[slot - 1]) / 2 + _chipGap) {
        _dragDx += _dragWidths[slot - 1] + _chipGap;
        _swapDragWidths(slot, slot - 1);
        swapped = true;
      }
    }
  }

  void _swapDragWidths(int from, int to) {
    final double w = _dragWidths.removeAt(from);
    _dragWidths.insert(to, w);
    _dragSlot = to;
  }

  void _onDragEnd(LongPressEndDetails details) {
    _finishDrag(openEditorWhenStill: true);
  }

  void _onDragCancel() {
    _finishDrag(openEditorWhenStill: false);
  }

  /// Drop: when the chip actually moved, commit the new slot;
  /// when the finger never left the spot, this is the old
  /// long-press = open the editor.
  void _finishDrag({required bool openEditorWhenStill}) {
    final int? from = _dragIndex;
    final int? to = _dragSlot;
    final bool moved = _dragMoved;
    final List<Tracker> trackers = widget.controller.value.trackers;
    final Tracker? tracker =
        from != null && from < trackers.length ? trackers[from] : null;
    setState(() {
      _dragIndex = null;
      _dragSlot = null;
      _dragMoved = false;
      _dragDx = 0;
      _dragWidths = const <double>[];
    });
    if (from == null || to == null) {
      return;
    }
    if (moved) {
      widget.controller.moveTracker(from, to);
    } else if (openEditorWhenStill && tracker != null) {
      widget.onEditTimer?.call(tracker);
    }
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

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: ValueListenableBuilder<AppState>(
              valueListenable: widget.controller,
              builder: (context, state, _) => _buildStrip(
                state,
                ext: ext,
                secondary: secondary,
              ),
            ),
          ),
        ),
        if (widget.onBackupTap != null) ...[
          const SizedBox(width: 8),
          _BackupChip(
            connected: widget.isBackupConnected,
            onTap: widget.onBackupTap!,
          ),
        ],
        if (widget.onToggleTheme != null && widget.isDarkMode != null) ...[
          const SizedBox(width: 8),
          _ThemeToggle(
            isDarkMode: widget.isDarkMode!,
            onTap: widget.onToggleTheme!,
          ),
        ],
      ],
    );
  }

  Widget _buildStrip(
    AppState state, {
    required FusionThemeExtension ext,
    required Color secondary,
  }) {
    final int count = state.trackers.length;
    while (_chipKeys.length < count) {
      _chipKeys.add(GlobalKey());
    }
    if (_chipKeys.length > count) {
      _chipKeys.removeRange(count, _chipKeys.length);
    }

    final int selected =
        count == 0 ? 0 : state.selectedIndex.clamp(0, count - 1);
    final String selectedId = count > 0 ? state.trackers[selected].id : '';

    final int? dragSlot = _dragSlot;
    final int? dragFrom = _dragIndex;
    final bool dragging = dragSlot != null && dragFrom != null;

    // Live swap: the strip shows the permutation, with the
    // dragged chip in its current slot.
    final List<Tracker> chips = <Tracker>[...state.trackers];
    if (dragging && dragSlot != dragFrom) {
      final Tracker moved = chips.removeAt(dragFrom);
      chips.insert(dragSlot, moved);
    }

    Widget buildChip(int slot, Tracker chip, {required bool clone}) {
      return _TabChip(
        key: !clone && chip.id == selectedId ? _selectedChipKey : null,
        tracker: chip,
        selected: chip.id == selectedId,
        lifted: dragging && slot == dragSlot,
        activeColor: ext.stateActive,
        activeTint: ext.stateActiveTint,
        inactiveColor: secondary,
        inactiveBackground: ext.surfaceVariant,
        onTap: () => widget.controller.select(slot),
      );
    }

    final Widget row = Row(
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: _chipGap),
          KeyedSubtree(
            key: _chipKeys[i],
            child: GestureDetector(
              onLongPressStart: (LongPressStartDetails details) =>
                  _onDragStart(details, i),
              onLongPressMoveUpdate: _onDragUpdate,
              onLongPressEnd: _onDragEnd,
              onLongPressCancel: _onDragCancel,
              child: IgnorePointer(
                // No taps while a chip is being dragged around.
                // The active drag gesture keeps its route:
                // IgnorePointer only affects new pointers.
                ignoring: dragging,
                child: Opacity(
                  // The floating clone replaces the in-row chip:
                  // the slot keeps its layout, the paint order is
                  // right (a Row child never paints above its
                  // later siblings) and the long-press gesture
                  // stays attached to this very element.
                  opacity: dragging && i == dragSlot ? 0.0 : 1.0,
                  child: buildChip(i, chips[i], clone: false),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: _chipGap),
        _AddChip(color: secondary, onTap: widget.onNewTimer),
      ],
    );

    if (!dragging) {
      return row;
    }

    // Where exactly under the finger: the base of the current
    // slot plus the finger offset.
    double base = 0;
    for (int i = 0; i < dragSlot; i++) {
      base += _dragWidths[i] + _chipGap;
    }

    return Stack(
      children: <Widget>[
        row,
        Positioned(
          left: base + _dragDx,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: Transform.scale(
                scale: 1.05,
                child: buildChip(dragSlot, chips[dragSlot], clone: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    super.key,
    required this.tracker,
    required this.selected,
    required this.lifted,
    required this.activeColor,
    required this.activeTint,
    required this.inactiveColor,
    required this.inactiveBackground,
    required this.onTap,
  });

  final Tracker tracker;
  final bool selected;

  /// True while the chip is dragged around: a small elevation
  /// and the scale in the bar make the pick-up visible.
  final bool lifted;
  final Color activeColor;
  final Color activeTint;
  final Color inactiveColor;
  final Color inactiveBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? activeColor : inactiveColor;

    // No icon: the chip falls back to the name, or to a generic
    // "Timer" label when both are missing (never an empty chip).
    final TimerGlyphId? glyph = tracker.glyph;
    final String? label = tracker.name ?? (glyph == null ? 'Timer' : null);

    return Material(
      color: selected ? activeTint : inactiveBackground,
      elevation: lifted ? 6 : 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) TimerGlyph(id: glyph, size: 18, color: fg),
              if (label != null) ...[
                if (glyph != null) const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "+" tab: dashed outline, opens the editor (mockup v0.3.4).
class _AddChip extends StatelessWidget {
  const _AddChip({required this.color, this.onTap});

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DashedRoundedRectPainter(
        color: color.withValues(alpha: 0.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.add_rounded, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

/// The cloud chip (step 5): opens the backup sheet. Same chip
/// style as the theme toggle; the active color (stateActive,
/// as the selected tabs) marks the signed-in state.
class _BackupChip extends StatelessWidget {
  const _BackupChip({required this.connected, required this.onTap});

  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: ext.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            Icons.cloud_outlined,
            size: 20,
            color: connected ? ext.stateActive : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDarkMode, required this.onTap});

  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FusionThemeExtension>()!;

    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: ext.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
