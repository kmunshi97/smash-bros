# Asset Pipeline Convention

## Directory Structure

```
assets/
├── sprites/     # Character and object sprite sheets
├── audio/       # Sound effects and music
└── data/        # Balance config and game data JSON
```

## Sprites (`assets/sprites/`)

- **Tool**: Aseprite (or any editor that exports to the same format)
- **Format**: PNG sprite sheets + JSON atlas metadata
- **Naming**: `<entity>_<action>.png` + `<entity>_<action>.json`
  - Example: `player_idle.png`, `player_idle.json`
  - Example: `player_smash.png`, `player_smash.json`
- **Resolution**: Design at 1x for a 1280x720 canonical game resolution
- **Placeholders**: Use colored rectangles until final art is produced.
  Placeholder colors:
  - Player 1: blue (#4A90D9)
  - Player 2 / AI: red (#D94A4A)
  - Shuttle: white (#FFFFFF)
  - Court: green (#2D5A27) with white lines
  - Net: dark gray (#444444)

## Audio (`assets/audio/`)

- **SFX format**: `.ogg` (Ogg Vorbis) -- small file size, good quality, broad support
- **Music format**: `.mp3` -- widely supported, good compression for longer tracks
- **Naming**: `sfx_<action>.ogg` for effects, `music_<context>.mp3` for tracks
  - Example: `sfx_hit_normal.ogg`, `sfx_hit_smash.ogg`, `sfx_point_scored.ogg`
  - Example: `music_menu.mp3`, `music_ingame.mp3`
- **Volume normalization**: All SFX should be normalized to -3dB peak

## Game Data (`assets/data/`)

- **Format**: JSON
- **Files**:
  - `balance.json` -- shot speeds, stamina costs, timing windows, stat multipliers
  - `characters.json` -- character definitions with base stats (Milestone 3)
  - `racquets.json` -- racquet component definitions with modifiers (Milestone 3)
- **Encoding**: UTF-8, no BOM
