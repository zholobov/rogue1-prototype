# Level Generator Playground — Design Spec

## Goal

Add a standalone screen accessible from the lobby where the user can edit all generation parameters, run the WFC generator, and view the result as a 2D grid schematic or a 3D orthographic preview. Also introduce a reusable `ConfigEditor` component for building property-editing UIs from any target object — to be reused by the universal config editor (task #5).

## Scope

Solo development/debug tool. No multiplayer, no ECS, no gameplay. Pure visualization and parameter tuning. Accessed from lobby via button, returns to lobby via back button.

---

## 1. ConfigEditor — Reusable Parameter Editor Component

### Purpose

A scrollable, categorized property editor that introspects a target and builds UI controls. Designed for reuse: the playground embeds one instance, and the future universal config editor (task #5) will embed multiple instances targeting different objects.

### Class: `ConfigEditor extends ScrollContainer`

### Setup API

```gdscript
func setup(sections: Array[ConfigSection]) -> void
```

**ConfigSection** is a simple inner class or Dictionary:
```gdscript
class ConfigSection:
    var title: String           # e.g., "Grid", "Tile Weights"
    var properties: Array       # Array of ConfigProperty

class ConfigProperty:
    var label: String           # Display name, e.g., "Width"
    var key: String             # Identifier for signal, e.g., "level_grid_width"
    var type: String            # "int", "float", "bool", "string_enum", "color"
    var value: Variant          # Current value
    var min_value: Variant      # For int/float
    var max_value: Variant      # For int/float
    var step: Variant           # For float (default 0.01)
    var options: PackedStringArray  # For string_enum
```

### Control Mapping

| Property type | Control | Details |
|---|---|---|
| `int` | SpinBox | min/max/step=1 |
| `float` | SpinBox | min/max/step=0.01, 2 decimal places |
| `bool` | CheckButton | on/off |
| `string_enum` | OptionButton | options array |
| `color` | ColorPickerButton | inline swatch |

### Layout

```
VBoxContainer (inside ScrollContainer)
  ├─ Section "Grid" (collapsible)
  │   ├─ HBox: Label "Width"  + SpinBox
  │   ├─ HBox: Label "Height" + SpinBox
  │   └─ ...
  ├─ Section "Tile Weights" (collapsible)
  │   ├─ HBox: Label "room"   + SpinBox
  │   └─ ...
  └─ ...
```

Each section has a clickable header (Button styled as label) that toggles the VBoxContainer of properties below it.

### Signal

```gdscript
signal property_changed(key: String, value: Variant)
```

Emitted on every control value change. The playground connects to this to know when to mark the current view as stale.

### Theming

Reads colors from `ThemeManager.active_theme`: `ui_background_color`, `ui_panel_color`, `ui_text_color`, `ui_accent_color`. Listens to `ThemeManager.theme_changed` to reapply.

---

## 2. LevelPlayground — Standalone Screen

### Class: `LevelPlayground extends Control`

### Signal

```gdscript
signal back_pressed()
```

### Layout (split panel)

```
┌──────────────────────────────────────────────────────┐
│ LEVEL GENERATOR PLAYGROUND                   [Back]  │
├────────────────┬─────────────────────────────────────┤
│  ConfigEditor  │                                     │
│  (left, 300px) │      Visualization Area             │
│                │      (right, fill)                  │
│                │                                     │
│                │   2D: _draw() grid schematic        │
│                │   OR                                │
│                │   3D: SubViewport + ortho camera    │
│                │                                     │
│                │                                     │
│                │                                     │
│                │                                     │
├────────────────┤                                     │
│ [Generate]     │                                     │
│ [Random Seed]  ├─────────────────────────────────────┤
│                │ [Preview 3D]  [Back to 2D]          │
└────────────────┴─────────────────────────────────────┘
```

- Left panel: `ConfigEditor` instance (300px wide) + action buttons at bottom
- Right panel: visualization area that switches between 2D and 3D modes

### Parameter Sections

The playground sets up ConfigEditor with these sections, reading initial values from `Config` and `TileRules`/`ThemeManager.active_theme`:

**Grid:**
- `level_grid_width` (int, 4–32, default 12)
- `level_grid_height` (int, 4–32, default 12)
- `level_seed` (int, 0–999999, default 0, where 0 = random)
- `level_tile_size` (float, 1.0–10.0, default 4.0)

**Modifier:**
- `current_modifier` (string_enum: normal, dense, large, dark, horde, boss)

**Tile Weights (6 floats):**
- `room` (float, 0.0–10.0)
- `spawn` (float, 0.0–10.0)
- `corridor` (float, 0.0–10.0)
- `door` (float, 0.0–10.0)
- `wall` (float, 0.0–10.0)
- `empty` (float, 0.0–10.0)

Tile weights initialize from `TileRules.get_weights()` for the current modifier. When modifier changes, weights reset to that modifier's defaults.

**Monsters:**
- `monsters_per_room` (int, 0–10, default 1)
- `max_monsters_per_level` (int, 0–50, default 5, where 0 = unlimited)
- `monster_hp_mult` (float, 0.1–10.0, default 1.0)
- `monster_damage_mult` (float, 0.1–10.0, default 1.0)

**Lighting:**
- `light_range_mult` (float, 0.1–5.0, default 1.0)
- `point_light_spacing` (int, 1–10, default from theme)

**Props:**
- `prop_density` (float, 0.0–1.0, default from theme)
- `pillar_chance` (float, 0.0–1.0)
- `rubble_chance` (float, 0.0–1.0)
- `ceiling_beam_spacing` (int, 1–10)
- `room_prop_min` (int, 0–5)
- `room_prop_max` (int, 0–10)

### 2D Grid View

A custom `Control` node that renders the WFC grid output via `_draw()`.

**Tile color mapping** (from theme where possible, fallback to distinct colors):
- `room` → green `Color(0.2, 0.6, 0.2)`
- `spawn` → cyan `Color(0.2, 0.7, 0.7)`
- `corridor_h`, `corridor_v` → yellow `Color(0.7, 0.65, 0.2)`
- `door` → orange `Color(0.8, 0.5, 0.15)`
- `wall` → dark gray `Color(0.2, 0.2, 0.2)`
- `empty` → black `Color(0.05, 0.05, 0.05)`

**Scaling:** Cell size = `min(available_width / grid_width, available_height / grid_height)`. Grid centered in the available area.

**Legend:** Small colored rectangles + labels in the top-right corner of the visualization area.

**Grid lines:** 1px lines between cells at `Color(1, 1, 1, 0.1)` for readability.

### 3D Preview

When "Preview 3D" is pressed:

1. Create a `SubViewportContainer` filling the right panel
2. Inside it, a `SubViewport` with its own `World3D`
3. Run `LevelBuilder.build(grid, tile_rules, tile_size)` to produce geometry
4. Add geometry to the SubViewport's scene
5. Add an orthographic `Camera3D` positioned above the grid center:
   - Position: `Vector3(center_x, 50.0, center_z)`
   - Rotation: looking straight down (`-90` degrees on X)
   - Projection: orthographic
   - Size: `max(grid_width, grid_height) * tile_size * 0.6` (to fit with margin)
6. Add a `DirectionalLight3D` for basic visibility
7. Add a `WorldEnvironment` with the active theme's ambient/fog settings

"Back to 2D" frees the SubViewport and shows the `_draw()` grid again.

### Generate Flow

1. User edits parameters in ConfigEditor
2. User clicks "Generate" (or "Randomize Seed")
3. Playground reads all current values from ConfigEditor
4. Applies values to Config/TileRules temporarily (does NOT persist — playground values are local)
5. Creates `LevelGenerator` and calls `generate(width, height, seed, tile_size)`
6. Stores returned `grid` for 2D view, calls `queue_redraw()`
7. If 3D preview was active, rebuilds 3D geometry too

"Randomize Seed" picks `randi() % 999999 + 1`, updates the seed SpinBox, then runs generate.

### State Management

The playground does NOT modify the global `Config` singleton permanently. It works on local copies of parameters. When the user leaves (back button), all values revert to what Config had before.

---

## 3. Lobby Integration

### lobby_ui.gd

Add signal:
```gdscript
signal playground_pressed()
```

Add "Level Playground" button after the existing "Themes" button.

### main.gd

Add handler following the same pattern as themes:
```gdscript
func _on_playground() -> void:
    _clear_current()
    var screen = LevelPlayground.new()
    screen.back_pressed.connect(_on_playground_back)
    add_child(screen)
    current_scene = screen

func _on_playground_back() -> void:
    _clear_current()
    _show_lobby()
```

Connect `lobby.playground_pressed` in `_show_lobby()`.

---

## 4. New Files

| File | Responsibility |
|---|---|
| `src/ui/config_editor.gd` | Reusable categorized property editor component |
| `src/ui/level_playground.gd` | Standalone playground screen with 2D/3D visualization |

## 5. Modified Files

| File | Changes |
|---|---|
| `src/ui/lobby_ui.gd` | Add "Level Playground" button and `playground_pressed` signal |
| `src/main.gd` | Handle playground navigation (show/back) |
| `src/generation/tile_rules.gd` | Add `get_weights(modifier: String) -> Dictionary` public method to expose weight profiles |

## 6. TileRules Change

Currently `setup_profile()` is the only way to set weights, and it mutates the TileRules instance. Add a static read-only method:

```gdscript
static func get_profile_weights(modifier: String) -> Dictionary
```

Returns the weight dictionary for a given modifier without mutating state. The playground uses this to initialize the tile weight spinboxes when the modifier dropdown changes.
