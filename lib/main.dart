import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'core/theme/fusion_tokens.dart';
import 'core/theme/fusion_theme.dart';
import 'core/theme/token_loader.dart';

import 'features/clean_streak/presentation/pages/main_page.dart';

const String _appTitle = 'Clean Streak';
const String _themeModePreferenceKey = 'theme_mode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final FusionTokens tokens = await TokenLoader.load();
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  runApp(
    App(
      tokens: tokens,
      preferences: preferences,
      initialPage: const MainPage(),
    ),
  );
}

class App extends StatefulWidget {
  const App({
    super.key,
    required this.tokens,
    required this.preferences,
    required this.initialPage,
  });

  final FusionTokens tokens;
  final SharedPreferences preferences;
  final Widget initialPage;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = _loadThemeMode();
  }

  ThemeMode _loadThemeMode() {
    final String? savedThemeMode = widget.preferences.getString(
      _themeModePreferenceKey,
    );

    return switch (savedThemeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  bool get _isDarkMode {
    final Brightness platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    return _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
  }

  void toggleTheme() {
    final ThemeMode nextMode = _isDarkMode ? ThemeMode.light : ThemeMode.dark;

    setState(() {
      _themeMode = nextMode;
    });

    unawaited(_saveThemeMode(nextMode));
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final bool saved = await widget.preferences.setString(
      _themeModePreferenceKey,
      mode.name,
    );

    if (!saved) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('Could not save the selected theme mode.'),
          library: _appTitle,
        ),
      );
    }
  }

  void _updateSystemUiOverlay() {
    final Brightness iconBrightness = _isDarkMode
        ? Brightness.light
        : Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateSystemUiOverlay();

    return MaterialApp(
      title: _appTitle,
      debugShowCheckedModeBanner: false,
      theme: FusionTheme.light(widget.tokens),
      darkTheme: FusionTheme.dark(widget.tokens),
      themeMode: _themeMode,
      home: widget.initialPage,
    );
  }
}
