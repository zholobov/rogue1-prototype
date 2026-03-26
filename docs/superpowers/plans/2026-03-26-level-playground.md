# Level Generator Playground Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standalone level generator playground screen with a reusable config editor, 2D grid visualization, and 3D orthographic preview — accessible from the lobby.

**Architecture:** Two new files: `ConfigEditor` (reusable scrollable property editor) and `LevelPlayground` (standalone screen with split-panel layout). The playground constructs local `TileRules`/`LevelGenerator` instances to avoid global state mutation. `TileRules` gets a new static method to expose weight profiles. Lobby and Main get wired following the existing Themes/Upgrades pattern.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS framework (not used in playground), GUT for unit tests

**Spec:** `docs/superpowers/specs/2026-03-26-level-playground-design.md`

**Indentation rules:**
- 4-SPACES: `config_editor.gd`, `level_playground.gd`, `tile_rules.gd`, test files
- TABS: `main.gd`, `lobby_ui.gd`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `src/ui/config_editor.gd` | Reusable categorized property editor — builds controls from Dictionary sections |
| `src/ui/level_playground.gd` | Standalone playground screen with GridPreview inner class and 3D preview |
| `test/unit/test_playground.gd` | GUT tests for ConfigEditor and TileRules.get_profile_weights |

### Modified Files

| File | Changes |
|------|---------|
| `src/generation/tile_rules.gd` | Add `static func get_profile_weights(modifier: String) -> Dictionary` |
| `src/ui/lobby_ui.gd` | Add "Level Playground" button and `playground_pressed` signal |
| `src/main.gd` | Handle playground navigation (show/back) |

---

## Task 1: TileRules.get_profile_weights()

**Files:**
- Modify: `src/generation/tile_rules.gd:7-31`
- Test: `test/unit/test_playground.gd`

- [ ] **Step 1: Create test file with weight profile tests**

Create `test/unit/test_playground.gd`:

```gdscript
extends GutTest

# --- TileRules.get_profile_weights ---

func test_get_profile_weights_normal():
    var w = TileRules.get_profile_weights("normal")
    assert_eq(w.room, 1.5)
    assert_eq(w.spawn, 1.5)
    assert_almost_eq(w.cor, 0.4, 0.001)
    assert_almost_eq(w.door, 0.2, 0.001)
    assert_eq(w.wall, 3.5)
    assert_eq(w.empty, 1.0)

func test_get_profile_weights_dense():
    var w = TileRules.get_profile_weights("dense")
    assert_eq(w.room, 2.5)

func test_get_profile_weights_boss():
    var w = TileRules.get_profile_weights("boss")
    assert_eq(w.room, 3.0)
    assert_almost_eq(w.cor, 0.2, 0.001)

func test_get_profile_weights_unknown_returns_normal():
    var w = TileRules.get_profile_weights("nonexistent")
    assert_eq(w.room, 1.5)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_playground.gd
```

Expected: FAIL — `get_profile_weights` does not exist.

- [ ] **Step 3: Add get_profile_weights to TileRules**

In `src/generation/tile_rules.gd`, add after the `var adjacency_dir` line (line 5), before `func setup_profile`:

```gdscript
static func get_profile_weights(modifier: String) -> Dictionary:
    match modifier:
        "dense":
            return { room = 2.5, spawn = 2.5, cor = 0.3, door = 0.5, wall = 2.0, empty = 0.5 }
        "large":
            return { room = 1.0, spawn = 1.0, cor = 0.8, door = 0.3, wall = 3.0, empty = 1.5 }
        "dark":
            return { room = 0.8, spawn = 0.8, cor = 0.5, door = 0.15, wall = 4.0, empty = 1.5 }
        "horde":
            return { room = 3.0, spawn = 3.0, cor = 0.3, door = 0.6, wall = 2.0, empty = 0.3 }
        "boss":
            return { room = 3.0, spawn = 3.0, cor = 0.2, door = 0.3, wall = 2.5, empty = 0.5 }
        _:
            return { room = 1.5, spawn = 1.5, cor = 0.4, door = 0.2, wall = 3.5, empty = 1.0 }
```

Also refactor `setup_profile` to use it — delete the entire `var w: Dictionary` declaration AND the `match modifier:` block (lines 12–30 inclusive), and replace with this single line:

```gdscript
    var w = TileRules.get_profile_weights(modifier)
```

Lines 31–38 (`add_tile(...)` calls) remain unchanged — they read from `w.room`, `w.spawn`, etc. which match the keys returned by `get_profile_weights()`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_playground.gd
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/generation/tile_rules.gd test/unit/test_playground.gd
git commit -m "feat: add TileRules.get_profile_weights() static method"
```

---

## Task 2: ConfigEditor — Reusable Property Editor

**Files:**
- Create: `src/ui/config_editor.gd`
- Test: `test/unit/test_playground.gd` (append tests)

- [ ] **Step 1: Add ConfigEditor tests**

Append to `test/unit/test_playground.gd`:

```gdscript
# --- ConfigEditor ---

func test_config_editor_get_values():
    var editor = ConfigEditor.new()
    add_child_autofree(editor)
    editor.setup([{
        "title": "Test",
        "properties": [
            {"label": "Width", "key": "width", "type": "int", "value": 12, "min_value": 1, "max_value": 50, "step": 1, "options": []},
            {"label": "Speed", "key": "speed", "type": "float", "value": 1.5, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
        ]
    }])
    var vals = editor.get_values()
    assert_almost_eq(vals["width"], 12.0, 0.001)  # SpinBox.value is always float
    assert_almost_eq(vals["speed"], 1.5, 0.001)

func test_config_editor_set_property_value():
    var editor = ConfigEditor.new()
    add_child_autofree(editor)
    editor.setup([{
        "title": "Test",
        "properties": [
            {"label": "Width", "key": "width", "type": "int", "value": 12, "min_value": 1, "max_value": 50, "step": 1, "options": []},
        ]
    }])
    editor.set_property_value("width", 20)
    var vals = editor.get_values()
    assert_eq(vals["width"], 20)

func test_config_editor_emits_property_changed():
    var editor = ConfigEditor.new()
    add_child_autofree(editor)
    editor.setup([{
        "title": "Test",
        "properties": [
            {"label": "Flag", "key": "flag", "type": "bool", "value": false, "min_value": 0, "max_value": 0, "step": 0, "options": []},
        ]
    }])
    watch_signals(editor)
    # Programmatically toggle the CheckButton to trigger signal
    editor._controls["flag"].button_pressed = true
    assert_signal_emitted(editor, "property_changed")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_playground.gd
```

Expected: FAIL — `ConfigEditor` class not found.

- [ ] **Step 3: Create config_editor.gd**

Create `src/ui/config_editor.gd`:

```gdscript
class_name ConfigEditor
extends ScrollContainer

signal property_changed(key: String, value: Variant)

var _controls: Dictionary = {}  # key -> Control
var _section_containers: Dictionary = {}  # title -> VBoxContainer
var _root_vbox: VBoxContainer
var _suppress_signals: bool = false

func _ready() -> void:
    horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func setup(sections: Array) -> void:
    # Clear existing UI
    for child in get_children():
        child.queue_free()
    _controls.clear()
    _section_containers.clear()

    _root_vbox = VBoxContainer.new()
    _root_vbox.add_theme_constant_override("separation", 4)
    _root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    add_child(_root_vbox)

    for section in sections:
        _build_section(section)

    _apply_theme()
    if ThemeManager:
        ThemeManager.theme_changed.connect(_on_theme_changed)

func get_values() -> Dictionary:
    var result: Dictionary = {}
    for key in _controls:
        var control = _controls[key]
        if control is SpinBox:
            result[key] = control.value
        elif control is CheckButton:
            result[key] = control.button_pressed
        elif control is OptionButton:
            result[key] = control.get_item_text(control.selected)
        elif control is ColorPickerButton:
            result[key] = control.color
    return result

func set_property_value(key: String, value: Variant) -> void:
    if not _controls.has(key):
        return
    _suppress_signals = true
    var control = _controls[key]
    if control is SpinBox:
        control.value = value
    elif control is CheckButton:
        control.button_pressed = value
    elif control is OptionButton:
        for i in range(control.item_count):
            if control.get_item_text(i) == str(value):
                control.selected = i
                break
    elif control is ColorPickerButton:
        control.color = value
    _suppress_signals = false

func _build_section(section: Dictionary) -> void:
    var title = section.get("title", "Section")
    var properties = section.get("properties", [])

    # Section header button
    var header = Button.new()
    header.text = "▼ %s" % title
    header.flat = true
    header.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _root_vbox.add_child(header)

    # Section content
    var content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 2)
    _root_vbox.add_child(content)
    _section_containers[title] = content

    header.pressed.connect(_toggle_section.bind(header, content))

    for prop in properties:
        _build_property(content, prop)

    # Separator
    var sep = HSeparator.new()
    _root_vbox.add_child(sep)

func _build_property(container: VBoxContainer, prop: Dictionary) -> void:
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 8)
    container.add_child(hbox)

    var label = Label.new()
    label.text = prop.get("label", prop.get("key", ""))
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 11)
    hbox.add_child(label)

    var key = prop.get("key", "")
    var type = prop.get("type", "int")
    var value = prop.get("value", 0)

    match type:
        "int":
            var spin = SpinBox.new()
            spin.min_value = prop.get("min_value", 0)
            spin.max_value = prop.get("max_value", 100)
            spin.step = prop.get("step", 1)
            spin.value = value
            spin.custom_minimum_size.x = 80
            spin.value_changed.connect(_on_value_changed.bind(key))
            hbox.add_child(spin)
            _controls[key] = spin

        "float":
            var spin = SpinBox.new()
            spin.min_value = prop.get("min_value", 0.0)
            spin.max_value = prop.get("max_value", 10.0)
            spin.step = prop.get("step", 0.01)
            spin.value = value
            spin.custom_minimum_size.x = 80
            spin.value_changed.connect(_on_value_changed.bind(key))
            hbox.add_child(spin)
            _controls[key] = spin

        "bool":
            var check = CheckButton.new()
            check.button_pressed = value
            check.toggled.connect(_on_bool_changed.bind(key))
            hbox.add_child(check)
            _controls[key] = check

        "string_enum":
            var option = OptionButton.new()
            var options = prop.get("options", [])
            for opt in options:
                option.add_item(opt)
            # Select current value
            for i in range(option.item_count):
                if option.get_item_text(i) == str(value):
                    option.selected = i
                    break
            option.custom_minimum_size.x = 100
            option.item_selected.connect(_on_enum_changed.bind(key, option))
            hbox.add_child(option)
            _controls[key] = option

        "color":
            var picker = ColorPickerButton.new()
            picker.color = value
            picker.custom_minimum_size = Vector2(40, 24)
            picker.color_changed.connect(_on_color_changed.bind(key))
            hbox.add_child(picker)
            _controls[key] = picker

func _on_value_changed(value: float, key: String) -> void:
    if not _suppress_signals:
        property_changed.emit(key, value)

func _on_bool_changed(pressed: bool, key: String) -> void:
    if not _suppress_signals:
        property_changed.emit(key, pressed)

func _on_enum_changed(index: int, key: String, option: OptionButton) -> void:
    if not _suppress_signals:
        property_changed.emit(key, option.get_item_text(index))

func _on_color_changed(color: Color, key: String) -> void:
    if not _suppress_signals:
        property_changed.emit(key, color)

func _toggle_section(header: Button, content: VBoxContainer) -> void:
    content.visible = not content.visible
    var title = header.text.substr(2)  # Remove "▼ " or "▶ "
    header.text = "%s %s" % ["▼" if content.visible else "▶", title]

func _on_theme_changed(_theme: Variant) -> void:
    _apply_theme()

func _apply_theme() -> void:
    if not ThemeManager:
        return
    var theme = ThemeManager.active_theme
    for key in _controls:
        var control = _controls[key]
        if control.get_parent() and control.get_parent().get_child(0) is Label:
            control.get_parent().get_child(0).add_theme_color_override("font_color", theme.ui_text_color)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_playground.gd
```

Expected: All tests PASS (4 previous + 3 new = 7 total).

- [ ] **Step 5: Commit**

```bash
git add src/ui/config_editor.gd test/unit/test_playground.gd
git commit -m "feat: add ConfigEditor reusable property editor component"
```

---

## Task 3: LevelPlayground — 2D Grid View

**Files:**
- Create: `src/ui/level_playground.gd`

- [ ] **Step 1: Create level_playground.gd with 2D grid view**

Create `src/ui/level_playground.gd`:

```gdscript
class_name LevelPlayground
extends Control

signal back_pressed()

var _config_editor: ConfigEditor
var _grid_preview: GridPreview
var _generate_btn: Button
var _error_label: Label
var _preview_3d_btn: Button
var _back_to_2d_btn: Button
var _viewport_container: SubViewportContainer
var _current_grid: Array = []
var _current_params: Dictionary = {}
var _is_3d_mode: bool = false
var _level_builder: LevelBuilder  # Lazy init on first 3D preview
var _stale: bool = false

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    _build_ui()

func _build_ui() -> void:
    var theme = ThemeManager.active_theme

    # Background
    var bg = ColorRect.new()
    bg.color = theme.ui_background_color
    bg.set_anchors_preset(PRESET_FULL_RECT)
    bg.mouse_filter = MOUSE_FILTER_IGNORE
    add_child(bg)

    # Top bar
    var top_bar = HBoxContainer.new()
    top_bar.set_anchors_preset(PRESET_TOP_WIDE)
    top_bar.offset_top = 8
    top_bar.offset_bottom = 36
    top_bar.offset_left = 16
    top_bar.offset_right = -16
    add_child(top_bar)

    var title = Label.new()
    title.text = "LEVEL GENERATOR PLAYGROUND"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", theme.ui_accent_color)
    top_bar.add_child(title)

    var back_btn = Button.new()
    back_btn.text = "Back"
    back_btn.pressed.connect(func(): back_pressed.emit())
    top_bar.add_child(back_btn)

    # Main split: left panel + right panel
    var hsplit = HSplitContainer.new()
    hsplit.anchor_left = 0.0
    hsplit.anchor_top = 0.0
    hsplit.anchor_right = 1.0
    hsplit.anchor_bottom = 1.0
    hsplit.offset_top = 44
    hsplit.offset_left = 8
    hsplit.offset_right = -8
    hsplit.offset_bottom = -8
    hsplit.split_offset = 300
    add_child(hsplit)

    # Left panel: config editor + buttons
    var left_vbox = VBoxContainer.new()
    left_vbox.custom_minimum_size.x = 280
    left_vbox.add_theme_constant_override("separation", 6)
    hsplit.add_child(left_vbox)

    _config_editor = ConfigEditor.new()
    _config_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _config_editor.setup(_build_sections())
    _config_editor.property_changed.connect(_on_property_changed)
    left_vbox.add_child(_config_editor)

    # Action buttons
    var btn_vbox = VBoxContainer.new()
    btn_vbox.add_theme_constant_override("separation", 4)
    left_vbox.add_child(btn_vbox)

    _generate_btn = Button.new()
    _generate_btn.text = "Generate"
    _generate_btn.pressed.connect(_on_generate)
    btn_vbox.add_child(_generate_btn)

    var random_btn = Button.new()
    random_btn.text = "Randomize Seed"
    random_btn.pressed.connect(_on_randomize_seed)
    btn_vbox.add_child(random_btn)

    # Right panel: visualization area
    var right_panel = VBoxContainer.new()
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.add_theme_constant_override("separation", 4)
    hsplit.add_child(right_panel)

    _grid_preview = GridPreview.new()
    _grid_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.add_child(_grid_preview)

    _error_label = Label.new()
    _error_label.text = ""
    _error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    _error_label.add_theme_font_size_override("font_size", 12)
    _error_label.visible = false
    right_panel.add_child(_error_label)

    # Bottom bar for 3D toggle
    var bottom_bar = HBoxContainer.new()
    bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom_bar.add_theme_constant_override("separation", 12)
    right_panel.add_child(bottom_bar)

    _preview_3d_btn = Button.new()
    _preview_3d_btn.text = "Preview 3D"
    _preview_3d_btn.pressed.connect(_on_preview_3d)
    _preview_3d_btn.disabled = true
    bottom_bar.add_child(_preview_3d_btn)

    _back_to_2d_btn = Button.new()
    _back_to_2d_btn.text = "Back to 2D"
    _back_to_2d_btn.pressed.connect(_on_back_to_2d)
    _back_to_2d_btn.visible = false
    bottom_bar.add_child(_back_to_2d_btn)

    # Auto-generate on open
    _on_generate()

func _build_sections() -> Array:
    var theme = ThemeManager.active_theme
    var modifier = Config.current_modifier if Config.current_modifier != "" else "normal"
    var weights = TileRules.get_profile_weights(modifier)

    return [
        {
            "title": "Grid",
            "properties": [
                {"label": "Width", "key": "level_grid_width", "type": "int", "value": Config.level_grid_width, "min_value": 4, "max_value": 32, "step": 1, "options": []},
                {"label": "Height", "key": "level_grid_height", "type": "int", "value": Config.level_grid_height, "min_value": 4, "max_value": 32, "step": 1, "options": []},
                {"label": "Seed (0=random)", "key": "level_seed", "type": "int", "value": Config.level_seed, "min_value": 0, "max_value": 999999, "step": 1, "options": []},
                {"label": "Tile Size", "key": "level_tile_size", "type": "float", "value": Config.level_tile_size, "min_value": 1.0, "max_value": 10.0, "step": 0.5, "options": []},
            ]
        },
        {
            "title": "Modifier",
            "properties": [
                {"label": "Preset", "key": "current_modifier", "type": "string_enum", "value": modifier, "min_value": 0, "max_value": 0, "step": 0, "options": PackedStringArray(["normal", "dense", "large", "dark", "horde", "boss"])},
            ]
        },
        {
            "title": "Tile Weights",
            "properties": [
                {"label": "Room", "key": "w_room", "type": "float", "value": weights.room, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Spawn", "key": "w_spawn", "type": "float", "value": weights.spawn, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Corridor", "key": "w_cor", "type": "float", "value": weights.cor, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Door", "key": "w_door", "type": "float", "value": weights.door, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Wall", "key": "w_wall", "type": "float", "value": weights.wall, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Empty", "key": "w_empty", "type": "float", "value": weights.empty, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
            ]
        },
        {
            "title": "Monsters",
            "properties": [
                {"label": "Per Room", "key": "monsters_per_room", "type": "int", "value": Config.monsters_per_room, "min_value": 0, "max_value": 10, "step": 1, "options": []},
                {"label": "Max/Level (0=∞)", "key": "max_monsters_per_level", "type": "int", "value": Config.max_monsters_per_level, "min_value": 0, "max_value": 50, "step": 1, "options": []},
                {"label": "HP Mult", "key": "monster_hp_mult", "type": "float", "value": Config.monster_hp_mult, "min_value": 0.1, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Damage Mult", "key": "monster_damage_mult", "type": "float", "value": Config.monster_damage_mult, "min_value": 0.1, "max_value": 10.0, "step": 0.1, "options": []},
            ]
        },
        {
            "title": "Lighting",
            "properties": [
                {"label": "Range Mult", "key": "light_range_mult", "type": "float", "value": Config.light_range_mult, "min_value": 0.1, "max_value": 5.0, "step": 0.1, "options": []},
                {"label": "Spacing", "key": "point_light_spacing", "type": "int", "value": theme.point_light_spacing, "min_value": 1, "max_value": 10, "step": 1, "options": []},
            ]
        },
        {
            "title": "Props",
            "properties": [
                {"label": "Density", "key": "prop_density", "type": "float", "value": theme.prop_density, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
                {"label": "Pillar Chance", "key": "pillar_chance", "type": "float", "value": theme.pillar_chance, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
                {"label": "Rubble Chance", "key": "rubble_chance", "type": "float", "value": theme.rubble_chance, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
                {"label": "Beam Spacing", "key": "ceiling_beam_spacing", "type": "int", "value": theme.ceiling_beam_spacing, "min_value": 1, "max_value": 10, "step": 1, "options": []},
                {"label": "Prop Min", "key": "room_prop_min", "type": "int", "value": theme.room_prop_min, "min_value": 0, "max_value": 5, "step": 1, "options": []},
                {"label": "Prop Max", "key": "room_prop_max", "type": "int", "value": theme.room_prop_max, "min_value": 0, "max_value": 10, "step": 1, "options": []},
            ]
        },
    ]

func _on_property_changed(key: String, value: Variant) -> void:
    if not _stale:
        _stale = true
        _generate_btn.text = "Generate *"

    # When modifier changes, reset tile weights to profile defaults
    if key == "current_modifier":
        var weights = TileRules.get_profile_weights(str(value))
        _config_editor.set_property_value("w_room", weights.room)
        _config_editor.set_property_value("w_spawn", weights.spawn)
        _config_editor.set_property_value("w_cor", weights.cor)
        _config_editor.set_property_value("w_door", weights.door)
        _config_editor.set_property_value("w_wall", weights.wall)
        _config_editor.set_property_value("w_empty", weights.empty)

func _on_generate() -> void:
    _current_params = _config_editor.get_values()

    # Seed handling: 0 = random
    var seed_val = int(_current_params.get("level_seed", 0))
    if seed_val == 0:
        seed_val = randi() % 999999 + 1
        _config_editor.set_property_value("level_seed", seed_val)
        _current_params["level_seed"] = seed_val

    var width = int(_current_params.get("level_grid_width", 12))
    var height = int(_current_params.get("level_grid_height", 12))
    var tile_size = float(_current_params.get("level_tile_size", 4.0))

    # Build local TileRules with custom weights
    var modifier = str(_current_params.get("current_modifier", "normal"))
    var rules = TileRules.new()
    rules.setup_profile(modifier)
    # Override individual tile weights
    var weight_keys = {"w_room": "room", "w_spawn": "spawn", "w_cor": "corridor_h", "w_door": "door", "w_wall": "wall", "w_empty": "empty"}
    for w_key in weight_keys:
        var tile_name = weight_keys[w_key]
        if _current_params.has(w_key) and rules.tiles.has(tile_name):
            rules.tiles[tile_name].weight = float(_current_params[w_key])
    # corridor_v uses same weight as corridor_h (both from "cor")
    if _current_params.has("w_cor") and rules.tiles.has("corridor_v"):
        rules.tiles["corridor_v"].weight = float(_current_params["w_cor"])

    # Run generation using local TileRules — bypass LevelGenerator to avoid Config mutation
    var solver = WFCSolver.new()
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_val

    var pinned = _generate_room_seeds(rng, width, height, modifier)
    var grid = solver.solve(rules, width, height, seed_val, pinned)

    # Post-processing — mirrors LevelGenerator pipeline (all 4 steps)
    _ensure_connectivity(grid)
    _remove_tiny_rooms(grid)
    _prune_dead_ends(grid)
    _seal_empty_borders(grid)
    _current_grid = grid

    # Check for empty/bad generation
    var has_walkable = false
    for row in grid:
        for cell in row:
            if cell in ["room", "spawn", "corridor_h", "corridor_v", "door"]:
                has_walkable = true
                break
        if has_walkable:
            break

    if not has_walkable:
        _error_label.text = "Generation produced no walkable area. Try different parameters."
        _error_label.visible = true
    else:
        _error_label.visible = false

    _grid_preview.set_grid(grid)
    _preview_3d_btn.disabled = false
    _stale = false
    _generate_btn.text = "Generate"

    # If 3D mode is active, rebuild
    if _is_3d_mode:
        _rebuild_3d_preview()

func _on_randomize_seed() -> void:
    var new_seed = randi() % 999999 + 1
    _config_editor.set_property_value("level_seed", new_seed)
    _on_generate()

func _on_preview_3d() -> void:
    if _current_grid.is_empty():
        return
    _is_3d_mode = true
    _grid_preview.visible = false
    _preview_3d_btn.visible = false
    _back_to_2d_btn.visible = true
    _rebuild_3d_preview()

func _on_back_to_2d() -> void:
    _is_3d_mode = false
    _grid_preview.visible = true
    _preview_3d_btn.visible = true
    _back_to_2d_btn.visible = false
    if _viewport_container:
        _viewport_container.queue_free()
        _viewport_container = null

func _rebuild_3d_preview() -> void:
    if _viewport_container:
        _viewport_container.queue_free()
        _viewport_container = null

    if _current_grid.is_empty():
        return

    var params = _current_params
    var tile_size = float(params.get("level_tile_size", 4.0))
    var width = _current_grid[0].size() if _current_grid.size() > 0 else 0
    var height_val = _current_grid.size()

    # Lazy init builder
    if not _level_builder:
        _level_builder = LevelBuilder.new()

    # Build local TileRules for builder
    var modifier = str(params.get("current_modifier", "normal"))
    var rules = TileRules.new()
    rules.setup_profile(modifier)

    var geometry = _level_builder.build(_current_grid, rules, tile_size)

    # SubViewport setup
    _viewport_container = SubViewportContainer.new()
    _viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _viewport_container.stretch = true
    _grid_preview.get_parent().add_child(_viewport_container)
    _grid_preview.get_parent().move_child(_viewport_container, 0)

    var viewport = SubViewport.new()
    viewport.own_world_3d = true
    viewport.size = Vector2i(800, 600)
    _viewport_container.add_child(viewport)

    viewport.add_child(geometry)

    # Orthographic camera
    var camera = Camera3D.new()
    var center_x = width * tile_size / 2.0
    var center_z = height_val * tile_size / 2.0
    camera.position = Vector3(center_x, 50.0, center_z)
    camera.rotation_degrees = Vector3(-90, 0, 0)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = max(width, height_val) * tile_size * 1.1
    camera.near = 0.1
    camera.far = 200.0
    viewport.add_child(camera)

    # Directional light
    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-60, 30, 0)
    light.light_energy = 1.5
    viewport.add_child(light)

    # World environment
    var theme = ThemeManager.active_theme
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = theme.background_color
    env.ambient_light_color = theme.ambient_color
    env.ambient_light_energy = theme.ambient_energy
    var world_env = WorldEnvironment.new()
    world_env.environment = env
    viewport.add_child(world_env)

# --- Room seed generation (mirrors LevelGenerator._generate_room_seeds) ---

func _generate_room_seeds(rng: RandomNumberGenerator, width: int, height: int, modifier: String) -> Dictionary:
    var pinned: Dictionary = {}
    var seeds: Array = []

    var room_count: int
    var min_dist: int
    match modifier:
        "dense":
            room_count = rng.randi_range(6, 9)
            min_dist = 3
        "large":
            room_count = rng.randi_range(3, 5)
            min_dist = 5
        "dark":
            room_count = rng.randi_range(5, 8)
            min_dist = 3
        "horde":
            room_count = rng.randi_range(3, 5)
            min_dist = 5
        "boss":
            var cx = width / 2
            var cy = height / 2
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    var px = cx + dx
                    var py = cy + dy
                    if px > 0 and px < width - 1 and py > 0 and py < height - 1:
                        if dx == 0 and dy == 0:
                            pinned[Vector2i(px, py)] = "spawn"
                        else:
                            pinned[Vector2i(px, py)] = "room"
            return pinned
        _:
            room_count = rng.randi_range(4, 7)
            min_dist = 4

    var attempts = 0
    while seeds.size() < room_count and attempts < 100:
        attempts += 1
        var x = rng.randi_range(2, width - 3)
        var y = rng.randi_range(2, height - 3)
        var too_close = false
        for s in seeds:
            if absi(x - s.x) + absi(y - s.y) < min_dist:
                too_close = true
                break
        if too_close:
            continue
        seeds.append(Vector2i(x, y))
        pinned[Vector2i(x, y)] = "spawn"

    return pinned

# --- Post-processing (mirrors LevelGenerator._ensure_connectivity) ---

func _ensure_connectivity(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var visited: Dictionary = {}
    var clusters: Array = []
    var walkable = ["room", "spawn", "corridor_h", "corridor_v", "door"]

    for y in range(h):
        for x in range(w):
            var key = Vector2i(x, y)
            if visited.has(key) or grid[y][x] not in walkable:
                continue
            var cluster: Array = []
            var stack: Array = [key]
            while not stack.is_empty():
                var cell = stack.pop_back()
                if visited.has(cell):
                    continue
                if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h:
                    continue
                if grid[cell.y][cell.x] not in walkable:
                    continue
                visited[cell] = true
                cluster.append(cell)
                stack.append(Vector2i(cell.x + 1, cell.y))
                stack.append(Vector2i(cell.x - 1, cell.y))
                stack.append(Vector2i(cell.x, cell.y + 1))
                stack.append(Vector2i(cell.x, cell.y - 1))
            if cluster.size() > 0:
                clusters.append(cluster)

    if clusters.size() <= 1:
        return
    clusters.sort_custom(func(a, b): return a.size() > b.size())
    var main_cluster = clusters[0]
    for i in range(1, clusters.size()):
        var small = clusters[i]
        var best_dist = 9999
        var best_main = Vector2i.ZERO
        var best_small = Vector2i.ZERO
        for mc in main_cluster:
            for sc in small:
                var dist = absi(mc.x - sc.x) + absi(mc.y - sc.y)
                if dist < best_dist:
                    best_dist = dist
                    best_main = mc
                    best_small = sc
        var cx = best_main.x
        var cy = best_main.y
        while cx != best_small.x:
            cx += 1 if best_small.x > cx else -1
            if cx > 0 and cx < w - 1 and grid[cy][cx] not in walkable:
                grid[cy][cx] = "corridor_h"
        while cy != best_small.y:
            cy += 1 if best_small.y > cy else -1
            if cy > 0 and cy < h - 1 and grid[cy][cx] not in walkable:
                grid[cy][cx] = "corridor_v"
        main_cluster.append_array(small)

func _remove_tiny_rooms(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var visited: Dictionary = {}
    var room_tiles = ["room", "spawn"]
    for y in range(h):
        for x in range(w):
            var key = Vector2i(x, y)
            if visited.has(key) or grid[y][x] not in room_tiles:
                continue
            var cluster: Array = []
            var has_spawn = false
            var stack: Array = [key]
            while not stack.is_empty():
                var cell = stack.pop_back()
                if visited.has(cell):
                    continue
                if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h:
                    continue
                if grid[cell.y][cell.x] not in room_tiles:
                    continue
                visited[cell] = true
                cluster.append(cell)
                if grid[cell.y][cell.x] == "spawn":
                    has_spawn = true
                for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                    stack.append(cell + d)
            if cluster.size() < 4 and not has_spawn:
                for cell in cluster:
                    grid[cell.y][cell.x] = "wall"

func _prune_dead_ends(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var corridor_tiles = ["corridor_h", "corridor_v"]
    var walkable = ["room", "spawn", "corridor_h", "corridor_v", "door"]
    var changed = true
    while changed:
        changed = false
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                if grid[y][x] not in corridor_tiles:
                    continue
                var neighbors = 0
                for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                    if grid[y + d.y][x + d.x] in walkable:
                        neighbors += 1
                if neighbors <= 1:
                    grid[y][x] = "wall"
                    changed = true

func _seal_empty_borders(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var walkable = ["room", "spawn", "corridor_h", "corridor_v", "door"]
    for y in range(h):
        for x in range(w):
            if grid[y][x] != "empty":
                continue
            for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                var nx = x + d.x
                var ny = y + d.y
                if nx >= 0 and nx < w and ny >= 0 and ny < h:
                    if grid[ny][nx] in walkable:
                        grid[y][x] = "wall"
                        break


# ===== GridPreview inner class =====

class GridPreview extends Control:
    var _grid: Array = []

    const TILE_COLORS = {
        "room": Color(0.2, 0.6, 0.2),
        "spawn": Color(0.2, 0.7, 0.7),
        "corridor_h": Color(0.7, 0.65, 0.2),
        "corridor_v": Color(0.7, 0.65, 0.2),
        "door": Color(0.8, 0.5, 0.15),
        "wall": Color(0.2, 0.2, 0.2),
        "empty": Color(0.05, 0.05, 0.05),
    }

    const LEGEND_LABELS = ["room", "spawn", "corridor", "door", "wall", "empty"]
    const LEGEND_KEYS = ["room", "spawn", "corridor_h", "door", "wall", "empty"]

    func set_grid(grid: Array) -> void:
        _grid = grid
        queue_redraw()

    func _draw() -> void:
        if _grid.is_empty():
            return

        var grid_h = _grid.size()
        var grid_w = _grid[0].size() if grid_h > 0 else 0
        if grid_w == 0:
            return

        var avail = size
        var cell_size = minf(avail.x / grid_w, avail.y / grid_h)
        var offset_x = (avail.x - grid_w * cell_size) / 2.0
        var offset_y = (avail.y - grid_h * cell_size) / 2.0

        # Draw tiles
        for y in range(grid_h):
            for x in range(grid_w):
                var tile = _grid[y][x]
                var color = TILE_COLORS.get(tile, Color(0.1, 0.0, 0.1))
                var rect = Rect2(offset_x + x * cell_size, offset_y + y * cell_size, cell_size, cell_size)
                draw_rect(rect, color)

        # Grid lines
        var line_color = Color(1, 1, 1, 0.1)
        for x in range(grid_w + 1):
            var px = offset_x + x * cell_size
            draw_line(Vector2(px, offset_y), Vector2(px, offset_y + grid_h * cell_size), line_color, 1.0)
        for y in range(grid_h + 1):
            var py = offset_y + y * cell_size
            draw_line(Vector2(offset_x, py), Vector2(offset_x + grid_w * cell_size, py), line_color, 1.0)

        # Legend (top-right corner)
        var legend_x = avail.x - 110
        var legend_y = 10.0
        for i in range(LEGEND_LABELS.size()):
            var color = TILE_COLORS.get(LEGEND_KEYS[i], Color.WHITE)
            draw_rect(Rect2(legend_x, legend_y + i * 18, 12, 12), color)
            draw_string(ThemeDB.fallback_font, Vector2(legend_x + 18, legend_y + i * 18 + 11), LEGEND_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
```

- [ ] **Step 2: Verify manually**

The file compiles and runs in the next task when wired to the lobby. For now, verify no syntax errors:

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_playground.gd
```

Expected: Previous tests still pass. LevelPlayground is not yet tested here — it requires scene tree wiring.

- [ ] **Step 3: Commit**

```bash
git add src/ui/level_playground.gd
git commit -m "feat: add LevelPlayground screen with 2D grid view and 3D preview"
```

---

## Task 4: Lobby + Main Wiring

**Files:**
- Modify: `src/ui/lobby_ui.gd:3,45-48`
- Modify: `src/main.gd:42-48`

- [ ] **Step 1: Add playground button to lobby_ui.gd**

In `src/ui/lobby_ui.gd` (TABS), add signal after the existing signals (line 3):

```gdscript
signal playground_pressed()
```

Add the button after the existing themes button block (after line 48):

```gdscript
	var playground_btn = Button.new()
	playground_btn.text = "Level Playground"
	playground_btn.pressed.connect(_on_playground)
	vbox.add_child(playground_btn)
```

Add the handler after `_on_themes()`:

```gdscript
func _on_playground():
	playground_pressed.emit()
```

- [ ] **Step 2: Wire playground in main.gd**

In `src/main.gd` (TABS), connect the signal in `_show_lobby()` after the `lobby.themes_pressed` connection (line 46):

```gdscript
	lobby.playground_pressed.connect(_on_playground)
```

Add the navigation methods after `_on_themes_back()`:

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

- [ ] **Step 3: Verify manually**

Run the game. Verify:
1. Lobby shows "Level Playground" button
2. Clicking it opens the playground screen
3. 2D grid generates automatically on open
4. Changing parameters marks generate button as "Generate *"
5. Clicking "Generate" regenerates the grid
6. "Randomize Seed" picks a new seed and generates
7. "Preview 3D" shows orthographic 3D view of the level
8. "Back to 2D" returns to schematic view
9. "Back" returns to lobby
10. Changing modifier resets tile weight spinboxes

- [ ] **Step 4: Commit**

```bash
git add src/ui/lobby_ui.gd src/main.gd
git commit -m "feat: wire level playground to lobby and main navigation"
```

---

## Task 5: Smoke Tests

**Files:**
- Modify: `test/unit/test_playground.gd`

- [ ] **Step 1: Add smoke test for LevelPlayground**

Append to `test/unit/test_playground.gd`:

```gdscript
# --- LevelPlayground smoke test ---

func test_playground_instantiates():
    var playground = LevelPlayground.new()
    add_child_autofree(playground)
    # Should have built UI without crashing
    assert_not_null(playground)
    assert_true(playground.get_child_count() > 0, "Playground should build UI children")

func test_grid_preview_renders_empty():
    var preview = LevelPlayground.GridPreview.new()
    add_child_autofree(preview)
    preview.set_grid([])
    # Should not crash on empty grid
    assert_not_null(preview)

func test_grid_preview_renders_grid():
    var preview = LevelPlayground.GridPreview.new()
    preview.size = Vector2(200, 200)
    add_child_autofree(preview)
    var grid = [
        ["wall", "wall", "wall"],
        ["wall", "room", "wall"],
        ["wall", "wall", "wall"],
    ]
    preview.set_grid(grid)
    # Should not crash; grid stored
    assert_eq(preview._grid.size(), 3)
```

- [ ] **Step 2: Run all tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_playground.gd
```

Expected: All tests PASS (7 previous + 3 new = 10 total).

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_playground.gd
git commit -m "test: add smoke tests for LevelPlayground and GridPreview"
```
