import 'package:flutter/material.dart';

import 'portrait_layout.dart';

/// Still a stub: the dedicated landscape layout arrives with the UI
/// refinement pass (same pattern as the other apps of the suite).
class LandscapeLayout extends StatelessWidget {
  const LandscapeLayout({super.key, this.isDarkMode, this.onToggleTheme});

  final bool? isDarkMode;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return PortraitLayout(
      isDarkMode: isDarkMode,
      onToggleTheme: onToggleTheme,
    );
  }
}
