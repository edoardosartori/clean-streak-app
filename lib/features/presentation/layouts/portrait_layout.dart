import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Step 1 placeholder: static screen to verify project setup and the
/// light/dark theme built from fusion-tokens.json. The real UI arrives in
/// step 3 (PageView tabs, hero card, milestone card).
///
/// AnnotatedRegion keeps the system bars transparent: the global
/// SystemChrome call in main.dart alone gets reset by the framework at
/// startup. Same convention as the other apps of the suite.
class PortraitLayout extends StatelessWidget {
  const PortraitLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyleFor(theme.brightness),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Clean Streak', style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                _PlaceholderCard(theme: theme),
                const SizedBox(height: 16),
                Text(
                  'Step 1 — setup check: theme loaded from fusion-tokens.json',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Fusion card tokens: radius 16, border 1, padding 16.
    // Colors come from ThemeData (built from tokens), never hand-written.
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clean for', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text('00 Y · 00 M · 04 D', style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
