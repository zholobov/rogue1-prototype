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
│   ├── rarity_colors: Dictionary  # "common" → Color, "rare" → Color, "epic" → Color
│   └── element_colors: Dictionary  # "fire" → Color, etc.
│
├── environment
│   ├── background_color: Color
│   ├── ambient_color: Color
│   ├── ambient_energy: float
│   ├── fog_color: Color
│   ├── fog_density: float
│   ├── fog_depth_begin: float
│   ├── fog_depth_end: float
│   ├── directional_light_color: Color
│   ├── directional_light_energy: float
│   ├── point_light_color: Color
│   ├── point_light_energy: float
│   ├── point_light_range: float
│   ├── point_light_attenuation: float
│   └── point_light_spacing: int
│
├── level_materials
│   ├── floor_albedo: Color
│   ├── floor_roughness: float
│   ├── corridor_floor_albedo: Color
│   ├── corridor_floor_roughness: float
│   ├── wall_albedo: Color
│   ├── wall_roughness: float
│   ├── ceiling_albedo: Color
│   ├── ceiling_roughness: float
│   ├── accent_emission_energy: float
│   └── accent_use_palette: bool
│
├── monsters
│   ├── scenes: Dictionary          # "basic" → PackedScene, "boss" → PackedScene
│   ├── body_albedo: Color          # fallback if no scene override
│   ├── body_emission: Color
│   ├── boss_albedo: Color          # boss-specific fallback
│   ├── boss_emission: Color
│   ├── eye_color: Color
│   ├── health_bar_foreground: Color
│   ├── health_bar_background: Color
│   └── health_bar_low_color: Color # color when HP is low (for green→red gradient)
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

**Note on element_colors:** The `palette.element_colors` dictionary replaces both `NeonPalette.ELEMENT_COLORS` and the colors in `element_registry.gd`. Element registry gameplay data (damage types, resistances) stays unchanged — only the display colors are themed.

## 1b. Procedural Texture Generation

All textures are generated procedurally — no external image files. Four approaches, each suited to different use cases. All are fully compatible with web export (WebGL 2 / GL Compatibility).

| Approach | Use case | How it works |
|---|---|---|
| GDScript Image generation | Structured static patterns (bricks, circuits, scales, tile grids) | Create `Image`, set pixels in loops, convert to `ImageTexture`. CPU-only. Generate once at theme load, cache. 256x256 or 512x512. |
| NoiseTexture2D + FastNoiseLite | Organic static surfaces (stone, dirt, flesh, rough terrain) | Built-in Godot resource. CPU-generated noise with cellular/simplex/perlin/value types. Color ramp via Gradient. |
| GradientTexture2D | Color ramps, glow falloffs, emissive ramps, simple gradients | Built-in Godot resource. Linear/radial/square modes. |
| Fragment shaders (GL Compatibility subset) | Animated effects (pulsing neon lines, flowing lava, flickering torches) | Godot shader language → GLSL ES 3.0 → WebGL 2. Must hand-roll noise functions (no built-in `noise()` in GLSL ES 3.0). Only option for per-frame animation without CPU cost. |

**ThemeData integration:** ThemeData gains a `textures` section with generation parameters per surface type. A `TextureFactory` utility generates and caches all textures for the active theme on load.

```
├── textures
│   ├── floor_pattern: Dictionary    # {type: "noise", noise_type: "cellular", color_ramp: Gradient, ...}
│   ├── wall_pattern: Dictionary     # {type: "image_gen", pattern: "bricks", color1: Color, color2: Color, ...}
│   ├── accent_shader: Shader        # optional animated shader for accent surfaces
│   └── monster_skin: Dictionary     # {type: "noise", noise_type: "simplex", ...}
```

**TextureFactory** (`src/effects/texture_factory.gd`):
- `generate_textures(theme: ThemeData) → Dictionary` — returns cached textures keyed by surface name
- Called once when theme is loaded or changed
- Static textures (Image, NoiseTexture2D, GradientTexture2D) generated and cached
- Animated shaders referenced directly — no caching needed

**Neon theme textures:** Minimal — mostly flat colors with emission. Accent strips could use an animated pulsing shader.

**Stone theme textures:** NoiseTexture2D cellular noise for stone surfaces, GDScript Image generation for brick mortar patterns, GradientTexture2D for torch glow falloff.

**Future themes** add their own texture parameters to the same system.

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
│   # Uses ResourceLoader.load() at runtime (not preload)
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

**Resource loading:** ThemeData `.tres` files are loaded at runtime via `ResourceLoader.load()`. Scene references within `.tres` files are set via the Godot editor inspector, which serializes them as ExtResource references. Do NOT use `preload()` inside ThemeData — it only works with compile-time constant paths.

**Hot-swap behavior:** When `theme_changed` fires, already-built level geometry and spawned monsters do NOT retroactively change. The new theme applies on next level load. Environment, lighting, and UI update immediately since those are set every level load.

## 3. Migration Strategy

Files with hardcoded visuals that migrate to read from ThemeManager:

**level_builder.gd** — Floor/corridor/ceiling/wall colors, accent emission, OmniLight3D grid (color, range, attenuation, energy, spacing), directional light. Reads from `theme.level_materials` and `theme.environment`. Accent strip colors from `theme.palette` instead of NeonPalette.

**generated_level.gd** — WorldEnvironment (background, ambient, fog color/density/depth). Reads from `theme.environment` on level load.

**monster.gd** — Currently builds BoxMesh body + eye meshes procedurally with hardcoded materials. Under the new system, checks `ThemeManager.get_monster_scene(type)` — if a PackedScene exists, replaces the visual mesh children with the scene contents. If null, falls back to procedural generation using `theme.monsters` colors. Boss-specific colors (`boss_albedo`, `boss_emission`) used when `setup_as_boss()` is called. Health bar reads `health_bar_foreground`, `health_bar_background`, and `health_bar_low_color`.

**projectile.gd / projectile.tscn** — Same pattern as monsters. Scene override replaces visual children if available, otherwise procedural SphereMesh with `theme.projectile.color`.

**vfx_factory.gd** — Reads particle colors from `theme.vfx` instead of hardcoded values. No scene overrides — particles are naturally data-driven.

**s_aoe_blast.gd** — AoE blast ring particle colors read from `theme.vfx.aoe_blast_color` instead of hardcoded `Color(1.0, 0.6, 0.1)`.

**UI screens** (hud.gd, shop_screen.gd, victory_screen.gd, game_over_screen.gd, lobby_ui.gd, meta_upgrades_screen.gd, reward_screen.gd, map_screen.gd) — Read background/panel/text colors from `theme.ui`. Rarity colors in shop_screen and reward_screen read from `theme.palette.rarity_colors`. Connect to `theme_changed` for live updates. `lobby_ui.gd` adds a ColorRect background at runtime to support theming (the .tscn has no programmatic background currently).

**hud.gd / hud.tscn** — DamageFlash ColorRect initial color stays transparent (Color(1,0,0,0)) in .tscn. Flash trigger color reads from `theme.ui.damage_flash_color` at runtime.

**floating_text.gd** — Reads text color from theme palette instead of hardcoded green.

**NeonPalette** — Becomes the data source for the "neon" ThemeData resource, then gets deprecated. All callers switch to `ThemeManager.active_theme.palette`.

**element_registry.gd** — Display colors (`Color.ORANGE_RED`, `Color.LIGHT_BLUE`, etc.) replaced by lookups into `ThemeManager.active_theme.palette.element_colors`. Gameplay data (damage types, resistances) unchanged.

## 4. Scene Override Contracts

Theme scenes provide **visual replacements only**. They do NOT contain physics bodies or collision shapes. The existing entity scripts (`monster.gd` extends CharacterBody3D, `projectile.gd` extends Area3D) retain their base classes and physics structure.

### How scene overrides work

When a theme provides a scene for a monster/projectile type, the entity script:
1. Removes its default procedural MeshInstance3D children
2. Instantiates the theme scene (a Node3D with visual children)
3. Adds it as a child of the existing CharacterBody3D/Area3D

This keeps the existing physics architecture intact — no base class changes needed.

### Monster Scene Contract
- Root node: `Node3D`
- Required child: `BodyMesh` (MeshInstance3D) — visual representation
- Optional child: `EyeMesh` (MeshInstance3D) — hidden if absent
- Required child: `HealthBarAnchor` (Marker3D) — position for health bar above model
- Scene contains ONLY visuals — no CollisionShape3D, no CharacterBody3D
- Boss variant: same contract, can be more elaborate (extra meshes, built-in particles). `monster.gd` still handles scale, HP, components.

### Projectile Scene Contract
- Root node: `Node3D`
- Required child: `Mesh` (MeshInstance3D)
- Optional child: `Trail` (GPUParticles3D) — if absent, vfx_factory trail used as fallback
- Scene contains ONLY visuals — no Area3D, no CollisionShape3D

### GL Compatibility constraint
Theme scenes using GPUParticles3D must stick to basic ParticleProcessMaterial properties. Features like sub-emitters, attract nodes, and collision nodes are Forward+ only and will not work under GL Compatibility.

### Workflow
1. Create scene matching contract (e.g., `themes/stone/monster_basic.tscn`)
2. Set the scene reference in the ThemeData `.tres` resource via the Godot editor inspector
3. At runtime, `monster.gd` instantiates the scene and parents it under its CharacterBody3D

Gameplay code (HP, AI, collision) stays completely separate from visuals. Theme scenes are skins slotted into existing entity structure.

## 5. Theme Selector UI

**Location:** New "Themes" button on lobby screen, next to "Permanent Upgrades".

**Screen:** `src/ui/theme_selector.gd` — programmatic UI (like meta_upgrades_screen). Grid of theme cards showing: theme name, description, 5-color palette swatch preview. Active theme gets highlight border. Click to apply via `ThemeManager.set_theme()`.

**No persistence initially** — theme resets to default on restart. Can add save/load to MetaSave later.

## 6. Theme Definitions

### Neon Dungeon (migrated from existing hardcoded values)
- **Palette:** cyan (0.0, 0.83, 1.0), magenta (1.0, 0.0, 0.67), purple (0.67, 0.27, 1.0), teal (0.0, 1.0, 0.67), orange (1.0, 0.53, 0.0)
- **Environment:** near-black background (0.02, 0.02, 0.04), dim purple ambient (0.15, 0.15, 0.25), depth fog begin 5.0 end 40.0
- **Levels:** room floors (0.45, 0.42, 0.48), corridor floors (0.38, 0.40, 0.45), walls (0.65, 0.62, 0.68), ceiling (0.50, 0.50, 0.55), neon emission accent strips cycling palette, colored OmniLight grid
- **Monsters:** dark geometric boxes with neon emission accents, red glowing eyes, boss gets red tint
- **VFX:** bright emission particles, neon trails
- **UI:** dark blue/purple backgrounds
- **Audio:** existing sounds

### Stone Dungeon (new)
- **Palette:** warm gold (0.85, 0.65, 0.2), torch orange (1.0, 0.55, 0.1), bone white (0.9, 0.85, 0.75), blood red (0.7, 0.1, 0.1), moss green (0.3, 0.5, 0.2)
- **Environment:** dark brown-black background (0.04, 0.03, 0.02), warm dim amber ambient (0.25, 0.18, 0.1), thick brown fog begin 3.0 end 30.0
- **Levels:** rough stone grey floors (0.4, 0.38, 0.35), corridor stone (0.35, 0.33, 0.30), darker stone walls (0.3, 0.28, 0.25), stone ceiling (0.35, 0.33, 0.30), torch-colored accent strips, warm OmniLight grid
- **Monsters:** squat golem (basic), larger horned golem (boss). Earth-toned materials, high roughness (0.9), low metallic
- **VFX:** ember/spark particles, warm orange trails
- **UI:** dark brown/parchment backgrounds (0.12, 0.08, 0.05), warm text (0.9, 0.8, 0.6)
- **Audio:** placeholder initially (dripping, stone echoes)

### Organic Hive (future — proves extensibility)
- Designed later using the same system.

## 7. Scope & Constraints

- **Runtime swappable** from lobby + **dev-time pluggable** via theme data packs
- **Cosmetic only** — no gameplay connection, no unlock requirements
- **Hot-swap applies on next level load** — no mid-level re-theming
- **First milestone:** System architecture + Neon + Stone themes fully playable
- **GL Compatibility renderer** — no advanced shader features, no Forward+-only particle features
- **Indentation:** 4-spaces for all new files; tabs for existing files that already use tabs
- **Scene overrides are visual-only** — physics bodies and collision stay in entity scripts
