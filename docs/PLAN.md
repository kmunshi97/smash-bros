---
name: Refined Badminton Plan v3
overview: Execution plan for a landscape-only 2D Arcade Badminton game (Flutter + Flame, custom Go backend). v3 adds ~40 critique findings (engine edge cases, platform hygiene, netcode security, store compliance), early monetization behind feature flags, Android-first release, a PR-per-phase review workflow, and a model-tier tag ([H]/[S]/[O]/[F]) on every task for cost-optimized agent delegation.
todos:
  - id: milestone-1-setup
    content: "Milestone 1 Setup: Scaffold -- CI workflow, pre-commit hooks, analysis_options, asset pipeline convention (DONE in repo)"
    status: completed
  - id: milestone-1-platform
    content: "Milestone 1 Platform Hygiene [S]: landscape lock (iOS plist + Android manifest + SystemChrome), app lifecycle auto-pause, git/GitHub + CLAUDE.md conventions"
    status: pending
  - id: milestone-1a
    content: "Milestone 1A: Engine Core -- [F] fixed-timestep accumulator + tick order + math abstraction + seeded PRNG + perfect-block redefinition; [O] shuttle physics, swept collision, ShotSystem, FSM + serve rules; [S] Player, InputBuffer/Validator, Stamina, Stun, Scoring (incl. golden point), rules gaps (double-hit, behind-player contact, net-cord, stuck shuttle), BalanceConfig + tuning overlay, unit tests. DONE: all systems implemented, M1-032 BalanceConfig + debug tuning overlay landed; engine coverage 95%."
    status: completed
  - id: milestone-1b
    content: "Milestone 1B: Flame Rendering [S] -- BadmintonGame shell (1280x720 letterboxed), RenderState, Court/Player/Shuttle components, touch controls + safe-area/notch + multi-touch, basic HUD"
    status: completed
  - id: milestone-1c
    content: "Milestone 1C: Basic AI + Integration [S] -- AIController interface (deterministic, private AI PRNG for rollback-stream safety), BasicAI, playable match vs AI"
    status: completed
  - id: milestone-2a
    content: "Milestone 2A: Visual Polish [S] -- sprite animations, parallax, camera + screen shake, particles, animation state machine, haptics"
    status: pending
  - id: milestone-2b
    content: "Milestone 2B: Audio -- [O] latency spike (flame_audio vs flutter_soloud) FIRST; [S] AudioBloc (frame-ID events), SFX/music, iOS audio session, volume/mute"
    status: pending
  - id: milestone-2c
    content: "Milestone 2C: Bloc + Screens [S] -- MatchBloc (frame-ID events + confirmed-frame watermark), InputBloc, UIBloc, SimulationBridge (accumulator), screens, pause flow, Android back button, prefs schema versioning, widget + integration tests"
    status: pending
  - id: milestone-2d
    content: "Milestone 2D: AI + Modes -- [S] GameMode interface (timer-expiry semantics), ClassicMode, PointRushMode, IntermediateAI, difficulty config, validation sims; [O] HardAI"
    status: pending
  - id: milestone-2e
    content: "Milestone 2E: Tutorial [S] -- TutorialMode (6 steps, serve timer suppressed), overlay, completion tracking, integration test"
    status: pending
  - id: milestone-2f
    content: "Milestone 2F: Feature Flags + Monetization-lite + Release (Android-first) -- [S] feature-flag foundation (local JSON + remote override; toggles ads/modes/IAP/tutorial), AdMob behind flags, Remove-Ads IAP, consent + Play Data Safety + privacy policy; [H+S] signing, Play internal track, store listing, versioning"
    status: pending
  - id: milestone-3-setup
    content: "Milestone 3 Setup: Foundations -- [H] ADR docs, migration convention + CI check, wire protocol doc; [S] Go CI jobs, Docker Compose. Can start in parallel during late M2 (Go learning track)"
    status: pending
  - id: milestone-3-preq
    content: "Milestone 3 Pre-Work: Fixed-Point Retrofit -- [F] Q16.16 + trig (LUT/CORDIC) design; [O] FixedPoint/FPVector2D + mechanical retrofit (eased by M1 math abstraction); [S] determinism tests (x86+ARM), binary serialization + CRC32, snapshot ring buffer, rollback/fast-forward, ReplayRecorder, perf benchmark"
    status: pending
  - id: milestone-3a
    content: "Milestone 3A: Go UDP Relay -- [S] scaffold (chi/slog/healthz), DB (pgx+sqlc), Redis, middleware, API versioning; [F] wire protocol + UDP session-token auth design; [O] UDP listener, packet relay, heartbeat, session lifecycle, input-rate validation; [S] version mismatch, load test (1k sessions + pprof)"
    status: pending
  - id: milestone-3b
    content: "Milestone 3B: Flutter Netcode -- [F] transport-neutral interface + UDP reachability probe design; [O] NetworkInputBuffer, PredictionSystem, RollbackManager, match-start sync handshake; [S] visual smoothing, input-delay auto-tuning"
    status: pending
  - id: milestone-3c
    content: "Milestone 3C: Lag Compensation -- [F] stun resolution (ADR-5) + desync rules; [O] frame sync, desync detection, reconnect flow, jitter buffer; [S] iOS background sockets, integration tests (latency/loss/disconnect/desync)"
    status: pending
  - id: milestone-3d-auth
    content: "Milestone 3D Auth [S] -- users table, guest auth (reinstall-surviving identity + link prompt), register/login, JWT + rotation, middleware, OAuth2 (Google, Apple), account deletion endpoint + UI, tests"
    status: pending
  - id: milestone-3d-matchmaking
    content: "Milestone 3D Matchmaking -- [S] private/friend match codes FIRST, queue-empty UX + bot backfill, profiles table, ELO queue, match creation, cancel; [O] ELO updates + dual-report reconciliation; [S] RTT gate (replaces region field), tests"
    status: pending
  - id: milestone-3d-economy
    content: "Milestone 3D Economy [S] -- wallets/transactions/xp_log tables, XP calc + anomaly rate-limiting, post-match results, store catalog + idempotent purchases, daily rewards, scheduled-jobs worker (seasons/streaks), tests"
    status: pending
  - id: milestone-3d-loadouts
    content: "Milestone 3D Loadouts -- [S] Character/Racquet models, StatCalculator (24 combos, clamped), backend tables + CRUD, LoadoutBloc + UI, balance test harness; [O] server-authoritative validation, balance patch snapshotting; tests"
    status: pending
  - id: milestone-3d-competitive
    content: "Milestone 3D Competitive -- [S] CompetitiveMode (ranked ELO, seasonal reset via jobs worker); [O] Point Rush statistical anomaly detection (replaces cut server re-simulation M3-077)"
    status: pending
  - id: milestone-3e
    content: "Milestone 3E: Monetization -- [O] IAP receipt validation + refund webhooks (Fable review); [S] Pro Pass backend + mid-match expiry snapshot, Restore Purchases + manage-subscription deep link + grace periods, daily rewards UI, store UI, notification banners, HTTP min-version gate, IAP integration tests"
    status: pending
  - id: milestone-3f
    content: "Milestone 3F: Analytics & Ops -- [S] match telemetry, heatmaps, Prometheus metrics, structured logging, Crashlytics, feature-flag service (replaces M2 static source, same client API); [S/H] Grafana dashboards, admin CLI + audit log"
    status: pending
  - id: milestone-3g
    content: "Milestone 3G: Deployment & Ops (NEW; replaces 10k-scale work) -- [S] VPS/Fly.io provisioning, Dockerized deploy pipeline from CI, secrets management; [H] TLS (Caddy/Lets Encrypt) + DNS, Postgres backups + restore drill, cost budget (~$10-25/mo)"
    status: pending
isProject: false
---

# 2D Arcade Badminton -- Execution Plan v3

---

## What Changed in v3 (from v2)

- **Repo reality**: Milestone 1 Setup is DONE (CI, lefthook, strict lints, asset dirs, `lib/engine/constants.dart`, UI theme). Flame is pinned `^1.35.1` in pubspec (v2 said 1.36 — bump deliberately or stay; don't let docs drift).
- **Model-tier delegation**: every task tagged `[H]/[S]/[O]/[F]` for cost-optimized subagent delegation (see below).
- **Code quality & review workflow**: PR-per-phase delivery, documented code, conventions in `CLAUDE.md` (see below).
- **~40 critique findings folded in**: engine correctness (tunneling, tick rate, determinism seeds), platform hygiene (landscape lock was missing!), netcode security (unauthenticated UDP), store compliance (account deletion, restore purchases, consent).
- **Early monetization (Milestone 2F)**: ads + Remove-Ads IAP at offline launch, all behind a feature-flag config (user decision).
- **Android-first** release strategy (user decision).
- **Custom Go backend kept** — explicit goal is learning Go for backend roles. Right-sized: cut the 10k-session scale vanity work and the M3-077 server re-simulation (hidden Go engine port); **added Milestone 3G Deployment & Ops** — operating a deployed service is the most job-relevant backend skill in this plan.
- **Cut**: M3-077 (Point Rush server re-simulation) — it contradicted ADR-5 (relay does NO game logic) and silently required porting the entire deterministic Dart engine to Go. Replaced with statistical anomaly detection.

---

## Code Quality & Review Workflow

These working agreements apply to every task and every subagent:

- **Phase = branch = PR.** Each task block (e.g. "M1-A physics + collision") lands as one reviewable PR (~200-500 lines) on a feature branch, pushed to [github.com/kmunshi97/smash-bros](https://github.com/kmunshi97/smash-bros) for review before the next block starts. Task IDs map to conventional commits: `feat(engine): M1-005 swept collision`.
- **Documented code.** Dartdoc `///` on every public class/method in `lib/engine/` (re-enable `public_member_api_docs` for the engine via a nested `lib/engine/analysis_options.yaml`). Every system gets a header comment stating its contract and position in the tick order. `docs/architecture.md` kept current per milestone.
- **Enforced practices.** `very_good_analysis` strict lints + lefthook (format / analyze --fatal-infos / tests) gate every commit. Engine stays pure Dart — add a CI grep check that nothing in `lib/engine/` imports `package:flutter` or `package:flame`. Tests land in the same PR as the code. Coverage >= 95% on `lib/engine/`.
- **Review aids.** Every PR description: what to look at, design decisions taken, how to verify manually — written for a reviewer following along.
- Conventions live in `CLAUDE.md` so every future session and subagent inherits them.

---

## Model-Tier Delegation (Cost Optimization)

Pricing per MTok (input/output): **Haiku 4.5** $1/$5 · **Sonnet 4.6** $3/$15 · **Opus 4.8** $5/$25 · **Fable 5** $10/$50.

> Note: Opus is the **second most expensive** tier, not a cheap one. The workhorse savings come from Sonnet (~55% of tasks) and Haiku.

Every task below carries a tag:

| Tag | Model | Use for |
|---|---|---|
| `[H]` | Haiku 4.5 | Boilerplate, docs, config, migrations, test fixtures, store copy, repetitive mechanical work |
| `[S]` | Sonnet 4.6 | Standard well-specified implementation + tests: most engine systems, all Flame components, Blocs/screens, Go CRUD endpoints, dashboards |
| `[O]` | Opus 4.8 | Complex algorithmic subsystems with subtle failure modes: physics/collision, FSM + serve rules, HardAI, fixed-point retrofit, rollback/prediction, UDP relay internals, IAP validation |
| `[F]` | Fable 5 | Architecture & design decisions, determinism design, security review, desync debugging — anything where a wrong call is expensive to discover late |

**Working pattern**: drive sessions with Fable as the main loop; delegate explicitly ("implement M1-011 with a sonnet subagent"). Fable reviews diffs on `[O]`-tagged and all money/security paths. Expected cost mix: ~15% Haiku, ~55% Sonnet, ~20% Opus, ~10% Fable.

---

## Architectural Decisions

- **ADR-1: Fixed-Point Arithmetic** -- DEFERRED to Milestone 3, **but** M1 introduces the math abstraction layer (engine scalar/vector wrapper over `double`) so the Q16.16 swap is mechanical, not a re-tune of game feel. Fixed-point **trig** (LUT/CORDIC) is part of ADR-1 — `dart:math` sin/cos are not bit-identical across architectures.
- **ADR-2: Semi-Implicit Euler** -- ACTIVE from Milestone 1, with **swept collision** for the shuttle (it moves up to 20 units/tick; discrete AABB tunnels through the net).
- **ADR-3: Mobile-only SHIPPING targets** -- amended: desktop (macOS runner already in repo) is a blessed **dev target** for fast feel-tuning with keyboard input. `RawDatagramSocket` for UDP on mobile.
- **ADR-4: Offline Mode** -- ACTIVE from Milestone 1. Offline modes are never version-gated.
- **ADR-5: Stun Arbitration (attacker wins); relay does NO game logic** -- DEFERRED to Milestone 3. Consequence enforced in v3: M3-077 (server re-simulation) is CUT — it violated this ADR.
- **ADR-6: Wire Protocol Versioning** -- DEFERRED to Milestone 3. Extended: protocol includes **session-token authentication** (see M3-017a).
- **ADR-7 (new): Fixed-timestep accumulator** -- simulation runs at exactly 60 ticks/sec decoupled from display refresh (120Hz devices would otherwise simulate at 2x via `Ticker`). Renderer may interpolate between ticks.
- **ADR-8 (new): Determinism from day one** -- seeded PRNG lives inside `GameState`; all randomness (shot-angle ranges, AI decisions) flows through it. Frame-ID'd gameplay events with a confirmed-frame watermark so rollback never double-fires SFX/VFX.

---

## Project Structure

(unchanged from v2 — see `lib/engine`, `lib/game`, `lib/ai`, `lib/bloc`, `lib/netcode`, `lib/ui`, `lib/audio`, `lib/models`, `server/`. Already partially realized in repo.)

**Key rule**: Nothing in `lib/engine/` imports `package:flutter` or `package:flame` (CI-enforced from M1).

---

## Gameplay Design Constants

Already implemented in [lib/engine/constants.dart](lib/engine/constants.dart) (court 1280x720, net x=640, gravity 0.15, drag 0.003, smash speed 16/clamp 20, timing windows, stamina table, deuce cap 15). v3 changes:

- Constants migrate to a **`BalanceConfig`** loaded from `assets/data/balance.json` with a debug tuning overlay (M1-032) — feel-tuning must not require recompiles.
- **Side switching after each point**: demoted from rule to tuning decision, default OFF (constantly inverting left/right in a side-view game is hostile; real badminton switches per game).
- **Perfect-block window**: "frames 6-12 before shuttle reaches player" is not directly computable under quadratic drag (no closed-form time-of-arrival) — redefined in M1-035.

---

## Milestone 1 -- Playable MVP (6-8 weeks)

**Goal**: a fun, full match vs basic AI with colored rectangles. **Gate**: do not start 1B polish until the rally "feels fun" with the tuning overlay.

### 1-Setup -- DONE (in repo)

- ~~M1-S01..S04~~ analysis_options (very_good_analysis), CI workflow (`badminton_ci.yml`), lefthook, asset pipeline dirs — all present.

### 1-Platform -- Platform Hygiene (NEW)

- **M1-S05** `[S]`: Landscape lock — iOS `Info.plist` orientations (currently still portrait!), Android `android:screenOrientation="sensorLandscape"`, `SystemChrome.setPreferredOrientations` in `main()`.
- **M1-S06** `[S]`: App lifecycle — auto-pause simulation + audio on `AppLifecycleState.paused`; serve timer must freeze (engine-frame-based, not wall-clock).
- **M1-S07** `[H]`: CI grep check: `lib/engine/` imports no Flutter/Flame; nested `analysis_options.yaml` re-enabling `public_member_api_docs` for engine.

### 1A -- Engine Core

Design-first tasks (do these before implementation fan-out):

- **M1-030** `[F]`: Fixed-timestep accumulator (ADR-7) — `Simulation.advance(elapsed)` accumulates and steps in exact 1/60s ticks; document render-interpolation hook.
- **M1-031** `[F]`: Engine math abstraction (ADR-1 prep) — `Fix`/`FixVec2` wrapper types (doubles inside for now), all engine math goes through them; trig via a table-driven API so the M3 fixed-point swap is mechanical.
- **M1-034** `[F]`: Seeded PRNG inside `GameState` (ADR-8) — single `GameRandom` serialized with state; all shot-angle and AI randomness draws from it.
- **M1-035** `[F]`: Redefine the perfect-block window computably — recommended: window keyed to the **attacker's hit frame + a short deterministic lookahead sim** for time-of-arrival; spec exact boundary semantics for the tests in M1-019.

Implementation tasks:

- **M1-001** `[S]`: `Court` with bounds/net/serve lines (constants exist).
- **M1-002** `[O]`: `Shuttle` — semi-implicit Euler, gravity, quadratic drag.
- **M1-003** `[S]`: Velocity clamping safeguard.
- **M1-004** `[S]`: `Player` — position, jump arc, facing, hitbox, stamina. Jump spec (NEW, decide + document): horizontal air control allowed (reduced), jump not cancellable, **jump smash gets a power/angle bonus** (genre-defining), stun while airborne = fall straight down then stunned on landing.
- **M1-005** `[O]`: `CollisionSystem` with **swept/segment collision** for shuttle vs net and ground (no tunneling at 20 units/tick); landing x interpolated at ground-crossing for line calls. Edge cases: on the line = IN; net-cord on **serve** = let; net-cord **mid-rally = play on** (let-everywhere is exploitable and un-badminton); clips net and falls on hitter's side = opponent's point; shuttle stuck/oscillating on net tape = resolution timeout (point to non-hitter side... decide + test); two collision events same tick.
- **M1-006** `[S]`: `InputAction` bitmask.
- **M1-007** `[S]`: `InputBuffer` ring buffer.
- **M1-008** `[S]`: `InputValidator` — illegal combos, action-while-stunned, toss outside serve, two shots same frame, **double-hit/carry fault**: last-hitter lockout until shuttle crosses the net plane.
- **M1-009** `[O]`: `ShotSystem` — trajectories per shot type via `BalanceConfig`; angle within range chosen via `GameRandom`; **behind-the-body contact = whiff** (facing direction is mechanical, not cosmetic — decide + test).
- **M1-010** `[S]`: Stat-modifier hook (identity multiplier until M3 loadouts).
- **M1-011** `[S]`: `StaminaSystem`.
- **M1-012** `[O]`: `StunSystem` + perfect-timing detection per M1-035 spec.
- **M1-013** `[O]`: `MatchState` FSM, transitions logged with frame numbers.
- **M1-014** `[O]`: Serve rules (expanded): `ShortServeFault`, `ServeTimeoutFault`, **winner of point serves**, **serve fault = point to receiver**, receiver may move after server's toss contact (decide + test), serve timer engine-frame-based.
- **M1-015** `[S]`: Simultaneous-input edge case (same-frame swings: shuttle-side player wins).
- **M1-016** `[S]`: `ScoringSystem` — configurable target (5/11/21), deuce at target-1, 2-point lead, **cap at target+4** (so 11 -> golden point at 14-14; spec + test explicitly), side-switching OFF by default (tuning flag).
- **M1-017** `[F]` design / `[O]` impl: `Simulation` — 60 ticks/sec via accumulator (M1-030), ordered systems: InputValidator -> InputBuffer -> PlayerMovement -> ShotSystem -> ShuttlePhysics -> CollisionSystem -> StaminaSystem -> StunSystem -> MatchFSM. Order documented.
- **M1-018** `[S]`: `MatchErrorHandler` — snapshot + last 60 input frames on unrecoverable error, graceful match termination.
- **M1-032** `[S]` (DONE): `BalanceConfig` from `assets/data/balance.json` + **debug tuning overlay** (sliders for gravity/drag/speeds at runtime) + desktop dev target wired for keyboard play (fast tuning loop).
  - `BalanceConfig` (pure Dart, immutable) holds the **feel** subset — physics coefficients, launch/player speeds, stamina drains; `defaults()` is built straight from the `k*` constants so they can't drift. Structural geometry, shot **angles**, and scoring stay compile-time const (the verified net-clearance math depends on them).
  - `Tunables` now delegates feel fields to a swappable active config (`Tunables.apply` / `resetToDefaults`), defaulting to `BalanceConfig.defaults()`. Set once before a match → determinism within a match preserved (10k-tick tests unaffected). M3 path: config moves into `GameState`'s snapshot signature for cross-peer agreement.
  - Game layer: `BalanceLoader` reads `assets/data/balance.json` (engine stays pure — no `rootBundle`), applied in `main()`. `TuningOverlay` (debug-only, stripped from release) is a slide-in slider panel grouped by subsystem; a slider release re-applies the config and restarts the match.
  - **Feel-tuning to "fun" is the owner's manual gate step** (`flutter run -d macos`, keyboard play). Engine code/tests are in place: coverage 95%, full suite green.
- **M1-019** `[S]`: Unit tests — determinism over 10k ticks (same seed => identical state hash), swept-collision cases incl. max-speed smash through net plane, FSM valid/invalid transitions, scoring (deuce, golden point 14-14, caps at 5/21 targets), stamina curves, stun boundaries per M1-035 spec, serve faults, double-hit fault, behind-body whiff, stuck-shuttle timeout.

### 1B -- Flame Rendering

- **M1-020** `[S]`: `BadmintonGame extends FlameGame`, 1280x720 letterboxed; render driven by accumulator output (interpolation optional).
- **M1-021** `[S]`: `RenderState` — engine-to-renderer contract.
- **M1-022/023/024** `[S]`: Court/Player/Shuttle components (rects + trail).
- **M1-025** `[S]`: Touch controls — D-pad + actions, context-sensitive Toss, min 48dp. **Safe-area/notch offsets** (`MediaQuery.padding`), **Android immersive-sticky**, verify **simultaneous multi-touch** (move + swing).
- **M1-026** `[S]`: HUD — score + stamina bars.

### 1C -- Basic AI

- **M1-027** `[S]`: `AIController` interface — deterministic, randomness via a private `GameRandom` owned by the AI (NOT `GameState.random` — the AI's draws must not touch the tick-owned PRNG stream; rollback replays recorded inputs, not the AI, so the stream must be bit-identical on re-execution).
- **M1-028** `[S]`: `BasicAI` — 15-frame reaction delay, 70/20/10 shot mix.
- **M1-029** `[S]`: Wire into playable match, tap-to-restart.
- **M1-028b** `[S]` (DONE): **Three difficulty tiers** pulled forward from M2-022/023 onto a shared `RuleBasedAi` skeleton (serve/rally structure single-sourced):
  - **easy** — `BasicAI` (above): 15-tick reaction, chases the shuttle's *current* x, 70/20/10 shot mix.
  - **hard** — `HardAI`: 8-tick reaction, `ShuttlePredictor` trajectory lookahead (walks to the predicted descent x before the shuttle arrives), 50/35/15 mix, net-clearance gate on smashes.
  - **challenging** — `ChallengingAI` (the M2-023 spec): 3-tick reaction, tight intercept, context-aware shot choice (jump-smash when the geometry clears the net, drop near the net, else clear/drop).
  - `AiDifficulty.roll(seed)` assigns one tier **at random per match** in the game layer (no difficulty screen yet — that arrives with M2-024); `ShuttlePredictor` is a pure deterministic ghost-integration, drawing from no PRNG.
  - Note: M2-022 `IntermediateAI` is now the one remaining tier to fill the gap between easy and hard; M2-023 `HardAI` is effectively delivered here (revisit its perfect-block behaviour when `StunSystem` blocking is tuned).

### MVP Done Criteria

Full match vs AI with all mechanics, deterministic over a fixed seed, landscape-locked, lifecycle-safe, and tuned to "fun" via the overlay. Delivered as a sequence of reviewed PRs.

---

## Milestone 2 -- Polish, Content & First Revenue (6-8 weeks)

### 2A -- Visual Polish

- **M2-001..005** `[S]`: sprites (8 states), parallax, camera + shake, particles, animation state machine (unchanged from v2).
  - **M2-003 (camera shake) + M2-004 (particles): DONE** as an art-free "impact juice" PR on the existing `RenderEvent` system. `ScreenShake` controller nudges the camera on smash impact (harder when airborne) and perfect block; `ImpactEffectsComponent` spawns particle bursts (smash sparks, ground dust on landing, net-hit puffs). Both are pure presentation reading `frameEvents` only.
  - **M2-005 (animation state machine): DONE** — `PlayerAnimator` is a pure, deterministic state machine (idle / run / rise / fall / land / swing / stunned, in that priority) that drives procedural transforms (squash-stretch, forward lean, jump-stretch, landing-squash, an anticipation→follow-through swing arc, stun wobble, breathing/run bob) on the existing character sprites — real, visible animation with **no new art**. `PlayerComponent` derives the state from `PlayerView` facts plus per-frame x/feet-y deltas and applies the pose around the feet pivot.
  - **M2-002 (parallax): DONE** — `ParallaxBackdropComponent` oversizes the stadium backdrop and drifts it against the camera shake (a fraction, so it reads as farther away) plus a slow idle sway; the floor and net stay world-fixed.
  - **M2-001 (sprites, 8 states): partial** — players still use the single character sprite driven by `PlayerAnimator`; the **shuttle** now renders as a proper procedural shuttlecock (cork nose + flared feather skirt) oriented cork-first along its velocity with a feather flutter (replacing the plain circle). Full per-state sprite-sheet art for players is still open; `PlayerAnimator` exposes the state + 0..1 swing progress for a future sheet renderer.

### 2A.POC — Perspective court fix + POC polish (NEW)

The flat side-view sim vs. perspective-court art mismatch caused false in/out calls and a "half-court" player look. Fixed without touching the tuned engine:

- **`CourtProjection`** (`lib/game/court_projection.dart`): an affine render-space map (`screen = offset + scale*engine`) applied by the gameplay components (players, shuttle, impact bursts). The engine's play rectangle maps onto the drawn court so the left/right bounds line up with the court edges (in/out now matches what you see) and the ground line lands on the court's mid-depth centre line (players stand on-court, not at the near edge). **No shot re-tuning** — the engine is unchanged; only where its already-correct results draw. Defaults are estimates; a debug **court-alignment overlay** (4 sliders) calibrates live against the art.
- **Pause menu (M2-016)**: full-screen Flame overlay (no popups) with Resume/Restart; a HUD pause button opens it, the Android back button routes to it (`PopScope`), and a deliberately-paused match survives a background cycle.
- **Bigger touch buttons (M1-025)**: RALLY/DROP radii bumped (40→54) with a larger primary and font so they clear the 48 dp tap minimum on real phones.
- **M2-030** `[S]` (NEW): Haptics — `HapticFeedback` on smash impact + perfect block. Cheapest feel win available.
  - **DONE (smash) / wired-but-dormant (perfect block).** `HapticsComponent` buzzes on every smash connect. The perfect-block buzz/shake/spark is wired end-to-end (engine now emits a `BlockEvent` via `Simulation.lastTickBlocks` → `RenderState.capture`), but is **currently dormant**: a perfectly-timed block swings 6–12 ticks *before* the shuttle is in reach, and `ShotSystem.trySwing` requires reach-now, so a perfect block whiffs and never connects. **Engine gap to close (M1-035/M2-023 follow-up): make an early, perfectly-timed block swing actually return the shuttle** (a pending-block that resolves on arrival). Once that lands, the perfect-block feedback lights up with no presentation changes. Imperfect blocks already connect (and stun); the infra/tests cover that path.

### 2B -- Audio

- **M2-031** `[O]` (NEW, DO FIRST): Audio latency spike — `flame_audio`/audioplayers has 100ms+ SFX latency on many Android devices, fatal for a timing game. Evaluate `flutter_soloud` (or flame_audio low-latency pool). Decision shapes AudioBloc API + asset formats.
- **M2-006** `[S]`: SFX + music integration (package per M2-031).
- **M2-007** `[S]`: `AudioBloc` — consumes **frame-ID'd** MatchBloc events (ADR-8) so M3 rollback can't double-play SFX; volume/mute/fade.
- **M2-032** `[S]` (NEW): iOS audio-session category — silent-switch behavior, ducking vs user's own music.

### 2C -- Bloc Architecture & Screens

- **M2-008** `[S]`: `MatchBloc` — events carry frame IDs + confirmed-frame watermark (ADR-8); error recovery screen.
- **M2-009/010/011** `[S]`: InputBloc, UIBloc (no popups), `SimulationBridge` — drives the **accumulator** (M1-030), not raw Ticker ticks.
- **M2-012..015** `[S]`: home / mode select / settings / post-match screens. **M2-012 (home) + M2-013 (mode select) + M2-015 (post-match): DONE**, restyled (PRD §6) into a **Contest-of-Champions-inspired hero UI** — deep-space gradient backdrop, gold/energy accents, beveled glow panels. `HomeScreen` = status bar (avatar + level badge + energy/coins/gems chips) → hero VS diorama → game-mode cards (Classic / Point Rush / Competitive-locked) → bottom nav (Home active; Store/Settings placeholders). The old separate mode-select + difficulty-select screens are **replaced by one `ModeSetupScreen`**: a VS preview + Target-Score (5/11/21) **or** Duration (60/90/120s, Point Rush) toggle + Difficulty toggle (4 tiers + Random) + a big FIGHT! CTA → `GameScreen(mode, difficulty)`. Shared widgets in `lib/ui/widgets/arcade_widgets.dart` (SpaceBackground, CurrencyChip, SegmentedToggle, PrimaryCta, GlowPanel). `PostMatchScreen` via the `BadmintonGame.onMatchOver` hook. Settings (M2-014) and the real data behind the header chips (currency/level — M3) remain.
- **M2-016** `[S]` (DONE): Pause flow + **M2-033** Android back button — full-screen Flame overlay (Resume / Restart / Main Menu), `PopScope` routes back → pause (never pop mid-match), survives an app background cycle.
- **M2-034** `[H]` (NEW): SharedPreferences schema version key + migration convention (tutorial flag, settings, AI slider, future cached loadouts).
- **M2-017/018** `[S]`: widget tests, full-match integration test.

### 2D -- AI & Game Modes

- **M2-019** `[S]` (DONE): `GameMode` interface (sealed, pure config → Simulation). Timer-expiry semantics implemented via a deterministic engine **match clock** (`MatchFsm.tickMatchClock`, snapshotted + in the desync signature) ticked **after** scoring each tick: a countdown hitting zero mid-rally lets the rally finish and its point count; expiry-vs-point on the same tick favours the point; a tie at expiry goes to a golden point.
- **M2-020** `[S]` (DONE): `ClassicMode` (target 5/11/21, untimed). Side-switch flag still default off (unchanged).
- **M2-021** `[S]` (DONE): `PointRushMode` (timed; unreachable score target so only the clock ends it; leader at expiry wins). `RenderState` exposes `isTimed`/`remainingTicks`, rendered by `MatchClockComponent` — a top-centre `m:ss` countdown (warning colour in the last 10 s) shown only for timed matches.
- **M2-022** `[S]` (DONE): `IntermediateAI` — extends `HardAI` (trajectory prediction + net-clearance smash gate) but slower (12-tick reaction) with looser positioning and a calmer 65/25/10 mix: the rung between easy and hard. Skill-ordering test: beats easy in most matches.
- **M2-023** `[O]`: HardAI (predictive movement, corner placement, perfect blocks, 3-frame delay). (Delivered earlier as `HardAI`/`ChallengingAI`; perfect-block path still dormant pending the engine block-connect fix.)
- **M2-024** `[S]` (partial): difficulty config + presets + slider. **Difficulty select DONE** — `DifficultySelectScreen` (Home → Mode → Difficulty → Game) lists all four tiers + a **Random** option; `BadmintonGame.fixedDifficulty` keeps the chosen tier across restarts (null = roll a fresh tier each match). A runtime difficulty *slider* (AI tuning knobs) is still open.
- **M2-025** `[S]`: AI tier validation (100-match sims, >70% win rates).

### 2E -- Tutorial

- **M2-026..029** `[S]`: TutorialMode (serve timeout suppressed in scripted steps), overlay, completion tracking (versioned prefs), integration test.

### 2F -- Feature Flags, Monetization-lite & Release (NEW; Android-first)

- **M2-035** `[S]`: **Feature-flag foundation** (user-requested) — `FeatureFlags` service: local JSON defaults in `assets/data/flags.json` + remote override fetched from static hosting (e.g. a JSON on GitHub Pages/Cloud Storage), cached locally. Toggles: ads on/off, each game mode, tutorial auto-launch, IAP, future experiments. M3-092's server-side flag service later becomes the fetch source — **same client API**.
- **M2-036** `[S]`: AdMob — interstitial between matches + optional rewarded (e.g. continue/cosmetic), entirely behind flags; frequency caps.
- **M2-037** `[S]`: "Remove Ads" one-time IAP via `in_app_purchase` — local verification acceptable pre-backend (server-side validation arrives in M3-080); restore-purchases entry point; behind a flag.
- **M2-038** `[S]`: Compliance-lite — privacy policy, Play **Data Safety** form, UMP consent flow for ads/analytics, explicit decision on child-appeal posture (a cartoon sports game risks Play Families classification, which constrains ads + identifiers — decide and document).
- **M2-039** `[H+S]`: Release engineering — app signing, versioning scheme, Play **internal testing track**, store listing + screenshots.

### Milestone 2 Done Criteria

Polished offline game on the Play internal track, earning-capable (ads + Remove-Ads IAP) with every monetization surface toggleable via flags. Natural "ship it" point.

> **Parallel Go track**: Milestone 3-Setup and 3D-Auth have zero coupling to Flutter work — start them during late M2 to spread the Go learning curve.

---

## Milestone 3 -- Online Multiplayer & Backend (12-16 weeks)

**Go-learning note**: this milestone is deliberately custom-built — REST design (chi), Postgres (pgx+sqlc), Redis, JWT auth, goroutine workers, UDP networking, observability, and (new) real deployment/ops are exactly the backend-role skill set. The v3 right-sizing cuts what doesn't teach (synthetic 10k-session scale) and adds what does (3G ops).

### 3-Setup -- Foundations

- **M3-S01** `[H]`: ADR docs (now ADR-1..8) in `docs/adr/`.
- **M3-S02** `[H]`: migration naming convention + CI up/down check.
- **M3-S03** `[F]` design, `[H]` doc: wire protocol doc — now includes **session-token handshake** (M3-017a).
- **M3-S04** `[S]`: Go CI jobs (test, golangci-lint, coverage).
- **M3-S05** `[H]`: docker-compose (Postgres 16 + Redis 7).

### Pre-Work: Fixed-Point Retrofit

- **M3-001** `[F]` design / `[O]` impl: `FixedPoint` (Q16.16) — **including trig**: sin/cos via lookup table or CORDIC (deterministic across x86/ARM). Unit tests for arithmetic properties and trig accuracy bounds.
- **M3-002** `[O]`: `FPVector2D`.
- **M3-003** `[O]`: Retrofit engine — mechanical swap behind the M1-031 abstraction (this is why we built it).
- **M3-004** `[S]`: cross-platform determinism tests (x86 emulator + ARM device in CI).
- **M3-005** `[S]`: binary `GameState` serialization + CRC32 — includes the `GameRandom` state (ADR-8).
- **M3-006/007** `[O]`: snapshot ring buffer; `rollbackTo`/`fastForwardTo` (<= 2ms for 600 frames).
- **M3-008** `[S]`: `ReplayRecorder`.
- **M3-009/010** `[S]`: determinism integration test (10k frames, both arches), perf benchmark (60k tps).

### 3A -- Go UDP Relay

- **M3-011..015** `[S]`: scaffold (chi, slog, graceful shutdown, healthz/readyz), pgx+sqlc, Redis, middleware stack, `/api/v1/` versioning.
- **M3-016** `[O]`: UDP listener + session map.
- **M3-017** `[F]` design / `[O]` impl: wire protocol (22 bytes, versioned).
- **M3-017a** `[F]` (NEW): **UDP session authentication** — matchmaking issues a per-match session token over HTTPS; first-packet handshake binds token -> (matchID, playerID, source addr); subsequent packets validated by source pinning + token. Without this, anyone with a guessed matchID can inject inputs.
- **M3-018..020** `[O]`: packet relay (no game logic per ADR-5), heartbeat, session lifecycle.
- **M3-021** `[S]`: input-rate validation (anti-speed-hack).
- **M3-022** `[S]`: version-mismatch -> force-update packet.
- **M3-023** `[S]` (right-sized): load test **1k concurrent sessions** + pprof profiling (latency p50/95/99, memory/session). The profiling skill is the point, not the number.

### 3B -- Flutter Netcode

- **M3-024** `[F]` design / `[S]` impl: **transport-neutral** interface (renamed from `UdpTransport`): `GameTransport` with UDP impl; **UDP reachability probe** at connect + user-facing error (carrier NAT / hotel Wi-Fi block UDP); WebSocket fallback documented as a follow-up, interface ready for it.
- **M3-025** `[O]`: `NetworkInputBuffer` (merge, reorder).
- **M3-026** `[O]`: `PredictionSystem` + accuracy metrics.
- **M3-027** `[O]`: `RollbackManager` (600-frame cap).
- **M3-040** `[O]` (NEW): **Match-start synchronization handshake** — RTT measurement, agree on frame 0, synchronized countdown, slow-loading-client handling. Frame-window sync (M3-030) maintains alignment; this establishes it.
- **M3-028** `[S]`: visual smoothing (2-3 frame lerp, snap on large corrections).
- **M3-029** `[S]`: input-delay auto-tuning from RTT.

### 3C -- Lag Compensation & Integrity

- **M3-030** `[O]`: frame sync (2-frame window).
- **M3-031** `[F]`: stun resolution per ADR-5.
- **M3-032** `[O]`: desync detection (hash every 60 frames; 5s persistent => void match, no ELO).
- **M3-033** `[O]`: reconnect flow (3s grace).
- **M3-034** `[S]`: iOS background socket handling.
- **M3-035** `[S]`: jitter buffer.
- **M3-036..038** `[S]`: integration tests — 100ms latency + 5% loss, disconnect/reconnect, injected desync.

### 3D -- Backend Services

#### Authentication `[S]` throughout, `[F]` review on token design

- **M3-039..046**: users table, guest auth, register/login, JWT + rotation, middleware, OAuth2 (Google, Apple), tests — as v2, plus:
- **M3-040a** (NEW): **guest identity survives reinstall** — keychain-backed on iOS, equivalent persistence on Android; "link your account" prompt **required before any guest IAP**.
- **M3-046a** (NEW): **account deletion** — `DELETE /api/v1/users/me` with cascading data handling + settings-screen entry point. Hard Apple/Google store requirement; admin-CLI GDPR export alone fails review.

#### Matchmaking

- **M3-047a** `[S]` (NEW, FIRST): **private/friend match codes** — create/join by short code, no ELO stakes. The dominant PvP use case for a small game; much cheaper than ranked infra and independently shippable.
- **M3-048..050** `[S]`: queue endpoint, ELO worker (expanding window), match creation + staleness check.
- **M3-048a** `[S]` (NEW): queue-empty UX — honest "no players online" + offer AI match; optional bot backfill flagged as such.
- **M3-051/053** `[O]`: ELO update; dual-report reconciliation (money/rating-adjacent — Fable review).
- **M3-052/054** `[S]`: cancel queue; tests.
- **M3-047** `[S]` amended: `region` field replaced by an **RTT gate** — warn/decline pairing above threshold (a single relay makes region decorative; intercontinental RTT exceeds what 3-frame delay + rollback can hide).

#### Economy & Store

- **M3-055..062** `[S]`: tables, XP calc + anomaly rate-limiting, post-match distribution, store catalog, idempotent purchases (`SELECT ... FOR UPDATE`), daily rewards (48h grace), tests — as v2, plus:
- **M3-062a** `[S]` (NEW): **scheduled-jobs worker** — cron-style Go worker for seasonal ELO reset + streak expiry (calendar-driven jobs survive restarts; goroutine patterns + optional leader election = good Go learning).

#### Loadouts

- **M3-063..075**: as v2. `[S]` models/StatCalculator/CRUD/Bloc/UI/test harness; `[O]` M3-069 server-authoritative validation + M3-070 balance-patch snapshotting (anti-cheat surface). Offline modes sync `balance_config` opportunistically; never gated.

#### Competitive

- **M3-076** `[S]`: CompetitiveMode (seasonal reset via M3-062a worker; ban/pick placeholder).
- **M3-077** **CUT** (server re-simulation contradicted ADR-5; implied a full Go engine port). Replaced by:
- **M3-077a** `[O]` (NEW): Point Rush **statistical anomaly detection** — score/duration bounds, per-player percentile flags, manual review queue via admin CLI.

### 3E -- Monetization & LiveOps

- **M3-078/079** `[S]`: subscriptions table; Pro Pass (multiplier snapshot at match start).
- **M3-080/081** `[O]` + `[F]` review: IAP receipt validation (App Store Server API v2 / Play Developer API), retry/backoff, refund webhooks + clawback. Money path — Fable reviews.
- **M3-085a** `[S]` (NEW): **subscription compliance client work** — Restore Purchases button (required), manage-subscription deep link, grace-period/billing-retry states surfaced in UI, price + terms shown before purchase.
- **M3-082..084** `[S]`: daily rewards UI, store UI, notification banners.
- **M3-084a** `[S]` (NEW): **HTTP min-client-version gate** (forced update existed only for UDP); offline modes never gated.
- **M3-085** `[S]`: IAP integration tests (mock store).

### 3F -- Analytics, Observability & Admin

- **M3-086..091** `[S]`: telemetry (gzip replay upload), heatmaps, Prometheus metrics, correlation-ID logging, Crashlytics (+ game-context keys), Grafana dashboards `[S/H]`.
- **M3-092** `[S]`: feature-flag **service** (boolean/percentage/segment) — replaces the M2-035 static fetch source behind the same client API.
- **M3-093** `[S/H]`: admin CLI (ban, grant, void, flags, GDPR export) + `admin_audit_log`.

### 3G -- Deployment & Ops (NEW)

The most backend-role-relevant work in the plan:

- **M3-100** `[S]`: provision host — small VPS (Hetzner/DO) or Fly.io/Railway; document the choice as an ADR.
- **M3-101** `[H]`: domain + DNS + TLS (Caddy or Let's Encrypt).
- **M3-102** `[S]`: Dockerized deploy pipeline from GitHub Actions (build, migrate, deploy, health-check, rollback).
- **M3-103** `[S]`: secrets management (env injection; no secrets in repo).
- **M3-104** `[H]`: Postgres backups + a tested restore drill.
- **M3-105** `[H]`: cost budget note: ~$10-25/mo at hobby scale (VPS + domain); revisit if DAU grows.

---

## Technology Stack

As v2 (Flame ^1.35.1 — bump deliberately when needed; flutter_bloc ^9.1.1; Go: chi, pgx/v5 + sqlc, go-redis/v9, golang-migrate, golang-jwt, slog, promhttp, testify, dockertest, golangci-lint) plus:

- **flutter_soloud** (pending M2-031 spike) — low-latency SFX
- **google_mobile_ads** + **UMP** consent — Milestone 2F
- **in_app_purchase** — arrives in 2F (Remove Ads), server validation in 3E

---

## Risk Mitigations (v3)

| Risk | Mitigation |
|---|---|
| Shuttle tunneling / wrong line calls | Swept collision + interpolated ground crossing (M1-005) |
| 120Hz devices double-speed sim | Fixed-timestep accumulator (ADR-7, M1-030) |
| Late-discovered nondeterminism | Seeded PRNG in GameState + math abstraction from M1 (ADR-8) |
| Fixed-point retrofit re-tunes game feel | M1-031 abstraction makes M3 swap mechanical |
| Rollback double-fires SFX/VFX | Frame-ID'd events + confirmed watermark from M2 |
| UDP blocked on some networks | Reachability probe + transport-neutral interface (M3-024) |
| UDP input injection | Session-token handshake + source pinning (M3-017a) |
| Empty matchmaking queue | Friend codes first, honest empty-queue UX, optional bots |
| Store rejection | Account deletion, Restore Purchases, Data Safety, consent (M2-038, M3-046a, M3-085a) |
| Guest loses purchases on reinstall | Keychain identity + link-before-IAP (M3-040a) |
| Backend cost/ops surprise | 3G budget + deploy pipeline + backups |
| XP farming | Anomaly rate-limiting + statistical detection (M3-077a) |

---

## Pacing (v3)

- **Milestone 1**: ~6-8 weeks. Gate: rally feels fun before rendering polish.
- **Milestone 2**: ~6-8 weeks, ending with a revenue-capable Android internal-track release. Start Go 3-Setup/Auth in parallel near the end.
- **Milestone 3**: ~12-16 weeks. Order: fixed-point -> relay + netcode (3A-3C) -> auth + **friend matches** -> ranked + economy + loadouts -> monetization -> observability -> deployment (3G threads through as services come online).

**Total**: ~6-8 months at a few hours/week. Milestone 2F is the first natural "it earns money" point; online PvP through 3C is the second.
