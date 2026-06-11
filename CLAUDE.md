# smash_bros — Arcade Badminton (Flutter + Flame)

Landscape-only 2D badminton game. Pure-Dart simulation engine + Flame rendering; custom Go backend arrives in Milestone 3. Full plan: [docs/PLAN.md](docs/PLAN.md).

## Architecture rules

- **`lib/engine/` is pure Dart.** It must never import `package:flutter` or `package:flame`. The engine produces a `RenderState`; `lib/game/` (Flame) consumes it.
- **Determinism from day one**: all randomness flows through the seeded PRNG inside `GameState`. No `dart:math Random()` calls elsewhere in the engine, no wall-clock time in simulation logic.
- **Fixed timestep**: the simulation runs at exactly 60 ticks/sec via an accumulator. Never tie simulation stepping to display refresh (`Ticker` frequency varies: 60/90/120Hz).
- Engine math goes through the engine's scalar/vector abstraction (future Q16.16 fixed-point swap must stay mechanical).
- Gameplay numbers live in `BalanceConfig` (loaded from `assets/data/`), not hardcoded — feel-tuning must not require recompiles.

## Workflow

- **Phase = branch = PR.** Each plan task block lands as one reviewable PR (~200–500 lines) pushed to GitHub before the next block starts. The owner code-reviews every PR — write PR descriptions for a reviewer following along: what to look at, design decisions taken, how to verify manually.
- Conventional commits referencing plan task IDs: `feat(engine): M1-005 swept collision`.
- Tests land in the same PR as the code they cover. Engine coverage target: ≥95%.
- Model-tier delegation: tasks in docs/PLAN.md are tagged `[H]` Haiku / `[S]` Sonnet / `[O]` Opus / `[F]` Fable — when delegating to subagents, use the tagged tier; Fable reviews `[O]`-tagged and all money/security paths.

## Code style

- `very_good_analysis` strict lints; lefthook runs format / `flutter analyze --fatal-infos` / tests pre-commit. Don't bypass hooks.
- Dartdoc `///` on every public class/method in `lib/engine/`. Each engine system gets a header comment stating its contract and its position in the simulation tick order.
- No popups in UI flows — full-screen transitions only (design rule from the plan).

## Commands

- `flutter test` — all tests; `flutter test test/engine` — fast headless engine tests
- `flutter analyze --fatal-infos` — must pass clean
- `flutter run -d macos` — desktop dev target for fast feel-tuning with keyboard (shipping targets are Android/iOS only; Android first)
