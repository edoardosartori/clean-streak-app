import 'package:flutter/material.dart';

import '../layouts/landscape_layout.dart';
import '../layouts/portrait_layout.dart';

/// Root page of the tracker feature. Picks the layout from the
/// orientation, same convention as the other apps of the suite.
class MainPage extends StatelessWidget {
  const MainPage({super.key, this.isDarkMode, this.onToggleTheme});

  /// Theme state owned by main.dart (as in pw-generator):
  /// pass both to show the theme toggle in the top bar.
  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape
        ? LandscapeLayout(isDarkMode: isDarkMode, onToggleTheme: onToggleTheme)
        : PortraitLayout(isDarkMode: isDarkMode, onToggleTheme: onToggleTheme);
  }
}
