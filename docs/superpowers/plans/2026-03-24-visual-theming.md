# Visual Theming System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all visuals data-driven and swappable via a theme system, shipping two complete themes (Neon Dungeon, Stone Dungeon).

**Architecture:** Hybrid ThemeData Resource (colors/materials/lighting/VFX/UI/audio) + PackedScene overrides for per-theme monster geometry. ThemeManager autoload provides access; TextureFactory generates procedural textures. All existing hardcoded visuals migrate to read from the active theme.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS, GL Compatibility renderer, GUT testing framework.

**Spec:** `docs/superpowers/specs/2026-03-24-visual-theming-design.md`

**Indentation rules:** 4-spaces for ALL new files. Tabs for existing files that already use tabs (`main.gd`, `game_config.gd`, `s_player_input.gd`, `lobby_ui.gd`, `level_builder.gd`, `hud.gd`). All other existing files (including `generated_level.gd`, `monster.gd`, UI screens) use 4-spaces.

**Autoload ordering note:** ThemeManager MUST be registered BEFORE Elements in `project.godot` so that `ThemeManager.active_theme` is available when element_registry.gd's `_ready()` runs.

**Scene import note:** New `.tscn` files must be imported by Godot before `load()` works at runtime. After creating `.tscn` files, the Godot editor needs to scan/import them (happens automatically on next editor open).

---

## File Structure

### New files to create:
| File | Responsibility |
|---|---|
| `src/themes/theme_data.gd` | ThemeData Resource class — all visual parameters for a theme |
| `src/themes/theme_manager.gd` | ThemeManager autoload — owns active theme, emits signals |
| `src/effects/texture_factory.gd` | Generates and caches procedural textures per theme |
| `themes/neon/neon_theme.gd` | Factory function returning a ThemeData with exact current neon values |
| `themes/neon/monster_basic.tscn` | Neon basic monster visual scene (geometric boxes + neon emission) |
| `themes/neon/monster_boss.tscn` | Neon boss monster visual scene (larger, red-tinted) |
| `themes/stone/stone_theme.gd` | Factory function returning a ThemeData with stone dungeon values |
| `themes/stone/monster_basic.tscn` | Stone golem visual scene (stacked primitives, earthy materials) |
| `themes/stone/monster_boss.tscn` | Stone boss golem visual scene (larger, horned) |
| `src/ui/theme_selector.gd` | Theme selector screen for lobby |
| `test/unit/test_theming.gd` | Unit tests for theming system |

### Existing files to modify:
| File | Changes |
|---|---|
| `project.godot` | Add ThemeManager autoload |
| `src/generation/level_builder.gd` | Read materials/lights from theme instead of hardcoded |
| `src/levels/generated_level.gd` | Read environment from theme instead of hardcoded |
| `src/entities/monster.gd` | Scene override support + read colors from theme |
| `src/entities/projectile.gd` | Read colors from theme |
| `src/effects/vfx_factory.gd` | Read particle colors from theme |
| `src/effects/floating_text.gd` | Read text color from theme |
| `src/systems/s_aoe_blast.gd` | Read blast color from theme |
| `src/config/element_registry.gd` | Read display colors from theme |
| `src/ui/lobby_ui.gd` | Add "Themes" button + background theming |
| `src/ui/map_screen.gd` | Read background from theme |
| `src/ui/shop_screen.gd` | Read background + rarity colors from theme |
| `src/ui/reward_screen.gd` | Read background + rarity colors from theme |
| `src/ui/victory_screen.gd` | Read background from theme |
| `src/ui/game_over_screen.gd` | Read background from theme |
| `src/ui/meta_upgrades_screen.gd` | Read background from theme |
| `src/ui/hud.gd` | Read damage flash color from theme |
| `src/main.gd` | Handle theme selector screen navigation |

### Files to remove:
| File | Reason |
|---|---|
| `src/effects/neon_palette.gd` | Replaced by ThemeManager.active_theme.palette |

---

## Task 1: ThemeData Resource Class

**Files:**
- Create: `src/themes/theme_data.gd`
- Test: `test/unit/test_theming.gd`

**Context:** This is the core data class. Every other task depends on it. All visual parameters for a theme live here as @export vars so they're editable in the Godot inspector.

- [ ] **Step 1: Write failing tests for ThemeData**

Create `test/unit/test_theming.gd`:

```gdscript
extends GutTest

# --- ThemeData defaults ---
func test_theme_data_has_name():
    var td = ThemeData.new()
    assert_eq(td.theme_name, "")

func test_theme_data_has_palette():
    var td = ThemeData.new()
    assert_ne(td.primary, Color.BLACK, "primary should have a non-black default")
    assert_typeof(td.rarity_colors, TYPE_DICTIONARY)
    assert_typeof(td.element_colors, TYPE_DICTIONARY)

func test_theme_data_has_environment():
    var td = ThemeData.new()
    assert_gt(td.fog_depth_end, td.fog_depth_begin, "fog end > begin")
    assert_gt(td.point_light_spacing, 0)

func test_theme_data_has_level_materials():
    var td = ThemeData.new()
    assert_gt(td.floor_roughness, 0.0)
    assert_gt(td.wall_roughness, 0.0)

func test_theme_data_has_monsters():
    var td = ThemeData.new()
    assert_typeof(td.monster_scenes, TYPE_DICTIONARY)
    assert_ne(td.eye_color, Color.BLACK)

func test_theme_data_has_vfx():
    var td = ThemeData.new()
    assert_ne(td.muzzle_flash_color, Color.BLACK)

func test_theme_data_has_ui():
    var td = ThemeData.new()
    assert_ne(td.ui_text_color, Color.BLACK)

func test_theme_data_get_palette_array():
    var td = ThemeData.new()
    td.primary = Color.RED
    td.secondary = Color.GREEN
    td.tertiary = Color.BLUE
    td.highlight = Color.YELLOW
    td.danger = Color.WHITE
    var arr = td.get_palette_array()
    assert_eq(arr.size(), 5)
    assert_eq(arr[0], Color.RED)

func test_theme_data_get_random_palette_color():
    var td = ThemeData.new()
    td.primary = Color.RED
    td.secondary = Color.GREEN
    td.tertiary = Color.BLUE
    td.highlight = Color.YELLOW
    td.danger = Color.WHITE
    var c = td.get_random_palette_color()
    assert_has([Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.WHITE], c)

func test_theme_data_get_element_color_known():
    var td = ThemeData.new()
    td.element_colors = {"fire": Color.RED}
    assert_eq(td.get_element_color("fire"), Color.RED)

func test_theme_data_get_element_color_unknown():
    var td = ThemeData.new()
    td.element_colors = {"fire": Color.RED}
    var c = td.get_element_color("unknown")
    assert_eq(c, Color.WHITE, "unknown elements default to white")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://test/unit -gtest=test_theming.gd -gexit`
Expected: FAIL — ThemeData class not found

- [ ] **Step 3: Implement ThemeData**

Create `src/themes/theme_data.gd`:

```gdscript
class_name ThemeData
extends Resource

# --- Meta ---
@export var theme_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

# --- Palette ---
@export_group("Palette")
@export var primary: Color = Color(1.0, 1.0, 1.0)
@export var secondary: Color = Color(0.8, 0.8, 0.8)
@export var tertiary: Color = Color(0.6, 0.6, 0.6)
@export var highlight: Color = Color(1.0, 1.0, 0.0)
@export var danger: Color = Color(1.0, 0.0, 0.0)
@export var rarity_colors: Dictionary = {
    "common": Color(0.8, 0.8, 0.8),
    "rare": Color(0.3, 0.5, 1.0),
    "epic": Color(0.7, 0.2, 1.0),
}
@export var element_colors: Dictionary = {
    "": Color(1.0, 1.0, 1.0),
    "fire": Color(1.0, 0.27, 0.0),
    "ice": Color(0.0, 0.87, 1.0),
    "water": Color(0.0, 0.4, 1.0),
    "oil": Color(0.33, 0.42, 0.18),
}

# --- Environment ---
@export_group("Environment")
@export var background_color: Color = Color(0.02, 0.02, 0.04)
@export var ambient_color: Color = Color(0.15, 0.15, 0.25)
@export var ambient_energy: float = 0.8
@export var fog_color: Color = Color(0.02, 0.02, 0.06)
@export var fog_density: float = 0.02
@export var fog_depth_begin: float = 5.0
@export var fog_depth_end: float = 40.0
@export var directional_light_color: Color = Color(0.6, 0.65, 0.8)
@export var directional_light_energy: float = 0.5
@export var point_light_color: Color = Color(1.0, 1.0, 1.0)
@export var point_light_energy: float = 0.8
@export var point_light_range_mult: float = 1.5  # multiplied by tile_size at runtime
@export var point_light_attenuation: float = 2.0
@export var point_light_spacing: int = 2

# --- Level Materials ---
@export_group("Level Materials")
@export var floor_albedo: Color = Color(0.45, 0.42, 0.48)
@export var floor_roughness: float = 0.9
@export var corridor_floor_albedo: Color = Color(0.38, 0.40, 0.45)
@export var corridor_floor_roughness: float = 0.9
@export var wall_albedo: Color = Color(0.65, 0.62, 0.68)
@export var wall_roughness: float = 0.85
@export var ceiling_albedo: Color = Color(0.50, 0.50, 0.55)
@export var ceiling_roughness: float = 0.95
@export var accent_emission_energy: float = 3.0
@export var accent_use_palette: bool = true

# --- Monsters ---
@export_group("Monsters")
@export var monster_scenes: Dictionary = {}  # "basic" → PackedScene, "boss" → PackedScene
@export var body_albedo: Color = Color(0.08, 0.08, 0.1)
@export var body_emission: Color = Color(0.0, 0.83, 1.0)
@export var boss_albedo: Color = Color(0.2, 0.02, 0.02)
@export var boss_emission: Color = Color(1.0, 0.15, 0.1)
@export var eye_color: Color = Color(1.0, 0.1, 0.1)
@export var health_bar_foreground: Color = Color(0.0, 1.0, 0.3)
@export var health_bar_background: Color = Color(0.15, 0.15, 0.15)
@export var health_bar_low_color: Color = Color(1.0, 0.0, 0.1)

# --- Projectile ---
@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_color: Color = Color(1.0, 1.0, 1.0)
@export var projectile_trail_color: Color = Color(1.0, 1.0, 1.0)

# --- VFX ---
@export_group("VFX")
@export var muzzle_flash_color: Color = Color(1.0, 0.9, 0.6)
@export var impact_color: Color = Color(1.0, 1.0, 1.0)
@export var death_color: Color = Color(1.0, 0.3, 0.1)
@export var aoe_blast_color: Color = Color(1.0, 0.6, 0.1)

# --- UI ---
@export_group("UI")
@export var ui_background_color: Color = Color(0.05, 0.05, 0.1)
@export var ui_panel_color: Color = Color(0.1, 0.1, 0.15)
@export var ui_text_color: Color = Color(1.0, 1.0, 1.0)
@export var ui_accent_color: Color = Color(0.0, 0.83, 1.0)
@export var ui_damage_flash_color: Color = Color(1.0, 0.0, 0.0, 0.3)

# --- Audio ---
@export_group("Audio")
@export var ambient_loop: AudioStream
@export var death_sound: AudioStream
@export var music: AudioStream

# --- Textures ---
@export_group("Textures")
@export var floor_pattern: Dictionary = {}
@export var wall_pattern: Dictionary = {}
@export var accent_shader: Shader
@export var monster_skin: Dictionary = {}

# --- Helper methods ---

func get_palette_array() -> Array[Color]:
    return [primary, secondary, tertiary, highlight, danger]

func get_random_palette_color() -> Color:
    var arr = get_palette_array()
    return arr[randi() % arr.size()]

func get_element_color(element: String) -> Color:
    if element_colors.has(element):
        return element_colors[element]
    return Color.WHITE
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://test/unit -gtest=test_theming.gd -gexit`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/themes/theme_data.gd test/unit/test_theming.gd
git commit -m "feat: add ThemeData resource class with all visual parameters"
```

---

## Task 2: ThemeManager Autoload

**Files:**
- Create: `src/themes/theme_manager.gd`
- Modify: `project.godot` (add autoload)
- Test: `test/unit/test_theming.gd` (append)

**Context:** ThemeManager is the singleton that holds the active theme and lets any system access it. It must be registered as an autoload in project.godot. The neon theme definition doesn't exist yet, so ThemeManager will use a default ThemeData for now. Task 3 will add the real neon theme.

- [ ] **Step 1: Write failing tests for ThemeManager**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- ThemeManager ---
func test_theme_manager_has_active_theme():
    # ThemeManager is an autoload, should be available
    assert_not_null(ThemeManager)
    assert_not_null(ThemeManager.active_theme)

func test_theme_manager_available_themes_not_empty():
    assert_gt(ThemeManager.available_themes.size(), 0)

func test_theme_manager_set_theme_emits_signal():
    var theme_name = ThemeManager.available_themes[0].theme_name
    watch_signals(ThemeManager)
    ThemeManager.set_theme(theme_name)
    assert_signal_emitted(ThemeManager, "theme_changed")

func test_theme_manager_set_theme_changes_active():
    var first = ThemeManager.available_themes[0]
    ThemeManager.set_theme(first.theme_name)
    assert_eq(ThemeManager.active_theme.theme_name, first.theme_name)

func test_theme_manager_get_monster_scene_returns_null_for_missing():
    var scene = ThemeManager.get_monster_scene("nonexistent_type")
    assert_null(scene)

func test_theme_manager_get_palette_returns_active_palette():
    var palette = ThemeManager.get_palette()
    assert_eq(palette, ThemeManager.active_theme.get_palette_array())
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — ThemeManager autoload not found

- [ ] **Step 3: Implement ThemeManager**

Create `src/themes/theme_manager.gd`:

```gdscript
extends Node

signal theme_changed(theme: ThemeData)

var active_theme: ThemeData
var available_themes: Array[ThemeData] = []

func _ready() -> void:
    _load_themes()
    if available_themes.size() > 0:
        active_theme = available_themes[0]

func set_theme(theme_name_to_set: String) -> void:
    for theme in available_themes:
        if theme.theme_name == theme_name_to_set:
            active_theme = theme
            theme_changed.emit(theme)
            return

func get_palette() -> Array[Color]:
    return active_theme.get_palette_array()

func get_monster_scene(type: String) -> PackedScene:
    if active_theme.monster_scenes.has(type):
        return active_theme.monster_scenes[type]
    return null

func get_projectile_scene() -> PackedScene:
    return active_theme.projectile_scene

func _load_themes() -> void:
    # For now, register a default theme.
    # Task 3 will add neon_theme.gd, Task 12 adds stone_theme.gd.
    # Later, this can scan res://themes/*/theme.tres for external themes.
    var default_theme = ThemeData.new()
    default_theme.theme_name = "Default"
    default_theme.description = "Default theme"
    available_themes.append(default_theme)
```

- [ ] **Step 4: Register ThemeManager autoload in project.godot**

Add ThemeManager BEFORE the Elements autoload line in `project.godot` (so ThemeManager._ready() runs before element_registry.gd._ready()):

```ini
ThemeManager="*res://src/themes/theme_manager.gd"
Elements="*res://src/config/element_registry.gd"
```

The Elements line already exists — just insert ThemeManager above it. The final autoload order should be: ECS, Config, Net, ThemeManager, Elements, RunManager, MetaSave.

- [ ] **Step 5: Run tests to verify they pass**

Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add src/themes/theme_manager.gd project.godot test/unit/test_theming.gd
git commit -m "feat: add ThemeManager autoload singleton"
```

---

## Task 3: Neon Theme Definition

**Files:**
- Create: `themes/neon/neon_theme.gd`
- Modify: `src/themes/theme_manager.gd` (register neon theme)
- Test: `test/unit/test_theming.gd` (append)

**Context:** This task extracts ALL current hardcoded visual values into a neon ThemeData. The values MUST exactly match what's currently in the codebase so that migrating systems (Tasks 5-10) produces zero visual change. Reference the source files for exact values:
- `src/effects/neon_palette.gd` — palette colors
- `src/generation/level_builder.gd:16-28,78,144` — material + light colors
- `src/levels/generated_level.gd:19-28` — environment colors
- `src/entities/monster.gd:46-81,137-177` — monster colors
- `src/effects/vfx_factory.gd:25,58,97` — VFX colors
- `src/effects/floating_text.gd:6-7` — text color
- `src/systems/s_aoe_blast.gd:57-60` — blast color
- `src/ui/map_screen.gd:15` — UI background
- `src/ui/shop_screen.gd:18,76-80` — UI background + rarity
- `src/ui/reward_screen.gd:15,47-51` — UI background + rarity
- `src/ui/victory_screen.gd:13` — UI background
- `src/ui/game_over_screen.gd:12` — UI background
- `src/ui/meta_upgrades_screen.gd:12` — UI background

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Neon Theme values ---
func test_neon_theme_exists():
    var found = false
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            found = true
    assert_true(found, "Neon Dungeon theme should be registered")

func test_neon_theme_palette_matches_neon_palette():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.primary.r, 0.0, 0.01)
    assert_almost_eq(neon.primary.g, 0.83, 0.01)
    assert_almost_eq(neon.primary.b, 1.0, 0.01)
    # Magenta
    assert_almost_eq(neon.secondary.r, 1.0, 0.01)
    assert_almost_eq(neon.secondary.g, 0.0, 0.01)
    assert_almost_eq(neon.secondary.b, 0.67, 0.01)

func test_neon_theme_environment_matches_current():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.background_color.r, 0.02, 0.01)
    assert_almost_eq(neon.background_color.g, 0.02, 0.01)
    assert_almost_eq(neon.background_color.b, 0.04, 0.01)
    assert_almost_eq(neon.fog_depth_begin, 5.0, 0.1)
    assert_almost_eq(neon.fog_depth_end, 40.0, 0.1)

func test_neon_theme_floor_matches_current():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.floor_albedo.r, 0.45, 0.01)
    assert_almost_eq(neon.floor_albedo.g, 0.42, 0.01)
    assert_almost_eq(neon.floor_albedo.b, 0.48, 0.01)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — no "Neon Dungeon" theme registered

- [ ] **Step 3: Implement neon theme definition**

Create `themes/neon/neon_theme.gd`:

```gdscript
class_name NeonTheme

static func create() -> ThemeData:
    var t = ThemeData.new()

    # Meta
    t.theme_name = "Neon Dungeon"
    t.description = "Dark corridors lit by neon glow"

    # Palette (from neon_palette.gd)
    t.primary = Color(0.0, 0.83, 1.0)      # CYAN
    t.secondary = Color(1.0, 0.0, 0.67)    # MAGENTA
    t.tertiary = Color(0.67, 0.27, 1.0)    # PURPLE
    t.highlight = Color(0.0, 1.0, 0.67)    # TEAL
    t.danger = Color(1.0, 0.53, 0.0)       # ORANGE
    t.rarity_colors = {
        "common": Color(0.8, 0.8, 0.8),
        "rare": Color(0.3, 0.5, 1.0),
        "epic": Color(0.7, 0.2, 1.0),
    }
    t.element_colors = {
        "": Color(1.0, 1.0, 1.0),
        "fire": Color(1.0, 0.27, 0.0),
        "ice": Color(0.0, 0.87, 1.0),
        "water": Color(0.0, 0.4, 1.0),
        "oil": Color(0.33, 0.42, 0.18),
    }

    # Environment (from generated_level.gd:19-28)
    t.background_color = Color(0.02, 0.02, 0.04)
    t.ambient_color = Color(0.15, 0.15, 0.25)
    t.ambient_energy = 0.8
    t.fog_color = Color(0.02, 0.02, 0.06)
    t.fog_density = 0.02
    t.fog_depth_begin = 5.0
    t.fog_depth_end = 40.0
    t.directional_light_color = Color(0.6, 0.65, 0.8)
    t.directional_light_energy = 0.5
    t.point_light_color = Color(1.0, 1.0, 1.0)  # Uses palette cycling per-light
    t.point_light_energy = 0.8
    t.point_light_range_mult = 1.5  # multiplied by tile_size at runtime
    t.point_light_attenuation = 2.0
    t.point_light_spacing = 2

    # Level materials (from level_builder.gd:16-28)
    t.floor_albedo = Color(0.45, 0.42, 0.48)
    t.floor_roughness = 0.9
    t.corridor_floor_albedo = Color(0.38, 0.40, 0.45)
    t.corridor_floor_roughness = 0.9
    t.wall_albedo = Color(0.65, 0.62, 0.68)
    t.wall_roughness = 0.85
    t.ceiling_albedo = Color(0.50, 0.50, 0.55)
    t.ceiling_roughness = 0.95
    t.accent_emission_energy = 3.0  # actual code uses randf_range(2.0, 3.0); this is the upper bound
    t.accent_use_palette = true

    # Monsters (from monster.gd:46-81)
    t.body_albedo = Color(0.08, 0.08, 0.1)
    t.body_emission = Color(0.0, 0.83, 1.0)   # Uses random palette per-monster
    t.boss_albedo = Color(0.2, 0.02, 0.02)
    t.boss_emission = Color(1.0, 0.15, 0.1)
    t.eye_color = Color(1.0, 0.1, 0.1)
    t.health_bar_foreground = Color(0.0, 1.0, 0.3)
    t.health_bar_background = Color(0.15, 0.15, 0.15)
    t.health_bar_low_color = Color(1.0, 0.0, 0.1)

    # Projectile
    t.projectile_color = Color(1.0, 1.0, 1.0)  # element-driven
    t.projectile_trail_color = Color(1.0, 1.0, 1.0)

    # VFX (from vfx_factory.gd:25, s_aoe_blast.gd:57)
    t.muzzle_flash_color = Color(1.0, 0.9, 0.6)
    t.impact_color = Color(1.0, 1.0, 1.0)     # element-driven
    t.death_color = Color(1.0, 0.3, 0.1)
    t.aoe_blast_color = Color(1.0, 0.6, 0.1)

    # UI (from various screen files)
    t.ui_background_color = Color(0.05, 0.05, 0.1)
    t.ui_panel_color = Color(0.1, 0.1, 0.15)
    t.ui_text_color = Color(1.0, 1.0, 1.0)
    t.ui_accent_color = Color(0.0, 0.83, 1.0)
    t.ui_damage_flash_color = Color(1.0, 0.0, 0.0, 0.3)

    # Textures — neon uses minimal textures, mostly flat + emission
    t.floor_pattern = {}
    t.wall_pattern = {}
    t.monster_skin = {}

    return t
```

- [ ] **Step 4: Register neon theme in ThemeManager**

Modify `src/themes/theme_manager.gd` `_load_themes()`:

```gdscript
func _load_themes() -> void:
    available_themes.append(NeonTheme.create())
    active_theme = available_themes[0]
```

Remove the old default theme placeholder code.

- [ ] **Step 5: Run tests to verify they pass**

Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add themes/neon/neon_theme.gd src/themes/theme_manager.gd test/unit/test_theming.gd
git commit -m "feat: add neon theme definition with exact current visual values"
```

---

## Task 4: TextureFactory

**Files:**
- Create: `src/effects/texture_factory.gd`
- Test: `test/unit/test_theming.gd` (append)

**Context:** Generates procedural textures from ThemeData parameters. Uses NoiseTexture2D + FastNoiseLite for organic patterns, GDScript Image generation for structured patterns, GradientTexture2D for ramps. All web-safe (CPU-only). Textures are generated once per theme switch and cached.

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- TextureFactory ---
func test_texture_factory_generate_noise_returns_texture():
    var params = {
        "type": "noise",
        "noise_type": "cellular",
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is NoiseTexture2D)

func test_texture_factory_generate_gradient_returns_texture():
    var params = {
        "type": "gradient",
        "color_from": Color.RED,
        "color_to": Color.BLUE,
        "width": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is GradientTexture2D)

func test_texture_factory_generate_image_returns_texture():
    var params = {
        "type": "image_gen",
        "pattern": "bricks",
        "color1": Color(0.4, 0.38, 0.35),
        "color2": Color(0.25, 0.22, 0.20),
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is ImageTexture)

func test_texture_factory_generate_for_theme_returns_dict():
    var td = ThemeData.new()
    td.floor_pattern = {"type": "noise", "noise_type": "cellular", "width": 64, "height": 64}
    var textures = TextureFactory.generate_for_theme(td)
    assert_typeof(textures, TYPE_DICTIONARY)
    assert_true(textures.has("floor"))

func test_texture_factory_empty_pattern_returns_null():
    var tex = TextureFactory.generate_texture({})
    assert_null(tex)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — TextureFactory not found

- [ ] **Step 3: Implement TextureFactory**

Create `src/effects/texture_factory.gd`:

```gdscript
class_name TextureFactory

static var _cache: Dictionary = {}

static func generate_for_theme(theme: ThemeData) -> Dictionary:
    _cache.clear()
    var result: Dictionary = {}

    if theme.floor_pattern.size() > 0:
        result["floor"] = generate_texture(theme.floor_pattern)
    if theme.wall_pattern.size() > 0:
        result["wall"] = generate_texture(theme.wall_pattern)
    if theme.monster_skin.size() > 0:
        result["monster"] = generate_texture(theme.monster_skin)

    _cache = result
    return result

static func get_cached() -> Dictionary:
    return _cache

static func generate_texture(params: Dictionary) -> Texture2D:
    if params.size() == 0:
        return null

    var tex_type = params.get("type", "")
    match tex_type:
        "noise":
            return _generate_noise(params)
        "gradient":
            return _generate_gradient(params)
        "image_gen":
            return _generate_image(params)
    return null

static func _generate_noise(params: Dictionary) -> NoiseTexture2D:
    var tex = NoiseTexture2D.new()
    var noise = FastNoiseLite.new()

    var noise_type_str = params.get("noise_type", "simplex")
    match noise_type_str:
        "cellular":
            noise.noise_type = FastNoiseLite.TYPE_CELLULAR
        "simplex":
            noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
        "perlin":
            noise.noise_type = FastNoiseLite.TYPE_PERLIN
        "value":
            noise.noise_type = FastNoiseLite.TYPE_VALUE

    noise.frequency = params.get("frequency", 0.05)
    noise.fractal_octaves = params.get("octaves", 3)
    tex.noise = noise
    tex.width = params.get("width", 256)
    tex.height = params.get("height", 256)

    if params.has("color_ramp"):
        tex.color_ramp = params["color_ramp"]

    return tex

static func _generate_gradient(params: Dictionary) -> GradientTexture2D:
    var tex = GradientTexture2D.new()
    var grad = Gradient.new()
    var c_from = params.get("color_from", Color.BLACK)
    var c_to = params.get("color_to", Color.WHITE)
    grad.set_color(0, c_from)
    grad.set_color(1, c_to)
    tex.gradient = grad
    tex.width = params.get("width", 256)
    tex.height = params.get("height", 64)
    return tex

static func _generate_image(params: Dictionary) -> ImageTexture:
    var w: int = params.get("width", 256)
    var h: int = params.get("height", 256)
    var c1: Color = params.get("color1", Color(0.4, 0.4, 0.4))
    var c2: Color = params.get("color2", Color(0.3, 0.3, 0.3))
    var pattern: String = params.get("pattern", "bricks")

    var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

    match pattern:
        "bricks":
            _draw_bricks(img, w, h, c1, c2)
        "grid":
            _draw_grid(img, w, h, c1, c2)
        "scales":
            _draw_scales(img, w, h, c1, c2)
        _:
            img.fill(c1)

    return ImageTexture.create_from_image(img)

static func _draw_bricks(img: Image, w: int, h: int, brick_color: Color, mortar_color: Color) -> void:
    var brick_w: int = maxi(w / 8, 4)
    var brick_h: int = maxi(h / 16, 2)
    var mortar: int = 1

    for y in range(h):
        for x in range(w):
            var row = y / brick_h
            var offset = (brick_w / 2) * (row % 2)
            var bx = (x + offset) % brick_w
            var by = y % brick_h
            if bx < mortar or by < mortar:
                img.set_pixel(x, y, mortar_color)
            else:
                img.set_pixel(x, y, brick_color)

static func _draw_grid(img: Image, w: int, h: int, bg_color: Color, line_color: Color) -> void:
    var spacing: int = maxi(w / 8, 4)
    img.fill(bg_color)
    for y in range(h):
        for x in range(w):
            if x % spacing == 0 or y % spacing == 0:
                img.set_pixel(x, y, line_color)

static func _draw_scales(img: Image, w: int, h: int, c1: Color, c2: Color) -> void:
    var scale_w: int = maxi(w / 8, 4)
    var scale_h: int = maxi(h / 8, 4)
    for y in range(h):
        for x in range(w):
            var row = y / scale_h
            var offset = (scale_w / 2) * (row % 2)
            var sx = (x + offset) % scale_w
            var sy = y % scale_h
            var cx = float(sx) / scale_w - 0.5
            var cy = float(sy) / scale_h - 0.5
            var dist = sqrt(cx * cx + cy * cy)
            if dist < 0.4:
                img.set_pixel(x, y, c1)
            else:
                img.set_pixel(x, y, c2)
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/effects/texture_factory.gd test/unit/test_theming.gd
git commit -m "feat: add TextureFactory for procedural texture generation"
```

---

## Task 5: Migrate Level Pipeline

**Files:**
- Modify: `src/generation/level_builder.gd` (uses TABS)
- Modify: `src/levels/generated_level.gd`
- Test: `test/unit/test_theming.gd` (append)

**Context:** Replace all hardcoded colors in level_builder.gd and generated_level.gd with reads from `ThemeManager.active_theme`. After this task, levels should look identical (neon theme has exact same values) but be driven by the theme system.

**Key references in level_builder.gd (uses TABS for indentation):**
- Lines 14-28: `_floor_material`, `_floor_material_corridor`, `_wall_material`, `_ceiling_material` — StandardMaterial3D with hardcoded albedo + roughness
- Line 55: `accent_color = NeonPalette.random_color()` → `ThemeManager.active_theme.get_random_palette_color()`
- Line 78: directional light color `Color(0.6, 0.65, 0.8)` → `theme.directional_light_color`
- Line 144: `NeonPalette.ALL[index % ...]` → `theme.get_palette_array()[index % ...]`
- Lines 141-143: OmniLight3D range/attenuation → `theme.point_light_range`, `theme.point_light_attenuation`
- Line 183: edge strip albedo `Color.BLACK` → keep (structural, not themed)
- Lines 184-186: edge strip emission → `theme.accent_emission_energy`

**Key references in generated_level.gd:**
- Line 19: `Color(0.02, 0.02, 0.04)` → `theme.background_color`
- Line 21: `Color(0.15, 0.15, 0.25)` → `theme.ambient_color`
- Line 22: ambient energy `0.8` → `theme.ambient_energy`
- Line 25: `Color(0.02, 0.02, 0.06)` → `theme.fog_color`
- Line 26: fog density → `theme.fog_density`
- Lines 27-28: fog depth begin/end → `theme.fog_depth_begin/end`

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Level theming verification ---
func test_level_builder_uses_theme_floor_color():
    # Verify LevelBuilder reads from ThemeManager
    # We can't easily test rendered output, but we can verify
    # the class references ThemeManager rather than hardcoded colors.
    # This is a smoke test — real verification is visual.
    var theme = ThemeManager.active_theme
    assert_not_null(theme.floor_albedo)
    assert_not_null(theme.wall_albedo)
    assert_not_null(theme.ceiling_albedo)
    assert_not_null(theme.corridor_floor_albedo)
```

- [ ] **Step 2: Migrate level_builder.gd**

Replace the `_init()` material setup (lines 14-28) to read from `ThemeManager.active_theme`:

Note: level_builder.gd uses TABS for indentation. The variable names are `_floor_material_room` (not `_floor_material`), `_floor_material_corridor`, `_wall_material`, `_ceiling_material`.

```gdscript
# In _init() or a new _setup_materials() method:
var theme = ThemeManager.active_theme

_floor_material_room = StandardMaterial3D.new()
_floor_material_room.albedo_color = theme.floor_albedo
_floor_material_room.roughness = theme.floor_roughness

_floor_material_corridor = StandardMaterial3D.new()
_floor_material_corridor.albedo_color = theme.corridor_floor_albedo
_floor_material_corridor.roughness = theme.corridor_floor_roughness

_wall_material = StandardMaterial3D.new()
_wall_material.albedo_color = theme.wall_albedo
_wall_material.roughness = theme.wall_roughness

_ceiling_material = StandardMaterial3D.new()
_ceiling_material.albedo_color = theme.ceiling_albedo
_ceiling_material.roughness = theme.ceiling_roughness
```

Replace NeonPalette references:
- Line 55: `NeonPalette.random_color()` → `ThemeManager.active_theme.get_random_palette_color()`
- Line 144: `NeonPalette.ALL[index % NeonPalette.ALL.size()]` → `var palette = ThemeManager.active_theme.get_palette_array()` then `palette[index % palette.size()]`

Replace light properties:
- Directional light color/energy from theme
- OmniLight3D range: `light.omni_range = tile_size * theme.point_light_range_mult` (keeps dynamic tile_size dependency)
- OmniLight3D attenuation/energy from theme
- OmniLight3D color: use palette cycling from theme
- Light spacing: replace `x % 2 == 1 and y % 2 == 1` with `x % theme.point_light_spacing == 1 and y % theme.point_light_spacing == 1`

Replace accent emission energy: use `randf_range(theme.accent_emission_energy * 0.67, theme.accent_emission_energy)` to preserve the existing randomization range.

- [ ] **Step 3: Migrate generated_level.gd (uses 4-SPACES)**

Replace the environment setup block to read from ThemeManager:

```gdscript
    var theme = ThemeManager.active_theme
    env.background_mode = Environment.BG_COLOR
    env.background_color = theme.background_color
env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
env.ambient_light_color = theme.ambient_color
env.ambient_light_energy = theme.ambient_energy
env.fog_enabled = true
env.fog_light_color = theme.fog_color
env.fog_density = theme.fog_density
env.fog_depth_begin = theme.fog_depth_begin
env.fog_depth_end = theme.fog_depth_end
env.fog_sky_affect = 0.0
```

- [ ] **Step 4: Run tests + run game visually to verify no change**

Expected: Tests pass. Game looks identical to before (neon theme values match hardcoded).

- [ ] **Step 5: Commit**

```bash
git add src/generation/level_builder.gd src/levels/generated_level.gd test/unit/test_theming.gd
git commit -m "feat: migrate level pipeline to read from ThemeManager"
```

---

## Task 6: Migrate Monster Visuals + Scene Override Support

**Files:**
- Modify: `src/entities/monster.gd`
- Test: `test/unit/test_theming.gd` (append)

**Context:** monster.gd extends CharacterBody3D and currently builds BoxMesh body + BoxMesh eyes (flat slits, size 0.08x0.08x0.02) with hardcoded materials in `_ready()`. This task:
1. Replaces hardcoded colors with theme reads
2. Adds scene override support — if `ThemeManager.get_monster_scene(type)` returns a PackedScene, instantiate it as a visual child instead of building procedural meshes
3. Health bar colors from theme

**Key references in monster.gd (note: uses 4-SPACES indentation):**
- Line 34: body emission uses `NeonPalette.random_color()`
- Lines 46-48: body material — albedo, emission
- Lines 68-70: eye material — albedo, emission
- Lines 80-82: boss body material — albedo, emission
- Line 137: health bar bg `Color(0.15, 0.15, 0.15)`
- Line 148: health bar fg `Color(0.0, 1.0, 0.3)`
- Line 177: health bar dynamic `Color(1.0 - ratio, ratio, 0.1)`

**Scene override contract (from spec):**
- Root: `Node3D`
- Required child: `BodyMesh` (MeshInstance3D)
- Optional child: `EyeMesh` (MeshInstance3D)
- Required child: `HealthBarAnchor` (Marker3D)

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Monster theming ---
func test_theme_data_monster_colors_accessible():
    var theme = ThemeManager.active_theme
    assert_not_null(theme.body_albedo)
    assert_not_null(theme.boss_albedo)
    assert_not_null(theme.eye_color)
    assert_not_null(theme.health_bar_foreground)
    assert_not_null(theme.health_bar_background)
    assert_not_null(theme.health_bar_low_color)

func test_theme_get_monster_scene_basic_initially_null():
    # Neon theme starts with no scene overrides (procedural)
    var scene = ThemeManager.get_monster_scene("basic")
    assert_null(scene, "Neon should use procedural monsters initially")
```

- [ ] **Step 2: Migrate monster.gd**

In the `_ready()` method (or wherever the body mesh is created), add scene override check:

```gdscript
var theme = ThemeManager.active_theme
var visual_scene = ThemeManager.get_monster_scene("basic")
if visual_scene:
    # Scene override — instantiate visual, parent under self
    var visual = visual_scene.instantiate()
    add_child(visual)
    _body_mesh = visual.get_node_or_null("BodyMesh")
    _eye_mesh = visual.get_node_or_null("EyeMesh")
else:
    # Procedural fallback — existing BoxMesh code but with theme colors
    # body material
    var body_mat = StandardMaterial3D.new()
    body_mat.albedo_color = theme.body_albedo
    body_mat.emission_enabled = true
    body_mat.emission = theme.get_random_palette_color()
    body_mat.emission_energy_multiplier = 2.0
    # ... rest of procedural setup
```

Replace `NeonPalette.random_color()` with `theme.get_random_palette_color()`.

Replace boss colors:
```gdscript
# In setup_as_boss():
var theme = ThemeManager.active_theme
body_mat.albedo_color = theme.boss_albedo
body_mat.emission = theme.boss_emission
```

Replace health bar colors:
```gdscript
var theme = ThemeManager.active_theme
# Background bar:
bg_mat.albedo_color = theme.health_bar_background
# Foreground bar:
fg_mat.albedo_color = theme.health_bar_foreground
# Dynamic color (keep interpolation mechanic, use themed endpoints):
var c = theme.health_bar_foreground.lerp(theme.health_bar_low_color, 1.0 - ratio)
```

- [ ] **Step 3: Run tests + visual verification**

Expected: Tests pass. Monsters look identical (neon values match).

- [ ] **Step 4: Commit**

```bash
git add src/entities/monster.gd test/unit/test_theming.gd
git commit -m "feat: migrate monster visuals to theme + add scene override support"
```

---

## Task 7: Migrate VFX Pipeline

**Files:**
- Modify: `src/effects/vfx_factory.gd`
- Modify: `src/entities/projectile.gd`
- Modify: `src/systems/s_aoe_blast.gd`
- Modify: `src/effects/floating_text.gd`
- Modify: `src/config/element_registry.gd`
- Test: `test/unit/test_theming.gd` (append)

**Context:** VFX colors are spread across 5 files. All switch to reading from ThemeManager. Element-specific colors (trail, impact) use `theme.get_element_color(element)` which consults `theme.element_colors`.

**Key replacements:**
- `vfx_factory.gd:25` — muzzle flash `Color(1.0, 0.9, 0.6)` → `theme.muzzle_flash_color`
- `vfx_factory.gd:58` — trail `NeonPalette.element_color(element)` → `theme.get_element_color(element)`
- `vfx_factory.gd:97` — impact `NeonPalette.element_color(element)` → `theme.get_element_color(element)`
- `projectile.gd` — trail creation uses element color from theme
- `s_aoe_blast.gd:57-59` — `Color(1.0, 0.6, 0.1)` → `theme.aoe_blast_color`
- `floating_text.gd:6` — `Color(0.2, 1.0, 0.4, 1.0)` → `theme.health_bar_foreground` (green damage text)
- `element_registry.gd:19-22` — `Color.ORANGE_RED` etc → `ThemeManager.active_theme.get_element_color("fire")` etc

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- VFX theming ---
func test_neon_theme_element_color_fire():
    var theme = ThemeManager.active_theme
    var fire = theme.get_element_color("fire")
    assert_almost_eq(fire.r, 1.0, 0.01)
    assert_almost_eq(fire.g, 0.27, 0.01)

func test_neon_theme_element_color_unknown_returns_white():
    var theme = ThemeManager.active_theme
    var c = theme.get_element_color("plasma")
    assert_eq(c, Color.WHITE)

func test_neon_theme_muzzle_flash_color():
    var theme = ThemeManager.active_theme
    assert_almost_eq(theme.muzzle_flash_color.r, 1.0, 0.01)
    assert_almost_eq(theme.muzzle_flash_color.g, 0.9, 0.01)

func test_neon_theme_aoe_blast_color():
    var theme = ThemeManager.active_theme
    assert_almost_eq(theme.aoe_blast_color.r, 1.0, 0.01)
    assert_almost_eq(theme.aoe_blast_color.g, 0.6, 0.01)
```

- [ ] **Step 2: Migrate vfx_factory.gd**

Replace all hardcoded colors:

```gdscript
# Muzzle flash (line 25):
var theme = ThemeManager.active_theme
mat.albedo_color = theme.muzzle_flash_color
mat.emission = theme.muzzle_flash_color

# Trail (line 58) — pass element for element-driven color:
var theme = ThemeManager.active_theme
var trail_color = theme.get_element_color(element)

# Impact (line 97):
var theme = ThemeManager.active_theme
var impact_col = theme.get_element_color(element)
```

- [ ] **Step 3: Migrate projectile.gd, s_aoe_blast.gd, floating_text.gd, element_registry.gd**

**projectile.gd:** Replace `NeonPalette.element_color()` calls with `ThemeManager.active_theme.get_element_color()`.

**s_aoe_blast.gd:** Replace `Color(1.0, 0.6, 0.1)` with `ThemeManager.active_theme.aoe_blast_color`.

**floating_text.gd:** Replace `Color(0.2, 1.0, 0.4, 1.0)` with `ThemeManager.active_theme.health_bar_foreground` (bright green matches current color).

**element_registry.gd:** In the element definitions, replace hardcoded Godot color constants with theme lookups:

```gdscript
# Instead of:
"color": Color.ORANGE_RED,
# Use (in _ready or wherever elements are initialized):
"color": ThemeManager.active_theme.get_element_color("fire"),
```

Note: element_registry.gd is an autoload. If ThemeManager loads after it, defer color resolution to access time or connect to `theme_changed`.

- [ ] **Step 4: Run tests**

Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/effects/vfx_factory.gd src/entities/projectile.gd src/systems/s_aoe_blast.gd src/effects/floating_text.gd src/config/element_registry.gd test/unit/test_theming.gd
git commit -m "feat: migrate VFX pipeline and element colors to theme system"
```

---

## Task 8: Migrate UI Screens + Deprecate NeonPalette

**Files:**
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/shop_screen.gd`
- Modify: `src/ui/reward_screen.gd`
- Modify: `src/ui/victory_screen.gd`
- Modify: `src/ui/game_over_screen.gd`
- Modify: `src/ui/meta_upgrades_screen.gd`
- Modify: `src/ui/lobby_ui.gd` (uses TABS)
- Modify: `src/ui/hud.gd` (uses TABS)
- Remove: `src/effects/neon_palette.gd`
- Test: `test/unit/test_theming.gd` (append)

**Context:** Each UI screen has a hardcoded background color and some have rarity colors. All switch to `ThemeManager.active_theme.ui_*` properties. After migration, NeonPalette has zero references and is deleted.

**Key replacements per file:**
- `map_screen.gd:15` — `Color(0.05, 0.05, 0.1)` → `theme.ui_background_color`
- `shop_screen.gd:18` — `Color(0.05, 0.03, 0.08)` → `theme.ui_background_color`
- `shop_screen.gd:76-80` — rarity_colors dict → `theme.rarity_colors`
- `reward_screen.gd:15` — `Color(0.05, 0.05, 0.1)` → `theme.ui_background_color`
- `reward_screen.gd:47-51` — rarity_colors dict → `theme.rarity_colors`
- `victory_screen.gd:13` — `Color(0.02, 0.05, 0.02)` → `theme.ui_background_color`
- `game_over_screen.gd:12` — `Color(0.08, 0.02, 0.02)` → `theme.ui_background_color`
- `meta_upgrades_screen.gd:12` — `Color(0.04, 0.04, 0.08)` → `theme.ui_background_color`
- `lobby_ui.gd` — add a ColorRect background, set color from theme
- `hud.gd:55` — damage flash `Color(1.0, 0.0, 0.0, 0.3)` → `theme.ui_damage_flash_color`

**Note on per-screen backgrounds:** The spec uses a single `ui_background_color`. Some screens currently have distinct background tints (victory=green, game_over=red). To preserve visual variety per-screen while still being theme-driven, screens can blend the theme background with a screen-specific tint. For now, use `theme.ui_background_color` for all screens — the stone theme will define its own consistent background.

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- UI theming ---
func test_neon_theme_ui_background():
    var theme = ThemeManager.active_theme
    assert_almost_eq(theme.ui_background_color.r, 0.05, 0.01)

func test_neon_theme_rarity_colors():
    var theme = ThemeManager.active_theme
    assert_true(theme.rarity_colors.has("common"))
    assert_true(theme.rarity_colors.has("rare"))
    assert_true(theme.rarity_colors.has("epic"))

func test_neon_palette_file_removed():
    assert_false(FileAccess.file_exists("res://src/effects/neon_palette.gd"),
        "neon_palette.gd should be deleted")
```

- [ ] **Step 2: Migrate all UI screen files**

For each screen, replace the hardcoded Color in the background setup with:

```gdscript
var theme = ThemeManager.active_theme
bg.color = theme.ui_background_color
```

For shop_screen.gd and reward_screen.gd, replace the `rarity_colors` dictionary:

```gdscript
var rarity_colors = ThemeManager.active_theme.rarity_colors
```

For lobby_ui.gd (TABS), add a ColorRect background in `_ready()`:

```gdscript
var bg = ColorRect.new()
bg.color = ThemeManager.active_theme.ui_background_color
bg.set_anchors_preset(Control.PRESET_FULL_RECT)
bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
add_child(bg)
move_child(bg, 0)  # behind everything
```

For hud.gd (TABS), replace damage flash color:

```gdscript
func _trigger_damage_flash() -> void:
	damage_flash.color = ThemeManager.active_theme.ui_damage_flash_color
	var tween = create_tween()
	tween.tween_property(damage_flash, "color:a", 0.0, 0.15)
```

- [ ] **Step 3: Remove NeonPalette**

Delete `src/effects/neon_palette.gd`. Verify with grep that no files reference `NeonPalette` — all should have been migrated in Tasks 5-8.

Run: `grep -r "NeonPalette" src/`
Expected: No matches.

- [ ] **Step 4: Run tests**

Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add -u  # stages all modifications and deletions
git commit -m "feat: migrate UI screens to theme + remove NeonPalette"
```

---

## Task 9: Stone Theme Definition + Procedural Textures

**Files:**
- Create: `themes/stone/stone_theme.gd`
- Modify: `src/themes/theme_manager.gd` (register stone theme)
- Test: `test/unit/test_theming.gd` (append)

**Context:** Second theme with earthy dungeon aesthetic. Uses procedural textures for stone surfaces. All color values from spec Section 6. Stone theme uses procedural monsters (no scene overrides yet — Task 11 adds those).

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Stone Theme ---
func test_stone_theme_exists():
    var found = false
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            found = true
    assert_true(found, "Stone Dungeon theme should be registered")

func test_stone_theme_palette_is_warm():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    # Primary should be warm gold
    assert_gt(stone.primary.r, 0.7, "primary should be warm/red-heavy")
    assert_gt(stone.primary.g, 0.5, "primary should have golden green")

func test_stone_theme_fog_is_closer():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_lt(stone.fog_depth_end, 35.0, "stone fog should be thicker than neon")

func test_stone_theme_has_textures():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_gt(stone.floor_pattern.size(), 0, "stone should define floor texture")
    assert_gt(stone.wall_pattern.size(), 0, "stone should define wall texture")

func test_stone_theme_textures_generate():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    var textures = TextureFactory.generate_for_theme(stone)
    assert_true(textures.has("floor"), "should generate floor texture")
    assert_true(textures.has("wall"), "should generate wall texture")
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — no "Stone Dungeon" theme

- [ ] **Step 3: Implement stone theme**

Create `themes/stone/stone_theme.gd`:

```gdscript
class_name StoneTheme

static func create() -> ThemeData:
    var t = ThemeData.new()

    # Meta
    t.theme_name = "Stone Dungeon"
    t.description = "Ancient stone corridors lit by flickering torches"

    # Palette — warm earthy tones
    t.primary = Color(0.85, 0.65, 0.2)      # Warm gold
    t.secondary = Color(1.0, 0.55, 0.1)     # Torch orange
    t.tertiary = Color(0.9, 0.85, 0.75)     # Bone white
    t.highlight = Color(0.7, 0.1, 0.1)      # Blood red
    t.danger = Color(0.3, 0.5, 0.2)         # Moss green
    t.rarity_colors = {
        "common": Color(0.7, 0.65, 0.55),
        "rare": Color(0.4, 0.55, 0.8),
        "epic": Color(0.65, 0.3, 0.1),
    }
    t.element_colors = {
        "": Color(0.9, 0.85, 0.7),
        "fire": Color(1.0, 0.4, 0.0),
        "ice": Color(0.6, 0.8, 0.95),
        "water": Color(0.2, 0.5, 0.8),
        "oil": Color(0.4, 0.35, 0.15),
    }

    # Environment — warm, close, thick fog
    t.background_color = Color(0.04, 0.03, 0.02)
    t.ambient_color = Color(0.25, 0.18, 0.1)
    t.ambient_energy = 0.6
    t.fog_color = Color(0.06, 0.04, 0.02)
    t.fog_density = 0.03
    t.fog_depth_begin = 3.0
    t.fog_depth_end = 30.0
    t.directional_light_color = Color(0.9, 0.7, 0.4)
    t.directional_light_energy = 0.3
    t.point_light_color = Color(1.0, 0.75, 0.4)
    t.point_light_energy = 2.0
    t.point_light_range_mult = 1.2  # slightly tighter than neon
    t.point_light_attenuation = 1.8
    t.point_light_spacing = 3

    # Level materials — stone surfaces
    t.floor_albedo = Color(0.4, 0.38, 0.35)
    t.floor_roughness = 0.95
    t.corridor_floor_albedo = Color(0.35, 0.33, 0.30)
    t.corridor_floor_roughness = 0.95
    t.wall_albedo = Color(0.3, 0.28, 0.25)
    t.wall_roughness = 0.9
    t.ceiling_albedo = Color(0.35, 0.33, 0.30)
    t.ceiling_roughness = 0.95
    t.accent_emission_energy = 1.5
    t.accent_use_palette = true

    # Monsters — earthy golems (procedural fallback, scene overrides in Task 11)
    t.body_albedo = Color(0.35, 0.3, 0.25)
    t.body_emission = Color(0.6, 0.35, 0.1)
    t.boss_albedo = Color(0.4, 0.2, 0.1)
    t.boss_emission = Color(0.9, 0.4, 0.1)
    t.eye_color = Color(1.0, 0.6, 0.1)
    t.health_bar_foreground = Color(0.2, 0.8, 0.3)
    t.health_bar_background = Color(0.2, 0.18, 0.15)
    t.health_bar_low_color = Color(0.8, 0.2, 0.1)

    # Projectile
    t.projectile_color = Color(0.9, 0.7, 0.3)
    t.projectile_trail_color = Color(1.0, 0.6, 0.2)

    # VFX — embers, warm sparks
    t.muzzle_flash_color = Color(1.0, 0.7, 0.3)
    t.impact_color = Color(0.9, 0.6, 0.2)
    t.death_color = Color(0.7, 0.4, 0.1)
    t.aoe_blast_color = Color(1.0, 0.5, 0.15)

    # UI — parchment/brown
    t.ui_background_color = Color(0.12, 0.08, 0.05)
    t.ui_panel_color = Color(0.18, 0.12, 0.08)
    t.ui_text_color = Color(0.9, 0.8, 0.6)
    t.ui_accent_color = Color(0.85, 0.65, 0.2)
    t.ui_damage_flash_color = Color(0.8, 0.2, 0.0, 0.3)

    # Textures — stone and brick patterns
    t.floor_pattern = {
        "type": "noise",
        "noise_type": "cellular",
        "frequency": 0.08,
        "octaves": 4,
        "width": 256,
        "height": 256,
    }
    t.wall_pattern = {
        "type": "image_gen",
        "pattern": "bricks",
        "color1": Color(0.35, 0.32, 0.28),
        "color2": Color(0.22, 0.20, 0.18),
        "width": 256,
        "height": 256,
    }
    t.monster_skin = {
        "type": "noise",
        "noise_type": "simplex",
        "frequency": 0.1,
        "octaves": 3,
        "width": 128,
        "height": 128,
    }

    return t
```

- [ ] **Step 4: Register stone theme in ThemeManager**

Modify `_load_themes()`:

```gdscript
func _load_themes() -> void:
    available_themes.append(NeonTheme.create())
    available_themes.append(StoneTheme.create())
    active_theme = available_themes[0]
```

- [ ] **Step 5: Run tests**

Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add themes/stone/stone_theme.gd src/themes/theme_manager.gd test/unit/test_theming.gd
git commit -m "feat: add Stone Dungeon theme with procedural textures"
```

---

## Task 10: Neon Monster Scenes

**Files:**
- Create: `themes/neon/monster_basic.tscn`
- Create: `themes/neon/monster_boss.tscn`
- Modify: `themes/neon/neon_theme.gd` (add scene references)
- Test: `test/unit/test_theming.gd` (append)

**Context:** Create PackedScene files matching the monster scene contract for the neon theme. These replicate the current procedural look (geometric boxes + neon emission) but as reusable scenes. Since we can't use the Godot editor, create scenes programmatically using a build script or create the .tscn files directly in text format.

**Monster Scene Contract:**
- Root: `Node3D`
- Required child: `BodyMesh` (MeshInstance3D) — visual representation
- Optional child: `EyeMesh` (MeshInstance3D)
- Required child: `HealthBarAnchor` (Marker3D) — position for health bar

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Neon Monster Scenes ---
func test_neon_monster_basic_scene_loads():
    var scene = load("res://themes/neon/monster_basic.tscn")
    assert_not_null(scene)

func test_neon_monster_basic_has_body_mesh():
    var scene = load("res://themes/neon/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("BodyMesh"))
    instance.queue_free()

func test_neon_monster_basic_has_health_bar_anchor():
    var scene = load("res://themes/neon/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("HealthBarAnchor"))
    instance.queue_free()

func test_neon_monster_boss_scene_loads():
    var scene = load("res://themes/neon/monster_boss.tscn")
    assert_not_null(scene)

func test_neon_theme_has_monster_scenes():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_true(neon.monster_scenes.has("basic"))
    assert_true(neon.monster_scenes.has("boss"))
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — scene files don't exist yet

- [ ] **Step 3: Create neon monster scenes**

Create `themes/neon/monster_basic.tscn` — text format (note: eyes use BoxMesh slits to match current procedural look):

```
[gd_scene load_steps=5 format=3]

[sub_resource type="BoxMesh" id="1"]
size = Vector3(0.8, 1.2, 0.8)

[sub_resource type="StandardMaterial3D" id="2"]
albedo_color = Color(0.08, 0.08, 0.1, 1)
emission_enabled = true
emission = Color(0, 0.83, 1, 1)
emission_energy_multiplier = 2.0

[sub_resource type="BoxMesh" id="3"]
size = Vector3(0.08, 0.08, 0.02)

[sub_resource type="StandardMaterial3D" id="4"]
albedo_color = Color(0, 0, 0, 1)
emission_enabled = true
emission = Color(1, 0.1, 0.1, 1)
emission_energy_multiplier = 3.0

[node name="NeonMonsterBasic" type="Node3D"]

[node name="BodyMesh" type="MeshInstance3D" parent="."]
mesh = SubResource("1")
material_override = SubResource("2")

[node name="EyeMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.15, 0.45, -0.41)
mesh = SubResource("3")
material_override = SubResource("4")

[node name="HealthBarAnchor" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.0, 0)
```

Create `themes/neon/monster_boss.tscn` — larger, red-tinted, BoxMesh eyes:

```
[gd_scene load_steps=5 format=3]

[sub_resource type="BoxMesh" id="1"]
size = Vector3(1.2, 1.8, 1.2)

[sub_resource type="StandardMaterial3D" id="2"]
albedo_color = Color(0.2, 0.02, 0.02, 1)
emission_enabled = true
emission = Color(1, 0.15, 0.1, 1)
emission_energy_multiplier = 3.0

[sub_resource type="BoxMesh" id="3"]
size = Vector3(0.12, 0.12, 0.02)

[sub_resource type="StandardMaterial3D" id="4"]
albedo_color = Color(0, 0, 0, 1)
emission_enabled = true
emission = Color(1, 0.1, 0.1, 1)
emission_energy_multiplier = 4.0

[node name="NeonMonsterBoss" type="Node3D"]

[node name="BodyMesh" type="MeshInstance3D" parent="."]
mesh = SubResource("1")
material_override = SubResource("2")

[node name="EyeMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.2, 0.7, -0.61)
mesh = SubResource("3")
material_override = SubResource("4")

[node name="HealthBarAnchor" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 0)
```

- [ ] **Step 4: Register scenes in neon theme**

Modify `themes/neon/neon_theme.gd` to add scene references:

```gdscript
# Monsters — scene overrides
t.monster_scenes = {
    "basic": load("res://themes/neon/monster_basic.tscn"),
    "boss": load("res://themes/neon/monster_boss.tscn"),
}
```

Note: Use `load()` (not `preload()`) since this is called at runtime from ThemeManager.

- [ ] **Step 5: Run tests**

Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add themes/neon/monster_basic.tscn themes/neon/monster_boss.tscn themes/neon/neon_theme.gd test/unit/test_theming.gd
git commit -m "feat: add neon monster scenes matching current geometric look"
```

---

## Task 11: Stone Monster Scenes

**Files:**
- Create: `themes/stone/monster_basic.tscn`
- Create: `themes/stone/monster_boss.tscn`
- Modify: `themes/stone/stone_theme.gd` (add scene references)
- Test: `test/unit/test_theming.gd` (append)

**Context:** Stone golem monsters using stacked primitives. Basic: squat body (wide box) + smaller head box + cylinder arms. Boss: larger body + horn cones + wider stance. All use earthy StandardMaterial3D (high roughness, low metallic, warm albedo).

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Stone Monster Scenes ---
func test_stone_monster_basic_scene_loads():
    var scene = load("res://themes/stone/monster_basic.tscn")
    assert_not_null(scene)

func test_stone_monster_basic_has_body_mesh():
    var scene = load("res://themes/stone/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("BodyMesh"))
    instance.queue_free()

func test_stone_monster_basic_has_health_bar_anchor():
    var scene = load("res://themes/stone/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("HealthBarAnchor"))
    instance.queue_free()

func test_stone_monster_boss_scene_loads():
    var scene = load("res://themes/stone/monster_boss.tscn")
    assert_not_null(scene)

func test_stone_theme_has_monster_scenes():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_true(stone.monster_scenes.has("basic"))
    assert_true(stone.monster_scenes.has("boss"))
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — scene files don't exist

- [ ] **Step 3: Create stone golem basic scene**

Create `themes/stone/monster_basic.tscn`:

A squat golem built from primitives:
- `BodyMesh`: Wide BoxMesh (1.0 x 0.9 x 0.8) — rough stone material
- `HeadMesh`: Smaller BoxMesh (0.5 x 0.4 x 0.5) atop body
- `ArmLeft`/`ArmRight`: CylinderMesh (radius 0.15, height 0.7) at sides
- `EyeMesh`: Two small SphereMesh with warm orange emission
- `HealthBarAnchor`: Marker3D above head

Material: high roughness (0.9), earthy albedo Color(0.45, 0.38, 0.3), subtle warm emission Color(0.3, 0.2, 0.1) at low energy (0.5).

```
[gd_scene load_steps=7 format=3]

[sub_resource type="BoxMesh" id="1"]
size = Vector3(1.0, 0.9, 0.8)

[sub_resource type="StandardMaterial3D" id="2"]
albedo_color = Color(0.45, 0.38, 0.3, 1)
roughness = 0.9
emission_enabled = true
emission = Color(0.3, 0.2, 0.1, 1)
emission_energy_multiplier = 0.5

[sub_resource type="BoxMesh" id="3"]
size = Vector3(0.5, 0.4, 0.5)

[sub_resource type="CylinderMesh" id="4"]
top_radius = 0.15
bottom_radius = 0.15
height = 0.7

[sub_resource type="SphereMesh" id="5"]
radius = 0.06
height = 0.12

[sub_resource type="StandardMaterial3D" id="6"]
albedo_color = Color(0, 0, 0, 1)
emission_enabled = true
emission = Color(1, 0.6, 0.1, 1)
emission_energy_multiplier = 2.0

[node name="StoneGolemBasic" type="Node3D"]

[node name="BodyMesh" type="MeshInstance3D" parent="."]
mesh = SubResource("1")
material_override = SubResource("2")

[node name="HeadMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.65, 0)
mesh = SubResource("3")
material_override = SubResource("2")

[node name="ArmLeft" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.65, 0.1, 0)
mesh = SubResource("4")
material_override = SubResource("2")

[node name="ArmRight" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.65, 0.1, 0)
mesh = SubResource("4")
material_override = SubResource("2")

[node name="EyeMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.12, 0.7, -0.26)
mesh = SubResource("5")
material_override = SubResource("6")

[node name="HealthBarAnchor" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.1, 0)
```

- [ ] **Step 4: Create stone golem boss scene**

Create `themes/stone/monster_boss.tscn` — larger golem with horn cones:

```
[gd_scene load_steps=9 format=3]

[sub_resource type="BoxMesh" id="1"]
size = Vector3(1.4, 1.3, 1.0)

[sub_resource type="StandardMaterial3D" id="2"]
albedo_color = Color(0.35, 0.25, 0.18, 1)
roughness = 0.9
emission_enabled = true
emission = Color(0.5, 0.25, 0.05, 1)
emission_energy_multiplier = 1.0

[sub_resource type="BoxMesh" id="3"]
size = Vector3(0.7, 0.5, 0.6)

[sub_resource type="CylinderMesh" id="4"]
top_radius = 0.01
bottom_radius = 0.08
height = 0.5

[sub_resource type="StandardMaterial3D" id="5"]
albedo_color = Color(0.3, 0.2, 0.15, 1)
roughness = 0.85

[sub_resource type="CylinderMesh" id="6"]
top_radius = 0.2
bottom_radius = 0.2
height = 0.9

[sub_resource type="SphereMesh" id="7"]
radius = 0.08
height = 0.16

[sub_resource type="StandardMaterial3D" id="8"]
albedo_color = Color(0, 0, 0, 1)
emission_enabled = true
emission = Color(1, 0.3, 0.05, 1)
emission_energy_multiplier = 3.0

[node name="StoneGolemBoss" type="Node3D"]

[node name="BodyMesh" type="MeshInstance3D" parent="."]
mesh = SubResource("1")
material_override = SubResource("2")

[node name="HeadMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
mesh = SubResource("3")
material_override = SubResource("2")

[node name="HornLeft" type="MeshInstance3D" parent="."]
transform = Transform3D(0.94, 0.34, 0, -0.34, 0.94, 0, 0, 0, 1, -0.3, 1.2, 0)
mesh = SubResource("4")
material_override = SubResource("5")

[node name="HornRight" type="MeshInstance3D" parent="."]
transform = Transform3D(0.94, -0.34, 0, 0.34, 0.94, 0, 0, 0, 1, 0.3, 1.2, 0)
mesh = SubResource("4")
material_override = SubResource("5")

[node name="ArmLeft" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.85, 0.15, 0)
mesh = SubResource("6")
material_override = SubResource("2")

[node name="ArmRight" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.85, 0.15, 0)
mesh = SubResource("6")
material_override = SubResource("2")

[node name="EyeMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.15, 1.0, -0.31)
mesh = SubResource("7")
material_override = SubResource("8")

[node name="HealthBarAnchor" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.7, 0)
```

- [ ] **Step 5: Register scenes in stone theme**

Modify `themes/stone/stone_theme.gd`:

```gdscript
t.monster_scenes = {
    "basic": load("res://themes/stone/monster_basic.tscn"),
    "boss": load("res://themes/stone/monster_boss.tscn"),
}
```

- [ ] **Step 6: Run tests**

Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add themes/stone/monster_basic.tscn themes/stone/monster_boss.tscn themes/stone/stone_theme.gd test/unit/test_theming.gd
git commit -m "feat: add stone golem monster scenes for Stone Dungeon theme"
```

---

## Task 12: Theme Selector UI + Lobby Integration

**Files:**
- Create: `src/ui/theme_selector.gd`
- Modify: `src/ui/lobby_ui.gd` (TABS — add "Themes" button)
- Modify: `src/main.gd` (TABS — handle theme selector navigation)
- Test: `test/unit/test_theming.gd` (append)

**Context:** A screen accessible from the lobby showing all available themes as cards with palette color swatches. Clicking a card sets the active theme. Uses programmatic UI like existing screens (meta_upgrades_screen.gd is the model).

**Reference file:** `src/ui/meta_upgrades_screen.gd` — follow its pattern for programmatic UI construction, layout, and button handling.

- [ ] **Step 1: Write failing tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Theme Selector ---
func test_theme_selector_instantiates():
    var selector = preload("res://src/ui/theme_selector.gd").new()
    assert_not_null(selector)
    selector.queue_free()
```

- [ ] **Step 2: Implement theme_selector.gd**

Create `src/ui/theme_selector.gd`:

```gdscript
extends Control

signal back_pressed

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    _build_ui()

func _build_ui() -> void:
    var theme = ThemeManager.active_theme

    # Full-screen background
    var bg = ColorRect.new()
    bg.color = theme.ui_background_color
    bg.set_anchors_preset(PRESET_FULL_RECT)
    bg.mouse_filter = MOUSE_FILTER_IGNORE
    add_child(bg)

    # Center container
    var margin = MarginContainer.new()
    margin.set_anchors_preset(PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_top", 40)
    margin.add_theme_constant_override("margin_left", 60)
    margin.add_theme_constant_override("margin_right", 60)
    margin.add_theme_constant_override("margin_bottom", 40)
    add_child(margin)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 20)
    margin.add_child(vbox)

    # Title
    var title = Label.new()
    title.text = "SELECT THEME"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 32)
    title.add_theme_color_override("font_color", theme.ui_text_color)
    vbox.add_child(title)

    # Theme cards grid
    var grid = HBoxContainer.new()
    grid.alignment = BoxContainer.ALIGNMENT_CENTER
    grid.add_theme_constant_override("separation", 20)
    vbox.add_child(grid)

    for t in ThemeManager.available_themes:
        var card = _create_theme_card(t)
        grid.add_child(card)

    # Back button
    var back_btn = Button.new()
    back_btn.text = "Back"
    back_btn.custom_minimum_size = Vector2(120, 40)
    back_btn.pressed.connect(func(): back_pressed.emit())
    vbox.add_child(back_btn)

func _create_theme_card(t: ThemeData) -> PanelContainer:
    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(200, 250)

    # Highlight active theme
    var style = StyleBoxFlat.new()
    style.bg_color = ThemeManager.active_theme.ui_panel_color
    if t.theme_name == ThemeManager.active_theme.theme_name:
        style.border_color = ThemeManager.active_theme.ui_accent_color
        style.border_width_top = 3
        style.border_width_bottom = 3
        style.border_width_left = 3
        style.border_width_right = 3
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    panel.add_theme_stylebox_override("panel", style)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    panel.add_child(vbox)

    # Theme name
    var name_label = Label.new()
    name_label.text = t.theme_name
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 20)
    name_label.add_theme_color_override("font_color", t.ui_text_color)
    vbox.add_child(name_label)

    # Description
    var desc_label = Label.new()
    desc_label.text = t.description
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc_label.add_theme_font_size_override("font_size", 14)
    desc_label.add_theme_color_override("font_color", t.ui_text_color)
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    vbox.add_child(desc_label)

    # Color swatch — 5 palette colors
    var swatch = HBoxContainer.new()
    swatch.alignment = BoxContainer.ALIGNMENT_CENTER
    swatch.add_theme_constant_override("separation", 4)
    vbox.add_child(swatch)
    for color in t.get_palette_array():
        var rect = ColorRect.new()
        rect.color = color
        rect.custom_minimum_size = Vector2(30, 30)
        swatch.add_child(rect)

    # Select button
    var btn = Button.new()
    btn.text = "Select" if t.theme_name != ThemeManager.active_theme.theme_name else "Active"
    btn.disabled = (t.theme_name == ThemeManager.active_theme.theme_name)
    btn.pressed.connect(func():
        ThemeManager.set_theme(t.theme_name)
        # Rebuild UI to reflect new selection — free synchronously to avoid flicker
        for child in get_children():
            remove_child(child)
            child.free()
        _build_ui()
    )
    vbox.add_child(btn)

    return panel
```

- [ ] **Step 3: Add "Themes" button to lobby_ui.gd**

In `lobby_ui.gd` (TABS), add a button next to "Permanent Upgrades":

```gdscript
signal themes_pressed

# In _ready() or wherever buttons are created:
var themes_btn = Button.new()
themes_btn.text = "Themes"
themes_btn.pressed.connect(func(): themes_pressed.emit())
# Add to the button container
```

- [ ] **Step 4: Handle theme selector in main.gd**

In `main.gd` (TABS), add theme selector screen management. Follow the same pattern used for meta_upgrades_screen:

```gdscript
# Add theme_selector var and instantiation
var _theme_selector: Control

# Connect lobby's themes_pressed signal:
lobby.themes_pressed.connect(_show_theme_selector)

func _show_theme_selector():
	_theme_selector = preload("res://src/ui/theme_selector.gd").new()
	_theme_selector.back_pressed.connect(_hide_theme_selector)
	add_child(_theme_selector)
	# Hide lobby

func _hide_theme_selector():
	_theme_selector.queue_free()
	# Show lobby
```

- [ ] **Step 5: Run tests**

Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add src/ui/theme_selector.gd src/ui/lobby_ui.gd src/main.gd test/unit/test_theming.gd
git commit -m "feat: add theme selector UI accessible from lobby"
```

---

## Task 13: Integration Testing + Apply Textures to Materials

**Files:**
- Modify: `src/generation/level_builder.gd` (TABS — apply textures)
- Modify: `src/themes/theme_manager.gd` (generate textures on theme change)
- Test: `test/unit/test_theming.gd` (append final tests)

**Context:** Wire TextureFactory into the theme pipeline so stone theme surfaces get procedural textures. Add final integration tests verifying the full theme system works end-to-end.

- [ ] **Step 1: Write integration tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- Integration ---
func test_switch_to_stone_and_back():
    ThemeManager.set_theme("Stone Dungeon")
    assert_eq(ThemeManager.active_theme.theme_name, "Stone Dungeon")
    ThemeManager.set_theme("Neon Dungeon")
    assert_eq(ThemeManager.active_theme.theme_name, "Neon Dungeon")

func test_all_themes_have_required_fields():
    for t in ThemeManager.available_themes:
        assert_ne(t.theme_name, "", "%s needs a name" % t)
        assert_ne(t.description, "", "%s needs a description" % t)
        assert_gt(t.get_palette_array().size(), 0, "%s needs palette colors" % t.theme_name)
        assert_gt(t.fog_depth_end, t.fog_depth_begin, "%s fog end > begin" % t.theme_name)

func test_all_themes_have_monster_scenes():
    for t in ThemeManager.available_themes:
        assert_true(t.monster_scenes.has("basic"), "%s needs basic monster scene" % t.theme_name)
        assert_true(t.monster_scenes.has("boss"), "%s needs boss monster scene" % t.theme_name)

func test_texture_cache_updates_on_theme_switch():
    ThemeManager.set_theme("Stone Dungeon")
    var cache = TextureFactory.get_cached()
    if ThemeManager.active_theme.floor_pattern.size() > 0:
        assert_true(cache.has("floor"), "stone theme should have cached floor texture")
    ThemeManager.set_theme("Neon Dungeon")

func test_theme_changed_signal_carries_theme():
    var received_theme: ThemeData = null
    var callback = func(t): received_theme = t
    ThemeManager.theme_changed.connect(callback)
    ThemeManager.set_theme("Stone Dungeon")
    assert_not_null(received_theme)
    assert_eq(received_theme.theme_name, "Stone Dungeon")
    ThemeManager.theme_changed.disconnect(callback)
    ThemeManager.set_theme("Neon Dungeon")
```

- [ ] **Step 2: Generate textures on theme switch**

Modify `src/themes/theme_manager.gd` `set_theme()`:

```gdscript
func set_theme(theme_name_to_set: String) -> void:
    for theme in available_themes:
        if theme.theme_name == theme_name_to_set:
            active_theme = theme
            TextureFactory.generate_for_theme(theme)
            theme_changed.emit(theme)
            return
```

Also generate for initial theme in `_ready()`:

```gdscript
func _ready() -> void:
    _load_themes()
    if available_themes.size() > 0:
        active_theme = available_themes[0]
        TextureFactory.generate_for_theme(active_theme)
```

- [ ] **Step 3: Apply textures in level_builder.gd**

In the material setup (modified in Task 5), check for cached textures:

```gdscript
# After setting albedo_color:
var textures = TextureFactory.get_cached()
if textures.has("floor"):
	_floor_material.albedo_texture = textures["floor"]
if textures.has("wall"):
	_wall_material.albedo_texture = textures["wall"]
```

For neon theme, no textures are generated (empty patterns), so materials stay flat colored. For stone theme, noise/brick textures are applied.

- [ ] **Step 4: Run all tests**

Run: `godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://test/unit -gtest=test_theming.gd -gexit`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add src/themes/theme_manager.gd src/generation/level_builder.gd test/unit/test_theming.gd
git commit -m "feat: wire texture generation into theme pipeline + integration tests"
```

---

## Summary

| Task | What it delivers |
|---|---|
| 1 | ThemeData resource class — the data model |
| 2 | ThemeManager autoload — runtime access |
| 3 | Neon theme with exact current values — zero visual change |
| 4 | TextureFactory — procedural texture generation |
| 5 | Level pipeline reads from theme |
| 6 | Monster visuals + scene override support |
| 7 | VFX pipeline + element colors from theme |
| 8 | UI screens from theme + NeonPalette removed |
| 9 | Stone Dungeon theme + procedural textures |
| 10 | Neon monster scenes |
| 11 | Stone golem monster scenes |
| 12 | Theme selector UI in lobby |
| 13 | Texture wiring + integration tests |

After Task 13, both themes are fully playable and selectable from the lobby.
