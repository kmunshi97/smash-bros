import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smash_bros/engine/entities/tunables.dart';
import 'package:smash_bros/game/balance_loader.dart';
import 'package:smash_bros/ui/screens/home_screen.dart';
import 'package:smash_bros/ui/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape-only (ADR-3): the native configs (Info.plist, AndroidManifest)
  // enforce this at the OS level; this call covers desktop dev targets and
  // any platform where the native config is not consulted.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Android immersive-sticky full-screen mode (M1-025). Hides status bar and
  // navigation bar; they reappear on swipe and auto-hide again. Harmless on
  // iOS and macOS dev targets.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // M1-032: load feel-tuning config from assets before any simulation is
  // built, so the first match already uses the tuned values. Falls back to
  // BalanceConfig.defaults() on any error (see BalanceLoader).
  Tunables.apply(await BalanceLoader.load());
  runApp(const MainApp());
}

/// The app root: a [MaterialApp] whose home is the title screen (M2-2C). The
/// screen flow is Home → Mode Select → Game, all full-screen routes.
class MainApp extends StatelessWidget {
  /// Creates the app root.
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcade Badminton',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
