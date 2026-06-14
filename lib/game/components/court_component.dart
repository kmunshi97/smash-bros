import 'package:flame/components.dart';
import 'package:smash_bros/game/arena/arena_theme.dart';
import 'package:smash_bros/game/badminton_game.dart';
import 'package:smash_bros/game/components/arena_court_component.dart';
import 'package:smash_bros/game/components/parallax_backdrop_component.dart';

export 'package:smash_bros/game/components/arena_court_component.dart'
    show NetComponent;

/// Scenery host (M2 court rework) — stacks the arena from swappable layers.
///
/// Layers, back to front:
///  * `stadium_bg.png` parallax backdrop (crowd / stands), drifting for depth;
///  * [ArenaCourtComponent] — the procedural textured floor + white court lines
///    drawn at exact dimensions;
///  * (players + shuttle render here, between this component and the net);
///  * [NetComponent] — the procedural net, added to the world above the players.
///
/// The court markings and net are code-drawn and fixed; only the [ArenaTheme]'s
/// **floor** changes between arenas, so swapping the theme re-skins everything.
class CourtComponent extends Component with HasGameReference<BadmintonGame> {
  /// Renders scenery at priority -2 (back of the world).
  CourtComponent({this.theme = ArenaTheme.indoorGreen}) : super(priority: -2);

  /// The arena theme applied to the floor, lines and net.
  final ArenaTheme theme;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Far backdrop (crowd/stands) — loads stadium_bg.png itself and parallaxes.
    await add(ParallaxBackdropComponent(priority: 0));

    // Procedural floor + court lines, over the backdrop and under the players.
    await add(ArenaCourtComponent(theme: theme, priority: 1));

    // Procedural net on the world at priority 10, over players and shuttle.
    await parent?.add(NetComponent(theme: theme));
  }
}
