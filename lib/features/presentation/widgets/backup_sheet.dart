import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/feedback/fusion_dialog.dart';
import '../../../core/theme/fusion_theme_extension.dart';
import '../../../core/theme/fusion_tokens_scope.dart';
import '../../data/remote/remote_backup.dart';
import '../../models/tracker.dart';
import '../state/tracker_controller.dart';

const List<String> _months = <String>[
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

/// "Oct 28, 2026 · 14:32" — the editor / celebration format.
String _formatBackupDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year} · '
    '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

String _twoDigits(int n) => n < 10 ? '0$n' : '$n';

/// Backup sheet (step 5): Google Drive backup state and actions,
/// opened from the cloud chip in the top bar.
///
/// Two states, as in the approved mockup:
/// - not connected: one primary "Back up to Google Drive" button
///   (the OAuth flow must start with the user's tap);
/// - connected: account row, last backup data, "Back up now",
///   "Restore from Drive" (destructive confirm) and "Sign out".
///
/// Sign-in never uploads by itself: on a new phone the user
/// signs in to restore, and an automatic push of the still
/// empty local state would erase the good backup before the
/// restore (last write wins). The "Back up to Google Drive"
/// button uploads right after the sign-in only when there is
/// something local to upload.
Future<void> showBackupSheet(
  BuildContext context, {
  required TrackerController controller,
  required TrackerBackupService backup,
  required VoidCallback onBackedUp,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (context) => _BackupSheetDialog(
      controller: controller,
      backup: backup,
      onBackedUp: onBackedUp,
    ),
  );
}

/// Full-screen scrim (FusionDialog recipe: backdrop blur +
/// ext.scrim) with the centered sheet on top. A tap on the scrim
/// closes the sheet, a tap on the sheet does not.
class _BackupSheetDialog extends StatelessWidget {
  const _BackupSheetDialog({
    required this.controller,
    required this.backup,
    required this.onBackedUp,
  });

  final TrackerController controller;
  final TrackerBackupService backup;
  final VoidCallback onBackedUp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FusionThemeExtension ext = theme.extension<FusionThemeExtension>()!;
    final tokens = FusionTokensScope.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color secondary = tokens.color(
      isDark ? 'semantic.dark.textSecondary' : 'semantic.light.textSecondary',
    );
    final double blur =
        tokens.dimension('component.dialog.scrimBlur').toDouble();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox.expand(
          child: Container(
            color: ext.scrim,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: GestureDetector(
              // Claims the taps on the sheet so the scrim pop
              // above never fires from inside it.
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedBuilder(
                animation: backup,
                builder: (context, _) => _BackupSheet(
                  controller: controller,
                  backup: backup,
                  onBackedUp: onBackedUp,
                  isDark: isDark,
                  secondary: secondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupSheet extends StatelessWidget {
  const _BackupSheet({
    required this.controller,
    required this.backup,
    required this.onBackedUp,
    required this.isDark,
    required this.secondary,
  });

  final TrackerController controller;
  final TrackerBackupService backup;
  final VoidCallback onBackedUp;
  final bool isDark;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FusionThemeExtension ext = theme.extension<FusionThemeExtension>()!;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
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
        child: backup.isSignedIn
            ? _connectedContent(context, theme, ext)
            : _signedOutContent(context, theme),
      ),
    );
  }

  Widget _title(ThemeData theme) => Text(
        'Google Drive backup',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      );

  Widget _signedOutContent(BuildContext context, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _title(theme),
        const SizedBox(height: 10),
        Text(
          'Back up your timers to a private folder in your Google'
          ' Drive and restore them on any device.\n\nBackups run'
          ' automatically once you sign in.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: secondary,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: backup.isBusy ? null : () => _signInAndBackup(context),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: backup.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Back up to Google Drive',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(38),
            foregroundColor: secondary,
          ),
          child: const Text(
            'Not now',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _connectedContent(
    BuildContext context,
    ThemeData theme,
    FusionThemeExtension ext,
  ) {
    final String? email = backup.accountEmail;
    final DateTime? lastAt = backup.lastBackupAt;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _title(theme),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ext.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
                alignment: Alignment.center,
                child: Text(
                  (email == null || email.isEmpty)
                      ? '?'
                      : email[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      email ?? 'Google account',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connected · auto-backup on',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: ext.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoLine(
          label: 'Last backup',
          value: lastAt == null ? 'Never' : _formatBackupDate(lastAt),
          mono: lastAt != null,
          secondary: secondary,
        ),
        const SizedBox(height: 4),
        _InfoLine(
          label: 'Stored timers',
          value: '${backup.storedTrackerCount}',
          mono: true,
          secondary: secondary,
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: backup.isBusy ? null : () => _backupNow(context),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: backup.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Back up now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: backup.isBusy ? null : () => _restore(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(42),
            side: BorderSide(color: secondary.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Restore from Drive',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: backup.isBusy ? null : _signOut,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(38),
            foregroundColor: secondary,
          ),
          child: const Text(
            'Sign out',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _signInAndBackup(BuildContext context) async {
    bool signedIn;
    try {
      signedIn = await backup.signIn();
    } on DriveBackupException catch (error) {
      if (context.mounted) {
        await FusionDialog.show(
          context,
          title: 'Sign-in failed',
          message: error.message,
        );
      }
      return;
    }
    // False = the user closed the account picker: no error.
    if (!signedIn || !context.mounted) {
      return;
    }
    // The primary button promised a backup: when there is
    // something local to upload, do it right away and close.
    // With no local timers the sheet stays open instead: that is
    // the restore-on-a-new-device path, and an empty push would
    // erase the good backup before the restore.
    if (controller.value.trackers.isEmpty) {
      return;
    }
    await _backupNow(context);
  }

  Future<void> _backupNow(BuildContext context) async {
    final int localCount = controller.value.trackers.length;
    // Safety rail: an empty backup would silently erase a good
    // one (last write wins). Only a conscious confirm allows it.
    if (localCount == 0 && backup.storedTrackerCount > 0) {
      final bool confirmed = await FusionDialog.confirm(
        context,
        title: 'Replace the Drive backup?',
        message: 'There are no timers on this device. Uploading now'
            ' replaces the ${backup.storedTrackerCount} timers stored'
            ' on Drive.',
        confirmLabel: 'Replace',
        isDestructive: true,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }
    final bool ok = await backup.pushSnapshot(controller.value.trackers);
    if (!context.mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop();
      onBackedUp();
    } else {
      await FusionDialog.show(
        context,
        title: 'Backup failed',
        message: 'Check the connection and try again.',
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final int localCount = controller.value.trackers.length;
    final DateTime? lastAt = backup.lastBackupAt;
    final String lastLine = lastAt == null
        ? 'Drive has no backup yet.'
        : 'Last backup: ${_formatBackupDate(lastAt)}';
    final bool confirmed = await FusionDialog.confirm(
      context,
      title: 'Restore from Drive?',
      message: 'The backup on Drive will replace the $localCount'
          ' ${localCount == 1 ? 'timer' : 'timers'} on this device.'
          '\nThis cannot be undone.\n\n$lastLine',
      confirmLabel: 'Restore',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final List<Tracker>? restored = await backup.pullSnapshot();
      if (!context.mounted) {
        return;
      }
      if (restored == null || restored.isEmpty) {
        await FusionDialog.show(
          context,
          title: 'Nothing to restore',
          message: 'The backup on Drive is empty.',
        );
        return;
      }
      controller.replaceAll(restored);
      Navigator.of(context).pop();
    } on DriveBackupException catch (error) {
      if (context.mounted) {
        await FusionDialog.show(
          context,
          title: 'Restore failed',
          message: error.message,
        );
      }
    }
  }

  Future<void> _signOut() async {
    await backup.signOut();
    // The AnimatedBuilder rebuilds the sheet back to the
    // not-connected state on the service notification.
  }
}

/// "Last backup" / "Stored timers" row: values that are data
/// (dates, counts) render in JetBrains Mono, suite rule.
class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    required this.secondary,
    this.mono = false,
  });

  final String label;
  final String value;
  final Color secondary;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: secondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            fontFamily: mono ? 'JetBrains Mono' : null,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
