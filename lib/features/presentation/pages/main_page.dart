import 'package:flutter/material.dart';

import '../../data/tracker_repository.dart';
import '../../models/tracker.dart';
import '../layouts/landscape_layout.dart';
import '../layouts/portrait_layout.dart';

/// Root page of the tracker feature. Picks the layout from the
/// orientation, same convention as the other apps of the suite.
class MainPage extends StatelessWidget {
  const MainPage({
    super.key,
    this.isDarkMode,
    this.onToggleTheme,
    this.repository,
    this.initialTrackers = const <Tracker>[],
  });

  /// Theme state owned by main.dart (as in pw-generator):
  /// pass both to show the theme toggle in the top bar.
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  /// local persistence handed down from main.dart. Only
  /// the portrait layout uses it — landscape stays dead code
  /// under the portrait lock, unchanged by design.
  final TrackerRepository? repository;
  final List<Tracker> initialTrackers;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape
        ? LandscapeLayout(isDarkMode: isDarkMode, onToggleTheme: onToggleTheme)
        : PortraitLayout(
            isDarkMode: isDarkMode,
            onToggleTheme: onToggleTheme,
            repository: repository,
            initialTrackers: initialTrackers,
          );
  }
}
