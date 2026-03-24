# Visual Theming System — Design Spec

**Goal:** Make all visuals in Rogue1 data-driven and swappable via a theme system, with runtime theme selection from the lobby. Ship two complete themes (Neon Dungeon, Stone Dungeon) to prove the architecture.

**Approach:** Hybrid — ThemeData Resource for colors/materials/lighting/VFX/UI/audio + PackedScene overrides for geometry that differs per theme (monsters, projectiles).

**Tech:** Godot 4.6, GDScript, GECS ECS, GL Compatibility renderer.

---

## 1. ThemeData Resource

A single Resource class holding all visual parameters for a theme.

```
ThemeData (Resource)
├── meta
│   ├── theme_name: String
│   ├── description: String
│   └── icon: Texture2D (optional, for UI selector)
│
├── palette
│   ├── primary: Color
│   ├── secondary: Color
│   ├── tertiary: Color
│   ├── highlight: Color
│   ├── danger: Color
│   └── element_colors: Dictionary  # "fire" → Color, etc.
│
├── environment
│   ├── background_color: Color
│   ├── ambient_color: Color
│   ├── ambient_energy: float
│   ├── fog_color: Color
│   ├── fog_density: float
│   ├── directional_light_color: Color
│   ├── directional_light_energy: float
│   ├── point_light_energy: float
│   └── point_light_spacing: int
│
├── level_materials
│   ├── floor_albedo: Color
│   ├── floor_roughness: float
│   ├── wall_albedo: Color
│   ├── wall_roughness: float
│   ├── accent_emission_energy: float
│   └── accent_use_palette: bool
│
├── monsters
│   ├── scenes: Dictionary          # "basic" → PackedScene, "boss" → PackedScene
│   ├── body_albedo: Color          # fallback if no scene override
│   ├── eye_color: Color
│   └── health_bar_color: Gradient
│
├── projectile
│   ├── scene: PackedScene          # optional override
│   ├── color: Color
│   └── trail_color: Color
│
├── vfx
│   ├── muzzle_flash_color: Color
│   ├── impact_color: Color
│   ├── death_color: Color
│   └── aoe_blast_color: Color
│
├── ui
│   ├── background_color: Color
│   ├── panel_color: Color
│   ├── text_color: Color
│   ├── accent_color: Color
│   └── damage_flash_color: Color
│
└── audio
    ├── ambient_loop: AudioStream
    ├── death_sound: AudioStream
    └── music: AudioStream
```

## 2. ThemeManager Autoload

Singleton that owns the active theme and provides access to all systems.

```
ThemeManager (Autoload, extends Node)
├── signal theme_changed(theme: ThemeData)
│
├── var active_theme: ThemeData
├── var available_themes: Array[ThemeData]
│
├── func load_themes() → void
│   # Scans res://themes/*/theme.tres for all ThemeData resources
│
├── func set_theme(theme_name: String) → void
│   # Sets active_theme, emits theme_changed
│
├── func get_palette() → palette section of active theme
├── func get_monster_scene(type: String) → PackedScene or null
├── func get_projectile_scene() → PackedScene or null
│
└── _ready():
    # load_themes(), set first as default
```

**Theme directory convention:**
```
res://themes/
├── neon/
│   ├── theme.tres
│   ├── monster_basic.tscn
│   └── monster_boss.tscn
├── stone/
│   ├── theme.tres
│   ├── monster_basic.tscn
│   └── monster_boss.tscn
└── hive/  (future)
    └── ...
```

**Hot-swap behavior:** When `theme_changed` fires, already-built level geometry and spawned monsters do NOT retroactively change. The new theme applies on next level load. Environment, lighting, and UI update immediately since those are set every level load.

## 3. Migration Strategy

Six files with hardcoded visuals migrate to read from ThemeManager:

**level_builder.gd** — Floor/wall colors, accent emission, OmniLight3D grid, directional light. Reads from `theme.level_materials` and `theme.environment`. Accent strip colors from `theme.palette` instead of NeonPalette.

**generated_level.gd** — WorldEnvironment (background, ambient, fog). Reads from `theme.environment` on level load.

**monster.gd** — Currently builds BoxMesh body + eye meshes procedurally. Checks `ThemeManager.get_monster_scene(type)` first — if PackedScene exists, instantiates it. If null, falls back to procedural generation using `theme.monsters` colors.

**projectile.gd / projectile.tscn** — Same pattern as monsters. Scene override if available, otherwise procedural SphereMesh with `theme.projectile.color`.

**vfx_factory.gd** — Reads particle colors from `theme.vfx` instead of hardcoded values. No scene overrides — particles are naturally data-driven.

**UI screens** (hud.gd, shop_screen.gd, victory_screen.gd, game_over_screen.gd, lobby_ui.gd, meta_upgrades_screen.gd, reward_screen.gd) — Read background/panel/text colors from `theme.ui`. Connect to `theme_changed` for live updates.

**floating_text.gd** — Reads text color from theme palette instead of hardcoded green.

**NeonPalette** — Becomes the data source for the "neon" ThemeData resource, then gets deprecated. All callers switch to `ThemeManager.active_theme.palette`.

## 4. Scene Override Contracts

### Monster Scene Contract
- Root node: `Node3D`
- Required child: `BodyMesh` (MeshInstance3D) — visual representation
- Optional child: `EyeMesh` (MeshInstance3D) — hidden if absent
- Required child: `HealthBarAnchor` (Marker3D) — position for health bar above model
- Collision NOT in scene — `monster.gd` creates CharacterBody3D + CollisionShape3D wrapping the visual. Hitboxes stay consistent across themes.
- Boss variant: same contract, can be more elaborate (extra meshes, built-in particles). `monster.gd` still handles scale, HP, components.

### Projectile Scene Contract
- Root node: `Node3D`
- Required child: `Mesh` (MeshInstance3D)
- Optional child: `Trail` (GPUParticles3D) — if absent, vfx_factory trail used as fallback

### Workflow
1. Create scene matching contract (e.g., `themes/stone/monster_basic.tscn`)
2. Reference in ThemeData: `monsters.scenes["basic"] = preload("monster_basic.tscn")`
3. `monster.gd` instantiates, parents under CharacterBody3D

Gameplay code (HP, AI, collision) stays completely separate from visuals. Theme scenes are skins slotted into existing entity structure.

## 5. Theme Selector UI

**Location:** New "Themes" button on lobby screen, next to "Permanent Upgrades".

**Screen:** `src/ui/theme_selector.gd` — programmatic UI (like meta_upgrades_screen). Grid of theme cards showing: theme name, description, 5-color palette swatch preview. Active theme gets highlight border. Click to apply via `ThemeManager.set_theme()`.

**No persistence initially** — theme resets to default on restart. Can add save/load to MetaSave later.

## 6. Theme Definitions

### Neon Dungeon (migrated from existing hardcoded values)
- **Palette:** cyan (#00FFFF), magenta (#FF00FF), purple (#8000FF), teal (#00FF80), orange (#FF8000)
- **Environment:** near-black background (0.02, 0.02, 0.04), dim purple ambient (0.15, 0.15, 0.25), depth fog
- **Levels:** dark grey floors (0.45, 0.42, 0.48) / walls (0.65, 0.62, 0.68), neon emission accent strips cycling palette, colored OmniLight grid
- **Monsters:** dark geometric boxes with neon emission accents, red glowing eyes
- **VFX:** bright emission particles, neon trails
- **UI:** dark blue/purple backgrounds
- **Audio:** existing sounds

### Stone Dungeon (new)
- **Palette:** warm gold, torch orange, bone white, blood red, moss green
- **Environment:** dark brown-black background, warm dim amber ambient, thick brown fog
- **Levels:** rough stone grey floors, darker stone walls, torch-colored accent strips, warm OmniLight grid
- **Monsters:** squat golem (basic), larger horned golem (boss). Earth-toned materials, high roughness, low metallic
- **VFX:** ember/spark particles, warm orange trails
- **UI:** dark brown/parchment backgrounds, warm text
- **Audio:** placeholder initially (dripping, stone echoes)

### Organic Hive (future — proves extensibility)
- Designed later using the same system.

## 7. Scope & Constraints

- **Runtime swappable** from lobby + **dev-time pluggable** via theme data packs
- **Cosmetic only** — no gameplay connection, no unlock requirements
- **Hot-swap applies on next level load** — no mid-level re-theming
- **First milestone:** System architecture + Neon + Stone themes fully playable
- **GL Compatibility renderer** — no advanced shader features
- **Indentation:** 4-spaces for all new files; tabs for existing files that already use tabs
