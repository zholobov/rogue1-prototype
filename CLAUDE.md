# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

3D first-person roguelite prototype built in Godot 4.6 (GL Compatibility renderer). 1–4 player co-op via WebRTC. Uses GECS (GDScript ECS framework) for game logic and WFC (Wave Function Collapse) for procedural level generation.

## Formatting

- **Never use tabs for indentation.** Always use spaces (4 spaces per indent level) in all files.

## Critical Rules

- **Never push to remote** unless explicitly told to push. Only commit locally.
- **Never make code changes** unless explicitly instructed. Research, analyze, and present options — but do not edit files until the user approves and tells you to proceed.
- **Never auto-launch Godot** for playtesting. The user controls when the game runs.
- **Never mask, suppress, or ignore warnings/errors.** Always find and fix the root cause. Do not use `@warning_ignore`, project settings suppression, or workarounds that hide the problem. If the fix is not 100% clear, stop and ask the user — explain the issue, what you know, and present options for how to properly resolve it.

## Running Tests

Tests use GUT (Godot Unit Test). All test files are in `test/unit/` and follow the naming convention `test_*.gd`.

```bash
# Run all tests headless (no window)
godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit

# Run a single test file
godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://test/unit -gtest=test_damage.gd -gexit

# Run a single test method
godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://test/unit -gtest=test_damage.gd -gunit_test_name=test_fire_damage -gexit
```

## Signaling Server

Node.js WebSocket server for WebRTC signaling (lobby/connection setup only, not game traffic).

```bash
cd signaling_server && npm start    # runs server.js
```

## Architecture

### ECS (GECS)

All game logic follows Entity-Component-System via the GECS addon (`addons/gecs/`).

- **Entities** (`src/entities/`): Godot nodes (`CharacterBody3D`, etc.) that create an `Entity` child node and register with `ECS.world`. Example: `PlayerEntity` creates an Entity, adds it to the world, then attaches components.
- **Components** (`src/components/`): Resources extending `Component`. Prefixed `C_` (e.g., `C_Health`, `C_Weapon`, `C_Velocity`). Pure data, no logic.
- **Systems** (`src/systems/`): Extend `System`. Prefixed `S_` (e.g., `S_Weapon`, `S_Movement`). Override `query()` to select entities by component composition, `process()` to run logic each frame.
- **World**: Created per-level in `generated_level.gd`. Systems are registered there. `ECS.process(delta)` is called from `_physics_process`.

Key pattern: Entities own a child `Entity` node → components are added to that node → systems query for component combinations → `generated_level.gd` orchestrates system registration.

### Autoloads (Singletons)

Defined in `project.godot` `[autoload]` section. Key ones:
- `ECS` — GECS world reference
- `Config` (`GameConfig`) — all runtime-configurable game parameters
- `Net` (`NetworkManager`) — WebRTC networking
- `ThemeManager` — visual theme/biome management
- `WeaponRegistry`, `ModifierRegistry`, `Elements` (`ElementRegistry`) — data registries
- `RunManager` — run state machine (LOBBY → MAP → LEVEL → REWARD → SHOP → BOSS → VICTORY → GAME_OVER)
- `MetaSave` — persistent meta-progression
- `DamageEvents` — global damage event bus
- `GameLog` — in-game logging

### Game Flow

`main.gd` is the scene controller. It listens to `RunManager.state_changed` and swaps scenes:
- Lobby → starts a run (solo or multiplayer)
- RunManager drives state transitions: MAP → LEVEL → REWARD → (SHOP every N levels) → MAP → ... → BOSS → VICTORY
- `generated_level.gd` is the core gameplay scene: creates ECS world, registers all systems, generates level via WFC, spawns players/monsters

### Multiplayer Model

- Host-authoritative: host spawns all players/monsters, runs game logic
- Clients receive entities via `MultiplayerSpawner`, sync state via `MultiplayerSynchronizer`
- Projectiles: host-spawned (authoritative), clients show predicted projectiles for responsiveness
- Level grid is pre-generated on host and sent to clients via RPC before state transition

### Procedural Generation Pipeline

`LevelGenerator` → `WFCSolver` → `LevelBuilder`
1. `TileRules` defines tile types and adjacency constraints per modifier profile
2. `WFCSolver` runs Wave Function Collapse on a 2D grid
3. `LevelBuilder` converts the solved grid into 3D geometry with themed materials

### Themes and Biomes

- `ThemeGroup`: a collection of biomes (e.g., "Folk Tales" group has forest, swamp, winter biomes)
- `ThemeData`: per-biome visual config — colors, fog, materials, monster variants, floor/wall/light styles
- Theme assets live in `themes/<name>/` (scenes for players, monsters, bosses)
- Three theme groups: Neon Dungeon, Stone Dungeon, Russian Folk Tales (each with different monster variants)
- `TextureFactory` procedurally generates textures per theme at runtime

### Registries and Definitions

- `src/definitions/`: Data classes (`ElementDefinition`, `WeaponDefinition`, `ModifierDefinition`, `MonsterVariantDefinition`)
- `src/constants/`: StringName constant pools (`ElementNames`, `ConditionNames`, `Modifiers`, `FloorStyles`, `WallStyles`, `LightStyles`)
- `src/config/`: Autoloaded registries that populate from theme data and provide lookup APIs

### Run Progression

- `RunMap` generates a branching node graph per run
- Each node has a modifier (normal, dense, large, dark, horde, boss) and biome
- `MetaSave` persists meta-currency and permanent upgrades across runs
- `UpgradeData` represents per-run upgrades (stat bonuses, abilities like dash/aoe_blast/lifesteal)
