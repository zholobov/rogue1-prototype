# Level Generator Playground — Design Spec

## Goal

Add a standalone screen accessible from the lobby where the user can edit all generation parameters, run the WFC generator, and view the result as a 2D grid schematic or a 3D orthographic preview. Also introduce a reusable `ConfigEditor` component for building property-editing UIs from any target object — to be reused by the universal config editor (task #5).

## Scope

Solo development/debug tool. No multiplayer, no ECS, no gameplay. Pure visualization and parameter tuning. Accessed from lobby via button, returns to lobby via back button.

---

## 1. ConfigEditor — Reusable Parameter Editor Component

### Purpose

A scrollable, categorized property editor that builds UI controls from structured section/property Dictionaries. Designed for reuse: the playground embeds one instance, and the future universal config editor (task #5) will embed multiple instances targeting different objects.

### Class: `ConfigEditor extends ScrollContainer`

File: `src/ui/config_editor.gd` (4-space indentation, `class_name ConfigEditor`)

### Setup API

```gdscript
func setup(sections: Array[Dictionary]) -> void
```

Each section Dictionary has the shape:
```gdscript
{
    "title": "Grid",                # Section header
    "properties": [                 # Array of property Dictionaries
        {
            "label": "Width",       # Display name
            "key": "level_grid_width",  # Identifier for signals
            "type": "int",          # "int", "float", "bool", "string_enum", "color"
            "value": 12,            # Current value
            "min_value": 4,         # For int/float
            "max_value": 32,        # For int/float
            "step": 1,             # For float (default 0.01)
            "options": [],          # For string_enum — PackedStringArray of choices
        },
    ]
}
```

### Control Mapping

| Property type | Control | Details |
|---|---|---|
| `int` | SpinBox | min/max/step=1 |
| `float` | SpinBox | min/max/step (default 0.01), 2 decimal places |
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

### Signals

```gdscript
signal property_changed(key: String, value: Variant)
```

Emitted on every control value change.

### Public Methods

```gdscript
func get_values() -> Dictionary
```

Returns `{ key: current_value }` for all properties across all sections. The playground calls this when generating.

```gdscript
func set_property_value(key: String, value: Variant) -> void
```

Programmatically updates a control's value (e.g., to reset tile weights when modifier changes). Does NOT emit `property_changed` to avoid loops.

### Theming

Reads colors from `ThemeManager.active_theme`: `ui_background_color`, `ui_panel_color`, `ui_text_color`, `ui_accent_color`. Listens to `ThemeManager.theme_changed` to reapply.

---

## 2. LevelPlayground — Standalone Screen

### Class: `LevelPlayground extends Control`

File: `src/ui/level_playground.gd` (4-space indentation, `class_name LevelPlayground`)

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

All UI built procedurally in `_build_ui()` — no `.tscn` file needed. Follows the same pattern as `theme_selector.gd`.

### Parameter Sections

The playground sets up ConfigEditor with these sections, reading initial values from `Config` and `ThemeManager.active_theme`:

**Grid:**
- `level_grid_width` (int, 4–32, default `Config.level_grid_width`)
- `level_grid_height` (int, 4–32, default `Config.level_grid_height`)
- `level_seed` (int, 0–999999, default `Config.level_seed`)
- `level_tile_size` (float, 1.0–10.0, default `Config.level_tile_size`)

**Modifier:**
- `current_modifier` (string_enum: normal, dense, large, dark, horde, boss; default `Config.current_modifier`)

**Tile Weights (6 floats):**

Tile weight keys use TileRules internal names: `room`, `spawn`, `cor`, `door`, `wall`, `empty`. Labels displayed to the user are human-readable: "Room", "Spawn", "Corridor", "Door", "Wall", "Empty".

- `w_room` (float, 0.0–10.0, default from `TileRules.get_profile_weights(modifier)`)
- `w_spawn` (float, 0.0–10.0)
- `w_cor` (float, 0.0–10.0)
- `w_door` (float, 0.0–10.0)
- `w_wall` (float, 0.0–10.0)
- `w_empty` (float, 0.0–10.0)

When the modifier dropdown changes, the playground calls `TileRules.get_profile_weights(new_modifier)` and uses `ConfigEditor.set_property_value()` to update all 6 weight spinboxes to the profile defaults.

**Monsters:**
- `monsters_per_room` (int, 0–10, default `Config.monsters_per_room`)
- `max_monsters_per_level` (int, 0–50, default `Config.max_monsters_per_level`, where 0 = unlimited)
- `monster_hp_mult` (float, 0.1–10.0, default `Config.monster_hp_mult`)
- `monster_damage_mult` (float, 0.1–10.0, default `Config.monster_damage_mult`)

**Lighting:**
- `light_range_mult` (float, 0.1–5.0, default `Config.light_range_mult`)
- `point_light_spacing` (int, 1–10, default `ThemeManager.active_theme.point_light_spacing`)

**Props:**
- `prop_density` (float, 0.0–1.0, default `ThemeManager.active_theme.prop_density`)
- `pillar_chance` (float, 0.0–1.0, default `ThemeManager.active_theme.pillar_chance`)
- `rubble_chance` (float, 0.0–1.0, default `ThemeManager.active_theme.rubble_chance`)
- `ceiling_beam_spacing` (int, 1–10, default `ThemeManager.active_theme.ceiling_beam_spacing`)
- `room_prop_min` (int, 0–5, default `ThemeManager.active_theme.room_prop_min`)
- `room_prop_max` (int, 0–10, default `ThemeManager.active_theme.room_prop_max`)

### 2D Grid View

An inner class `GridPreview extends Control` defined inside `level_playground.gd` that renders the WFC grid output via `_draw()`.

**Tile color mapping** (hardcoded for debug clarity — not theme-dependent):
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
3. Instantiate `LevelBuilder` lazily (first 3D preview click only — not in `_ready()`, since LevelBuilder._init() constructs materials from ThemeManager and TextureFactory)
4. Call `_level_builder.build(grid, tile_rules, tile_size)` to produce geometry Node3D
5. Add geometry to the SubViewport's scene
6. Add an orthographic `Camera3D` positioned above the grid center:
   - Position: `Vector3(center_x, 50.0, center_z)`
   - Rotation: looking straight down (`-90` degrees on X)
   - Projection: orthographic
   - Size: `max(grid_width, grid_height) * tile_size * 1.1` (fit with small margin)
7. Add a `DirectionalLight3D` for basic visibility
8. Add a `WorldEnvironment` with the active theme's ambient/fog settings

"Back to 2D" frees the SubViewport contents and shows the `_draw()` grid again.

### Generate Flow

1. User edits parameters in ConfigEditor
2. User clicks "Generate" (or "Randomize Seed")
3. Playground calls `_config_editor.get_values()` to read all current values
4. **Seed handling:** If seed value is 0, generate a random seed (`randi() % 999999 + 1`) and update the seed spinbox via `set_property_value("level_seed", new_seed)`. Seed 0 always means "randomize" — it never produces a deterministic result.
5. Construct a local `TileRules` instance and call `setup_profile(modifier)`. Then override individual tile weights from the ConfigEditor values. This avoids mutating the global `Config` or any shared `TileRules` instance.
6. Create a `LevelGenerator` with the local TileRules and call `generate(width, height, seed, tile_size)`
7. Store returned `grid` for 2D view, call `queue_redraw()` on GridPreview
8. If 3D preview was active, rebuild 3D geometry too

"Randomize Seed" picks `randi() % 999999 + 1`, updates the seed SpinBox via `set_property_value()`, then runs generate.

### Stale Indicator

When any parameter changes after a generation, the Generate button text changes to **"Generate *"** (asterisk appended) to indicate the current view doesn't match the parameters. After generating, the button text resets to **"Generate"**. Simple and obvious.

### Error Handling

If `LevelGenerator.generate()` returns an empty grid or a grid with no spawn points:
- 2D view shows the grid as-is (even if all walls — the user can see what happened)
- A red `Label` appears below the visualization: **"Generation produced no walkable area. Try different parameters."**
- The label auto-hides on next successful generation

### State Management

The playground does NOT modify the global `Config` singleton. It works on local copies of all parameters and constructs local `TileRules`/`LevelGenerator` instances. When the user leaves (back button), nothing has changed globally.

---

## 3. Lobby Integration

### lobby_ui.gd

Add signal (procedural button, same pattern as Themes button):
```gdscript
signal playground_pressed()
```

Add "Level Playground" button after the existing "Themes" button. Purely procedural — no `.tscn` changes.

### main.gd

Add handler following the same pattern as themes (uses TABS):
```gdscript
func _on_playground() -> void:
    _clear_current()
    var screen = preload("res://src/ui/level_playground.gd").new()
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
| `src/ui/config_editor.gd` | Reusable categorized property editor component (4-space indent) |
| `src/ui/level_playground.gd` | Standalone playground screen with GridPreview inner class and 3D preview (4-space indent) |

## 5. Modified Files

| File | Changes |
|---|---|
| `src/ui/lobby_ui.gd` | Add "Level Playground" button and `playground_pressed` signal (TABS) |
| `src/main.gd` | Handle playground navigation — show/back (TABS) |
| `src/generation/tile_rules.gd` | Add `static func get_profile_weights(modifier: String) -> Dictionary` to expose weight profiles without mutation (4-space indent) |

## 6. TileRules Change

Currently `setup_profile()` is the only way to set weights, and it mutates the TileRules instance. Add a static read-only method:

```gdscript
static func get_profile_weights(modifier: String) -> Dictionary
```

Returns the weight dictionary for a given modifier without mutating state. Keys match TileRules internals: `room`, `spawn`, `cor`, `door`, `wall`, `empty`. The playground uses this to initialize tile weight spinboxes when the modifier dropdown changes.

The playground also needs to be able to override individual weights after calling `setup_profile()`. `TileRules` already stores weights per-tile in `tiles[name].weight`. After `setup_profile()`, the playground iterates the ConfigEditor weight values and sets `tile_rules.tiles[name].weight = value` directly. No new method needed for this — the `tiles` Dictionary is already public.
