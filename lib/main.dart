import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/fusion_tokens.dart';
import 'core/theme/fusion_tokens_scope.dart';
import 'core/theme/fusion_theme.dart';
import 'core/theme/token_loader.dart';

import 'features/data/local/hive_tracker_repository.dart';
import 'features/data/notifications/flutter_milestone_scheduler.dart';
import 'features/data/notifications/milestone_scheduler.dart';
import 'features/data/tracker_repository.dart';
import 'features/models/tracker.dart';
import 'features/presentation/pages/main_page.dart';

const String _appTitle = 'Clean Streak';
const String _themeModePreferenceKey = 'theme_mode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final FusionTokens tokens = await TokenLoader.load();
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  // Step 4: local persistence (Hive CE). The box is opened and
  // loaded before the first frame: the boot shows exactly what
  // was saved, no seed, no flash of empty content.
  await Hive.initFlutter();
  final Box<Map> trackerBox = await Hive.openBox<Map>(
    HiveTrackerRepository.boxName,
  );
  final TrackerRepository repository = HiveTrackerRepository(
    box: trackerBox,
  );
  final List<Tracker> savedTrackers = await repository.loadTrackers();

  // Step 4d: system milestone notifications. The plugin (timezone
  // database, local location) is initialized before the first
  // frame; if anything fails the app falls back to the noop
  // scheduler and everything else keeps working.
  MilestoneScheduler scheduler;
  try {
    scheduler = await FlutterMilestoneScheduler.create(
      preferences: preferences,
    );
  } catch (_) {
    scheduler = NoopMilestoneScheduler();
  }
  final String? launchTrackerId = await scheduler.launchTrackerId();

  runApp(
    App(
      tokens: tokens,
      preferences: preferences,
      repository: repository,
      initialTrackers: savedTrackers,
      scheduler: scheduler,
      initialSelectedTrackerId: launchTrackerId,
    ),
  );
}

class App extends StatefulWidget {
  const App({
    super.key,
    required this.tokens,
    required this.preferences,
    required this.repository,
    required this.initialTrackers,
    required this.scheduler,
    required this.initialSelectedTrackerId,
  });

  final FusionTokens tokens;
  final SharedPreferences preferences;
  final TrackerRepository repository;
  final List<Tracker> initialTrackers;

  /// Step 4d: system milestone notifications.
  final MilestoneScheduler scheduler;

  /// The card tapped in the notification that cold-started the
  /// app (null on a normal launch).
  final String? initialSelectedTrackerId;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = _loadThemeMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The controller saves fire-and-forget: on detach we make
    // sure the last writes reach the disk before the process dies.
    if (state == AppLifecycleState.detached) {
      unawaited(Hive.flush());
    }
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
    final Brightness iconBrightness =
        _isDarkMode ? Brightness.light : Brightness.dark;

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

    return FusionTokensScope(
      tokens: widget.tokens,
      child: MaterialApp(
        title: _appTitle,
        debugShowCheckedModeBanner: false,
        theme: FusionTheme.light(widget.tokens),
        darkTheme: FusionTheme.dark(widget.tokens),
        themeMode: _themeMode,
        home: MainPage(
          isDarkMode: _isDarkMode,
          onToggleTheme: toggleTheme,
          repository: widget.repository,
          initialTrackers: widget.initialTrackers,
          scheduler: widget.scheduler,
          initialSelectedTrackerId: widget.initialSelectedTrackerId,
        ),
      ),
    );
  }
}
