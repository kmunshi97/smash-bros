import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smash_bros/game/badminton_game.dart';
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
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcade Badminton',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: GameWidget(
        // Wall-clock seed is fine here — this is outside the engine; the
        // engine itself never calls dart:math directly (see CLAUDE.md).
        game: BadmintonGame(seed: DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
