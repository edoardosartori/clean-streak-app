import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transparent system bars; icon brightness follows the theme.
SystemUiOverlayStyle systemOverlayStyleFor(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  );
}

class PortraitLayout extends StatelessWidget {
  const PortraitLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final SystemUiOverlayStyle overlayStyle =
        systemOverlayStyleFor(Theme.of(context).brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Minimal App'),
          // The AppBar applies its own overlay style, so give it ours.
          systemOverlayStyle: overlayStyle,
        ),
        body: const SafeArea(
          top: false, // the AppBar already covers the status bar
          child: Center(
            child: Text(
              'Hello, Flutter!',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
