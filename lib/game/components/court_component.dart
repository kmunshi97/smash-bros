import 'package:flame/components.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/game/badminton_game.dart';

/// Static scenery component that loads and renders the background assets.
///
/// Under the hood, this loads:
///  * `stadium_bg.png` as the background layer (walls, crowd, scoreboard, lights)
///  * `stadium_floor.png` as the badminton court floor (green court and lines)
///
/// Added to the world container at priority = -2 (Background) and -1 (Floor)
/// so that players and the shuttlecock naturally render in front of them.
class CourtComponent extends Component with HasGameReference<BadmintonGame> {
  /// Renders background layers at priority -2 (placed at back of parent world).
  CourtComponent() : super(priority: -2);

  late final SpriteComponent _background;
  late final SpriteComponent _floor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final bgSprite = await game.loadSprite('stadium_bg.png');
    _background = SpriteComponent(
      sprite: bgSprite,
      size: Vector2(kCourtWidth, kCourtHeight),
      priority: 0,
    );
    await add(_background);

    final floorSprite = await game.loadSprite('stadium_floor.png');
    _floor = SpriteComponent(
      sprite: floorSprite,
      size: Vector2(kCourtWidth, kCourtHeight),
      priority: 1,
    );
    await add(_floor);

    // Add NetComponent directly to parent (the world) so it can render at
    // priority = 10, overlaying the players and the shuttlecock.
    final net = NetComponent();
    await parent?.add(net);
  }
}

/// Foreground overlay component that renders the net and posts on top of
/// characters and the playfield.
class NetComponent extends SpriteComponent
    with HasGameReference<BadmintonGame> {
  /// Render at a high priority (10) to draw in front of players (priority 0/default)
  /// and the shuttlecock (priority 0/default).
  NetComponent() : super(priority: 10);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await game.loadSprite('stadium_net.png');
    size = Vector2(kCourtWidth, kCourtHeight);
  }
}
