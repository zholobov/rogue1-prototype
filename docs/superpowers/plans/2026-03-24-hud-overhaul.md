# HUD Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain-text HUD with a themed, game-quality UI featuring crosshair, styled health bar, weapon panel, ability cooldowns, floating damage numbers, kill feed, boss health bar, and minimap.

**Architecture:** All UI built from Godot Control nodes (no assets). A `DamageEvents` autoload singleton decouples damage signals from the HUD. Standalone Controls (`CrosshairManager`, `Minimap`, `AbilityIndicator`) are composed into a rewritten `hud.gd`. All colors sourced from `ThemeData` and re-applied on `theme_changed`.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS, GL Compatibility renderer, GUT testing

**Spec:** `docs/superpowers/specs/2026-03-24-hud-overhaul-design.md`

---

## Indentation Convention

- `src/ui/hud.gd` uses **TABS** (existing file convention).
- All **new files** (`crosshair.gd`, `minimap.gd`, `ability_indicator.gd`, `damage_number_factory.gd`, `damage_events.gd`) use **4 spaces**.

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `src/events/damage_events.gd` | Autoload singleton: `damage_dealt` signal |
| `src/effects/damage_number_factory.gd` | Static helper: create FloatingText with element color |
| `src/ui/crosshair.gd` | CrosshairManager: weapon-specific reticles from ColorRect nodes |
| `src/ui/minimap.gd` | Minimap: `_draw()`-based tile grid + player/monster dots |
| `src/ui/ability_indicator.gd` | AbilityIndicator: circular cooldown via `_draw()` |

### Modified Files
| File | Change |
|------|--------|
| `src/themes/theme_data.gd:91` | Add 4 HUD color properties after `ui_damage_flash_color` |
| `themes/stone/stone_theme.gd:82` | Add stone HUD color overrides |
| `themes/neon/neon_theme.gd:81` | Add neon HUD color overrides |
| `src/effects/floating_text.gd:13` | Random X offset in `show_text()` |
| `src/systems/s_damage.gd:63` | Emit `DamageEvents.damage_dealt` at end of `apply_damage()` |
| `src/ui/hud.gd` | Complete rewrite (TABS) |
| `src/ui/hud.tscn` | Minimal scene — root Control + script only |
| `src/levels/generated_level.gd:76-86,126-134,171` | Store HUD ref, pass level_data/boss, connect signals |
| `project.godot:29` | Register `DamageEvents` autoload |
| `test/unit/test_theming.gd` | Tests for new ThemeData properties |

---

## Context for Implementers

### Key APIs

- **Player entity access** (from HUD `_process`): `get_tree().get_nodes_in_group("players")` → iterate, check `player is PlayerEntity`, then `player.get_component(C_Health)`, `player.get_component(C_Weapon)`, etc. Player weapon index: `player._current_weapon_index` (line 8 of `src/entities/player.gd`).
- **Weapon presets**: `Config.weapon_presets` (lines 17-22 of `src/config/game_config.gd`) — array of dicts: `{name, damage, fire_rate, speed, element}`. Index 0=Pistol, 1=Flamethrower, 2=Ice Rifle, 3=Water Gun.
- **Theme colors**: `ThemeManager.active_theme` is a `ThemeData` resource. Signal: `ThemeManager.theme_changed` (passes ThemeData). Element colors: `theme.get_element_color(element)`.
- **Ability components**: `C_Dash` (`.cooldown`, `.cooldown_remaining`), `C_AoEBlast` (`.cooldown`, `.cooldown_remaining`), `C_Lifesteal` (`.percent`, no cooldown — always "active" when present).
- **Death signal**: `S_Death.actor_died(entity: Entity)` — instance signal on the death system, not global. Connected in `generated_level.gd`.
- **Boss detection**: `entity.get_component(C_BossAI)` returns non-null for boss entities.
- **Level grid**: `level_data["grid"]` is `Array[Array[String]]` indexed `grid[y][x]`. Values: `"room"`, `"spawn"`, `"corridor_h"`, `"corridor_v"`, `"door"`, `"wall"`, `"empty"`. `level_data["width"]` and `level_data["height"]` are grid dimensions.
- **Monster group**: `MonsterEntity` calls `add_to_group("monsters")` (line 31 of `src/entities/monster.gd`).

### Test Runner

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_theming.gd -gexit
```

### Parse Check

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

---

### Task 1: ThemeData HUD Properties

**Files:**
- Modify: `src/themes/theme_data.gd:91`
- Modify: `themes/stone/stone_theme.gd:82`
- Modify: `themes/neon/neon_theme.gd:81`
- Modify: `test/unit/test_theming.gd:268` (fix stale fog assertion)
- Test: `test/unit/test_theming.gd`

- [ ] **Step 1: Write failing tests for new ThemeData properties**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- HUD ThemeData properties ---
func test_theme_data_has_ui_crosshair_color():
    var td = ThemeData.new()
    assert_eq(td.ui_crosshair_color, Color(1.0, 1.0, 1.0))

func test_theme_data_has_ui_minimap_room():
    var td = ThemeData.new()
    assert_almost_eq(td.ui_minimap_room.r, 0.15, 0.01)
    assert_almost_eq(td.ui_minimap_room.g, 0.15, 0.01)
    assert_almost_eq(td.ui_minimap_room.b, 0.2, 0.01)

func test_theme_data_has_ui_minimap_wall():
    var td = ThemeData.new()
    assert_almost_eq(td.ui_minimap_wall.r, 0.3, 0.01)
    assert_almost_eq(td.ui_minimap_wall.g, 0.3, 0.01)
    assert_almost_eq(td.ui_minimap_wall.b, 0.4, 0.01)

func test_theme_data_has_ui_kill_feed_color():
    var td = ThemeData.new()
    assert_eq(td.ui_kill_feed_color, Color(1.0, 1.0, 1.0))

func test_stone_theme_hud_crosshair_color():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_almost_eq(stone.ui_crosshair_color.r, 0.9, 0.01)
    assert_almost_eq(stone.ui_crosshair_color.g, 0.85, 0.01)
    assert_almost_eq(stone.ui_crosshair_color.b, 0.7, 0.01)

func test_stone_theme_hud_minimap_room():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_almost_eq(stone.ui_minimap_room.r, 0.2, 0.01)
    assert_almost_eq(stone.ui_minimap_room.g, 0.18, 0.01)
    assert_almost_eq(stone.ui_minimap_room.b, 0.15, 0.01)

func test_neon_theme_hud_kill_feed_color():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.ui_kill_feed_color.r, 0.0, 0.01)
    assert_almost_eq(neon.ui_kill_feed_color.g, 0.83, 0.01)
    assert_almost_eq(neon.ui_kill_feed_color.b, 1.0, 0.01)

func test_all_themes_have_hud_properties():
    for t in ThemeManager.available_themes:
        assert_ne(t.ui_crosshair_color, Color.BLACK, "%s needs crosshair color" % t.theme_name)
        assert_ne(t.ui_minimap_wall, Color.BLACK, "%s needs minimap wall color" % t.theme_name)
```

Also fix the stale fog assertion at line 268 — stone `fog_depth_end` was changed from 30→45 during lighting tuning:

Replace line 268:
```gdscript
    assert_lt(stone.fog_depth_end, 35.0, "stone fog should be thicker than neon")
```
With:
```gdscript
    assert_lt(stone.fog_depth_end, 50.0, "stone fog should not be infinite")
```

- [ ] **Step 2: Run tests to verify new tests fail**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_theming.gd -gexit
```

Expected: New tests FAIL (properties don't exist). Fog test should now PASS.

- [ ] **Step 3: Add HUD properties to ThemeData**

In `src/themes/theme_data.gd`, after line 90 (`@export var ui_damage_flash_color: Color = Color(1.0, 0.0, 0.0, 0.3)`), add:

```gdscript
@export var ui_crosshair_color: Color = Color(1.0, 1.0, 1.0)
@export var ui_minimap_room: Color = Color(0.15, 0.15, 0.2)
@export var ui_minimap_wall: Color = Color(0.3, 0.3, 0.4)
@export var ui_kill_feed_color: Color = Color(1.0, 1.0, 1.0)
```

- [ ] **Step 4: Add Stone theme HUD overrides**

In `themes/stone/stone_theme.gd`, after line 82 (`t.ui_damage_flash_color = Color(0.8, 0.2, 0.0, 0.3)`), add:

```gdscript
    t.ui_crosshair_color = Color(0.9, 0.85, 0.7)
    t.ui_minimap_room = Color(0.2, 0.18, 0.15)
    t.ui_minimap_wall = Color(0.4, 0.35, 0.3)
    t.ui_kill_feed_color = Color(0.9, 0.75, 0.4)
```

- [ ] **Step 5: Add Neon theme HUD overrides**

In `themes/neon/neon_theme.gd`, after line 81 (`t.ui_damage_flash_color = Color(1.0, 0.0, 0.0, 0.3)`), add:

```gdscript
    t.ui_crosshair_color = Color(1.0, 1.0, 1.0)
    t.ui_minimap_room = Color(0.1, 0.1, 0.2)
    t.ui_minimap_wall = Color(0.2, 0.3, 0.5)
    t.ui_kill_feed_color = Color(0.0, 0.83, 1.0)
```

- [ ] **Step 6: Run tests to verify all pass**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_theming.gd -gexit
```

Expected: ALL PASS (including new HUD property tests and fixed fog test).

- [ ] **Step 7: Commit**

```bash
git add src/themes/theme_data.gd themes/stone/stone_theme.gd themes/neon/neon_theme.gd test/unit/test_theming.gd
git commit -m "feat(hud): add HUD color properties to ThemeData and both themes"
```

---

### Task 2: DamageEvents Autoload + S_Damage Emit

**Files:**
- Create: `src/events/damage_events.gd`
- Modify: `project.godot:29`
- Modify: `src/systems/s_damage.gd:63`

- [ ] **Step 1: Create DamageEvents autoload singleton**

Create `src/events/damage_events.gd` (4-space indentation):

```gdscript
extends Node

signal damage_dealt(position: Vector3, amount: int, element: String)
```

- [ ] **Step 2: Register autoload in project.godot**

In `project.godot`, after line 29 (`MetaSave="*res://src/run/meta_save.gd"`), add:

```ini
DamageEvents="*res://src/events/damage_events.gd"
```

- [ ] **Step 3: Emit signal from S_Damage.apply_damage()**

In `src/systems/s_damage.gd`, after line 62 (the end of the elemental condition block, just before the blank line before `static func _apply_element_to_conditions`), add:

```gdscript
    # Emit damage event for floating numbers
    var parent_body = target_entity.get_parent()
    if parent_body and DamageEvents:
        DamageEvents.damage_dealt.emit(parent_body.global_position, actual_damage, element)
```

This goes inside `apply_damage()`, at the very end before the next static function.

- [ ] **Step 4: Verify Godot parses without errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

Expected: No parse errors.

- [ ] **Step 5: Commit**

```bash
git add src/events/damage_events.gd project.godot src/systems/s_damage.gd
git commit -m "feat(hud): add DamageEvents autoload and emit from S_Damage"
```

---

### Task 3: Floating Damage Numbers

**Files:**
- Modify: `src/effects/floating_text.gd:13`
- Create: `src/effects/damage_number_factory.gd`

- [ ] **Step 1: Add random X offset to FloatingText.show_text()**

In `src/effects/floating_text.gd`, replace line 13:

```gdscript
    global_position = pos + Vector3(0, 1.5, 0)
```

With:

```gdscript
    global_position = pos + Vector3(randf_range(-0.3, 0.3), 1.5, 0)
```

- [ ] **Step 2: Create DamageNumberFactory**

Create `src/effects/damage_number_factory.gd` (4-space indentation):

```gdscript
class_name DamageNumberFactory
extends RefCounted

## Creates a FloatingText with element-colored tint.
## Caller must add_child() first, then call ft.show_text().

static func create(element: String) -> FloatingText:
    var ft = FloatingText.new()
    ft.modulate = ThemeManager.active_theme.get_element_color(element)
    return ft
```

**Usage pattern** (consumer adds to tree, then calls show_text — same as existing kill text in `s_death.gd:20-23`):

```gdscript
var ft = DamageNumberFactory.create(element)
add_child(ft)
ft.show_text(pos, "-%d" % amount)
```

- [ ] **Step 3: Verify Godot parses without errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

- [ ] **Step 4: Commit**

```bash
git add src/effects/floating_text.gd src/effects/damage_number_factory.gd
git commit -m "feat(hud): add DamageNumberFactory and random offset to FloatingText"
```

---

### Task 4: AbilityIndicator Control

**Files:**
- Create: `src/ui/ability_indicator.gd`

- [ ] **Step 1: Create AbilityIndicator custom Control**

Create `src/ui/ability_indicator.gd` (4-space indentation):

```gdscript
class_name AbilityIndicator
extends Control

var ability_name: String = ""
var cooldown_total: float = 0.0
var cooldown_remaining: float = 0.0
var is_active: bool = false

var _label: Label
var _status_label: Label

func _init() -> void:
    custom_minimum_size = Vector2(50, 60)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
    _label = Label.new()
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.position = Vector2(0, 18)
    _label.size = Vector2(50, 16)
    _label.add_theme_font_size_override("font_size", 9)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_label)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.position = Vector2(0, 44)
    _status_label.size = Vector2(50, 14)
    _status_label.add_theme_font_size_override("font_size", 8)
    _status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_status_label)

func setup(p_name: String, p_cooldown: float) -> void:
    ability_name = p_name
    cooldown_total = p_cooldown
    if _label:
        _label.text = p_name

func update_state(p_remaining: float, p_active: bool = false) -> void:
    cooldown_remaining = p_remaining
    is_active = p_active
    _update_status_label()
    queue_redraw()

func apply_theme() -> void:
    var theme = ThemeManager.active_theme
    if _label:
        _label.add_theme_color_override("font_color", theme.ui_text_color)
    _update_status_label()
    queue_redraw()

func _update_status_label() -> void:
    var theme = ThemeManager.active_theme
    if not _status_label:
        return
    if is_active:
        _status_label.text = "ON"
        _status_label.add_theme_color_override("font_color", theme.highlight)
    elif cooldown_remaining <= 0:
        _status_label.text = "READY"
        _status_label.add_theme_color_override("font_color", theme.health_bar_foreground)
    else:
        _status_label.text = "%.1fs" % cooldown_remaining
        _status_label.add_theme_color_override("font_color", theme.ui_text_color)

func _draw() -> void:
    var theme = ThemeManager.active_theme
    var center = Vector2(25, 22)
    var radius = 18.0

    # Background circle fill
    draw_circle(center, radius, theme.ui_panel_color)

    if is_active:
        # Active: highlight border
        draw_arc(center, radius, 0, TAU, 64, theme.highlight, 2.0)
    elif cooldown_remaining <= 0:
        # Ready: accent border
        draw_arc(center, radius, 0, TAU, 64, theme.ui_accent_color, 2.0)
    else:
        # On cooldown: dim border + progress arc
        draw_arc(center, radius, 0, TAU, 64, theme.ui_panel_color.lightened(0.2), 1.5)
        if cooldown_total > 0:
            var progress = 1.0 - (cooldown_remaining / cooldown_total)
            var sweep = progress * TAU
            # Clockwise fill from top (-PI/2)
            draw_arc(center, radius - 3, -PI / 2, -PI / 2 + sweep, 64, Color(theme.ui_accent_color, 0.4), 6.0)

    if _label:
        _label.text = ability_name
```

- [ ] **Step 2: Verify Godot parses without errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add src/ui/ability_indicator.gd
git commit -m "feat(hud): add AbilityIndicator circular cooldown Control"
```

---

### Task 5: CrosshairManager Control

**Files:**
- Create: `src/ui/crosshair.gd`

- [ ] **Step 1: Create CrosshairManager with per-weapon reticles**

Create `src/ui/crosshair.gd` (4-space indentation):

```gdscript
class_name CrosshairManager
extends Control

## Weapon-specific crosshair reticles built from ColorRect nodes.
## Base shapes are white; modulate tints them by element color.

var _current_index: int = -1
var _current_element: String = ""

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    anchor_left = 0.5
    anchor_top = 0.5
    anchor_right = 0.5
    anchor_bottom = 0.5
    offset_left = -30
    offset_top = -30
    offset_right = 30
    offset_bottom = 30

func set_weapon(index: int, element: String) -> void:
    if index == _current_index and element == _current_element:
        return
    _current_index = index
    _current_element = element
    _rebuild()

func apply_theme() -> void:
    _apply_tint()

func _rebuild() -> void:
    for child in get_children():
        child.queue_free()

    match _current_index:
        0: _build_pistol()
        1: _build_flamethrower()
        2: _build_ice_rifle()
        3: _build_water_gun()
        _: _build_pistol()

    _apply_tint()

func _apply_tint() -> void:
    var theme = ThemeManager.active_theme
    if _current_element == "":
        modulate = theme.ui_crosshair_color
    else:
        modulate = theme.get_element_color(_current_element)

# --- Pistol: center dot + 4 lines with gap ---

func _build_pistol() -> void:
    _add_rect(Vector2(28, 28), Vector2(4, 4))   # Center dot
    _add_rect(Vector2(4, 29), Vector2(14, 2))    # Left line
    _add_rect(Vector2(42, 29), Vector2(14, 2))   # Right line
    _add_rect(Vector2(29, 4), Vector2(2, 14))    # Top line
    _add_rect(Vector2(29, 42), Vector2(2, 14))   # Bottom line

# --- Flamethrower: concentric circles + center dot ---

func _build_flamethrower() -> void:
    _add_ring(Vector2(30, 30), 24, 2)   # Outer ring (spray cone)
    _add_ring(Vector2(30, 30), 12, 2)   # Inner ring
    _add_rect(Vector2(28, 28), Vector2(4, 4))  # Center dot

# --- Ice Rifle: sniper cross + corner ticks ---

func _build_ice_rifle() -> void:
    _add_rect(Vector2(0, 29), Vector2(60, 1))    # Full horizontal
    _add_rect(Vector2(29, 0), Vector2(1, 60))    # Full vertical
    # Gap in center (black overlay)
    var gap = ColorRect.new()
    gap.color = Color.BLACK
    gap.position = Vector2(24, 24)
    gap.size = Vector2(12, 12)
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(gap)
    _add_rect(Vector2(28.5, 28.5), Vector2(3, 3))  # Tiny center dot
    # Corner ticks
    _add_rect(Vector2(10, 10), Vector2(8, 1))
    _add_rect(Vector2(42, 10), Vector2(8, 1))
    _add_rect(Vector2(10, 49), Vector2(8, 1))
    _add_rect(Vector2(42, 49), Vector2(8, 1))

# --- Water Gun: scatter dots + dashed circle ---

func _build_water_gun() -> void:
    _add_rect(Vector2(27, 27), Vector2(5, 5))    # Center dot
    _add_rect(Vector2(21, 18), Vector2(3, 3))    # Spray dots
    _add_rect(Vector2(35, 33), Vector2(3, 3))
    _add_rect(Vector2(22, 37), Vector2(3, 3))
    _add_rect(Vector2(37, 20), Vector2(3, 3))
    _add_rect(Vector2(16, 30), Vector2(2, 2))
    _add_rect(Vector2(40, 28), Vector2(2, 2))
    _add_dashed_ring(Vector2(30, 30), 22, 1)     # Outer dashed circle

# --- Helpers ---

func _add_rect(pos: Vector2, rect_size: Vector2) -> void:
    var r = ColorRect.new()
    r.color = Color.WHITE
    r.position = pos
    r.size = rect_size
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(r)

func _add_ring(center: Vector2, radius: float, thickness: float) -> void:
    var segments = 32
    for i in range(segments):
        var angle = (float(i) / segments) * TAU
        var px = center.x + cos(angle) * radius - thickness / 2
        var py = center.y + sin(angle) * radius - thickness / 2
        _add_rect(Vector2(px, py), Vector2(thickness, thickness))

func _add_dashed_ring(center: Vector2, radius: float, thickness: float) -> void:
    var segments = 24
    for i in range(segments):
        if i % 2 == 0:
            continue
        var angle = (float(i) / segments) * TAU
        var px = center.x + cos(angle) * radius - thickness / 2
        var py = center.y + sin(angle) * radius - thickness / 2
        _add_rect(Vector2(px, py), Vector2(thickness + 1, thickness + 1))
```

- [ ] **Step 2: Verify Godot parses without errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add src/ui/crosshair.gd
git commit -m "feat(hud): add CrosshairManager with per-weapon reticles"
```

---

### Task 6: Minimap Control

**Files:**
- Create: `src/ui/minimap.gd`

- [ ] **Step 1: Create Minimap custom Control**

Create `src/ui/minimap.gd` (4-space indentation):

```gdscript
class_name Minimap
extends Control

## Renders level grid, player dot, and monster dots via _draw().
## Redraws at ~10 FPS via Timer, not every frame.

const MAP_SIZE: float = 120.0

var _grid: Array = []
var _grid_width: int = 0
var _grid_height: int = 0
var _tile_size: float = 4.0
var _cell_size: float = 1.0
var _timer: Timer

func _init() -> void:
    custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
    size = Vector2(MAP_SIZE, MAP_SIZE)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
    _timer = Timer.new()
    _timer.wait_time = 0.1  # ~10 FPS
    _timer.timeout.connect(queue_redraw)
    add_child(_timer)
    _timer.start()

func setup(level_data: Dictionary) -> void:
    _grid = level_data.get("grid", [])
    _grid_width = level_data.get("width", 0)
    _grid_height = level_data.get("height", 0)
    _tile_size = Config.level_tile_size
    if _grid_width > 0 and _grid_height > 0:
        _cell_size = MAP_SIZE / float(maxi(_grid_width, _grid_height))
    queue_redraw()

func apply_theme() -> void:
    queue_redraw()

func _draw() -> void:
    var theme = ThemeManager.active_theme

    # Semi-transparent background
    var bg_color = Color(theme.ui_background_color.r, theme.ui_background_color.g, theme.ui_background_color.b, 0.7)
    draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), bg_color)

    if _grid.is_empty():
        return

    # Draw tile grid
    for y in range(_grid.size()):
        var row = _grid[y]
        for x in range(row.size()):
            var tile: String = row[x]
            var color: Color
            match tile:
                "room", "spawn":
                    color = theme.ui_minimap_room
                "corridor_h", "corridor_v", "door":
                    # Slightly darker than room
                    color = Color(
                        theme.ui_minimap_room.r - 0.03,
                        theme.ui_minimap_room.g - 0.03,
                        theme.ui_minimap_room.b - 0.03
                    )
                "wall":
                    color = theme.ui_minimap_wall
                _:
                    continue  # "empty" — skip
            draw_rect(Rect2(x * _cell_size, y * _cell_size, _cell_size, _cell_size), color)

    # Monster dots (red)
    var monsters = get_tree().get_nodes_in_group("monsters")
    for monster in monsters:
        if is_instance_valid(monster) and monster is Node3D:
            var dot_pos = _world_to_map(monster.global_position)
            draw_circle(dot_pos, 2.0, theme.health_bar_low_color)

    # Player dot (green)
    var players = get_tree().get_nodes_in_group("players")
    for player in players:
        if player is PlayerEntity:
            var net_id = player.get_component(C_NetworkIdentity)
            if net_id and net_id.is_local:
                var dot_pos = _world_to_map(player.global_position)
                draw_circle(dot_pos, 3.0, theme.health_bar_foreground)
                break

    # Border
    draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), theme.ui_minimap_wall, false, 2.0)

func _world_to_map(world_pos: Vector3) -> Vector2:
    var mx = (world_pos.x / (_grid_width * _tile_size)) * MAP_SIZE
    var my = (world_pos.z / (_grid_height * _tile_size)) * MAP_SIZE
    return Vector2(clampf(mx, 0, MAP_SIZE), clampf(my, 0, MAP_SIZE))
```

- [ ] **Step 2: Verify Godot parses without errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add src/ui/minimap.gd
git commit -m "feat(hud): add Minimap Control with tile grid rendering"
```

---

### Task 7: HUD Rewrite

**Files:**
- Rewrite: `src/ui/hud.tscn`
- Rewrite: `src/ui/hud.gd` (TABS indentation — this file uses tabs, not spaces)

This is the central task. The HUD is completely rewritten. All child nodes are created programmatically in `_ready()` so the `.tscn` is minimal.

- [ ] **Step 1: Rewrite hud.tscn**

Replace entire `src/ui/hud.tscn` with:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/hud.gd" id="1"]

[node name="HUD" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("1")
```

- [ ] **Step 2: Rewrite hud.gd**

Replace entire `src/ui/hud.gd` with the following. **IMPORTANT: This file uses TABS for indentation, not spaces.**

```gdscript
extends Control

# --- Health bar ---
var _health_container: Control
var _health_title: Label
var _health_bar_bg: ColorRect
var _health_bar_fill: ColorRect
var _health_label: Label

# --- Weapon panel ---
var _weapon_container: Control
var _weapon_panel_bg: ColorRect
var _weapon_title: Label
var _weapon_name_label: Label
var _weapon_element_label: Label
var _weapon_slots: Array[ColorRect] = []
var _weapon_slot_labels: Array[Label] = []

# --- Abilities ---
var _ability_container: HBoxContainer
var _ability_dash: AbilityIndicator
var _ability_aoe: AbilityIndicator
var _ability_life: AbilityIndicator

# --- Crosshair ---
var _crosshair: CrosshairManager

# --- Kill feed ---
var _kill_feed_container: VBoxContainer

# --- Boss bar ---
var _boss_container: Control
var _boss_name_label: Label
var _boss_bar_bg: ColorRect
var _boss_bar_fill: ColorRect
var _boss_entity: Entity

# --- Minimap ---
var _minimap: Minimap

# --- Damage flash ---
var _damage_flash: ColorRect

var _prev_health: int = -1

func _ready() -> void:
	_build_damage_flash()
	_build_health_bar()
	_build_weapon_panel()
	_build_ability_indicators()
	_build_crosshair()
	_build_kill_feed()
	_build_boss_bar()
	_build_minimap()
	_apply_theme()
	ThemeManager.theme_changed.connect(_on_theme_changed)

# ========== BUILD ==========

func _build_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.color = Color(1, 0, 0, 0)
	add_child(_damage_flash)

func _build_health_bar() -> void:
	_health_container = Control.new()
	_health_container.anchor_left = 0.0
	_health_container.anchor_top = 1.0
	_health_container.anchor_right = 0.0
	_health_container.anchor_bottom = 1.0
	_health_container.offset_left = 20
	_health_container.offset_top = -52
	_health_container.offset_right = 220
	_health_container.offset_bottom = -16
	_health_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_health_container)

	_health_title = Label.new()
	_health_title.text = "HEALTH"
	_health_title.position = Vector2(0, -16)
	_health_title.size = Vector2(200, 14)
	_health_title.add_theme_font_size_override("font_size", 10)
	_health_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_container.add_child(_health_title)

	_health_bar_bg = ColorRect.new()
	_health_bar_bg.position = Vector2(0, 0)
	_health_bar_bg.size = Vector2(200, 16)
	_health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_container.add_child(_health_bar_bg)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.position = Vector2(0, 0)
	_health_bar_fill.size = Vector2(200, 16)
	_health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_container.add_child(_health_bar_fill)

	_health_label = Label.new()
	_health_label.text = "100 / 100"
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.position = Vector2(0, 0)
	_health_label.size = Vector2(200, 16)
	_health_label.add_theme_font_size_override("font_size", 11)
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_container.add_child(_health_label)

func _build_weapon_panel() -> void:
	_weapon_container = Control.new()
	_weapon_container.anchor_left = 1.0
	_weapon_container.anchor_top = 1.0
	_weapon_container.anchor_right = 1.0
	_weapon_container.anchor_bottom = 1.0
	_weapon_container.offset_left = -220
	_weapon_container.offset_top = -62
	_weapon_container.offset_right = -20
	_weapon_container.offset_bottom = -16
	_weapon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_weapon_container)

	_weapon_title = Label.new()
	_weapon_title.text = "WEAPON"
	_weapon_title.position = Vector2(0, -16)
	_weapon_title.size = Vector2(200, 14)
	_weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_title.add_theme_font_size_override("font_size", 10)
	_weapon_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_container.add_child(_weapon_title)

	_weapon_panel_bg = ColorRect.new()
	_weapon_panel_bg.position = Vector2(0, 0)
	_weapon_panel_bg.size = Vector2(200, 46)
	_weapon_panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_container.add_child(_weapon_panel_bg)

	for i in range(4):
		var slot_bg = ColorRect.new()
		slot_bg.position = Vector2(8 + i * 22, 6)
		slot_bg.size = Vector2(18, 18)
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_container.add_child(slot_bg)
		_weapon_slots.append(slot_bg)

		var slot_label = Label.new()
		slot_label.text = str(i + 1)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.position = Vector2(8 + i * 22, 6)
		slot_label.size = Vector2(18, 18)
		slot_label.add_theme_font_size_override("font_size", 9)
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_container.add_child(slot_label)
		_weapon_slot_labels.append(slot_label)

	_weapon_name_label = Label.new()
	_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_name_label.position = Vector2(96, 4)
	_weapon_name_label.size = Vector2(96, 18)
	_weapon_name_label.add_theme_font_size_override("font_size", 12)
	_weapon_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_container.add_child(_weapon_name_label)

	_weapon_element_label = Label.new()
	_weapon_element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_element_label.position = Vector2(96, 24)
	_weapon_element_label.size = Vector2(96, 16)
	_weapon_element_label.add_theme_font_size_override("font_size", 10)
	_weapon_element_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_container.add_child(_weapon_element_label)

func _build_ability_indicators() -> void:
	_ability_container = HBoxContainer.new()
	_ability_container.anchor_left = 0.5
	_ability_container.anchor_top = 1.0
	_ability_container.anchor_right = 0.5
	_ability_container.anchor_bottom = 1.0
	_ability_container.offset_left = -90
	_ability_container.offset_top = -76
	_ability_container.offset_right = 90
	_ability_container.offset_bottom = -16
	_ability_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_container.add_theme_constant_override("separation", 12)
	_ability_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ability_container)

	_ability_dash = AbilityIndicator.new()
	_ability_container.add_child(_ability_dash)
	_ability_dash.setup("DASH", 3.0)

	_ability_aoe = AbilityIndicator.new()
	_ability_container.add_child(_ability_aoe)
	_ability_aoe.setup("AOE", 8.0)

	_ability_life = AbilityIndicator.new()
	_ability_container.add_child(_ability_life)
	_ability_life.setup("LIFE", 0.0)

func _build_crosshair() -> void:
	_crosshair = CrosshairManager.new()
	add_child(_crosshair)

func _build_kill_feed() -> void:
	_kill_feed_container = VBoxContainer.new()
	_kill_feed_container.anchor_left = 1.0
	_kill_feed_container.anchor_top = 0.0
	_kill_feed_container.anchor_right = 1.0
	_kill_feed_container.anchor_bottom = 0.0
	_kill_feed_container.offset_left = -200
	_kill_feed_container.offset_top = 12
	_kill_feed_container.offset_right = -16
	_kill_feed_container.offset_bottom = 100
	_kill_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kill_feed_container)

func _build_boss_bar() -> void:
	_boss_container = Control.new()
	_boss_container.anchor_left = 0.3
	_boss_container.anchor_top = 0.0
	_boss_container.anchor_right = 0.7
	_boss_container.anchor_bottom = 0.0
	_boss_container.offset_top = 12
	_boss_container.offset_bottom = 48
	_boss_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_container.visible = false
	add_child(_boss_container)

	_boss_name_label = Label.new()
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name_label.offset_bottom = 16
	_boss_name_label.add_theme_font_size_override("font_size", 11)
	_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_container.add_child(_boss_name_label)

	_boss_bar_bg = ColorRect.new()
	_boss_bar_bg.anchor_left = 0.0
	_boss_bar_bg.anchor_right = 1.0
	_boss_bar_bg.offset_top = 18
	_boss_bar_bg.offset_bottom = 34
	_boss_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_container.add_child(_boss_bar_bg)

	_boss_bar_fill = ColorRect.new()
	_boss_bar_fill.anchor_left = 0.0
	_boss_bar_fill.anchor_right = 1.0
	_boss_bar_fill.offset_top = 18
	_boss_bar_fill.offset_bottom = 34
	_boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_container.add_child(_boss_bar_fill)

func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.position = Vector2(16, 12)
	add_child(_minimap)

# ========== PUBLIC API ==========

func setup_minimap(level_data: Dictionary) -> void:
	_minimap.setup(level_data)

func show_boss_bar(boss_entity: Entity) -> void:
	_boss_entity = boss_entity
	_boss_container.visible = true
	_boss_name_label.text = "DUNGEON BOSS"

func on_actor_died(entity: Entity) -> void:
	var tag := entity.get_component(C_ActorTag) as C_ActorTag
	if not tag or tag.actor_type != C_ActorTag.ActorType.MONSTER:
		return
	var feed_text = "Defeated Boss" if entity.get_component(C_BossAI) else "Defeated Enemy"
	_add_kill_feed_entry(feed_text)

# ========== PROCESS ==========

func _process(_delta: float) -> void:
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player is PlayerEntity:
			_update_health(player)
			_update_weapon(player)
			_update_abilities(player)
			_update_crosshair(player)
			break
	_update_boss_bar()

func _update_health(player: PlayerEntity) -> void:
	var health = player.get_component(C_Health)
	if not health:
		return
	var current = health.current_health
	var max_hp = health.max_health
	_health_label.text = "%d / %d" % [current, max_hp]

	var ratio = float(current) / float(maxi(max_hp, 1))
	_health_bar_fill.size.x = 200.0 * ratio

	var theme = ThemeManager.active_theme
	_health_bar_fill.color = theme.health_bar_foreground.lerp(theme.health_bar_low_color, 1.0 - ratio)

	if _prev_health >= 0 and current < _prev_health:
		_trigger_damage_flash()
	_prev_health = current

func _update_weapon(player: PlayerEntity) -> void:
	var weapon = player.get_component(C_Weapon)
	if not weapon:
		return
	var idx = player._current_weapon_index
	var theme = ThemeManager.active_theme

	for i in range(_weapon_slots.size()):
		if i == idx:
			_weapon_slots[i].color = theme.ui_accent_color
			_weapon_slot_labels[i].add_theme_color_override("font_color", theme.ui_background_color)
		else:
			_weapon_slots[i].color = theme.ui_panel_color
			_weapon_slot_labels[i].add_theme_color_override("font_color", theme.ui_text_color)

	var preset_name = "Custom"
	if idx < Config.weapon_presets.size():
		preset_name = Config.weapon_presets[idx].name
	_weapon_name_label.text = preset_name
	_weapon_element_label.text = weapon.element if weapon.element != "" else "Standard"

func _update_abilities(player: PlayerEntity) -> void:
	var dash = player.get_component(C_Dash)
	if dash:
		_ability_dash.visible = true
		_ability_dash.update_state(dash.cooldown_remaining)
	else:
		_ability_dash.visible = false

	var aoe = player.get_component(C_AoEBlast)
	if aoe:
		_ability_aoe.visible = true
		_ability_aoe.update_state(aoe.cooldown_remaining)
	else:
		_ability_aoe.visible = false

	var lifesteal = player.get_component(C_Lifesteal)
	if lifesteal:
		_ability_life.visible = true
		_ability_life.update_state(0.0, true)
	else:
		_ability_life.visible = false

func _update_crosshair(player: PlayerEntity) -> void:
	var weapon = player.get_component(C_Weapon)
	if weapon:
		_crosshair.set_weapon(player._current_weapon_index, weapon.element)

func _update_boss_bar() -> void:
	if not _boss_container.visible or not _boss_entity:
		return
	if not is_instance_valid(_boss_entity):
		_boss_container.visible = false
		_boss_entity = null
		return
	var health = _boss_entity.get_component(C_Health)
	if not health or health.current_health <= 0:
		_boss_container.visible = false
		_boss_entity = null
		return
	var ratio = float(health.current_health) / float(maxi(health.max_health, 1))
	_boss_bar_fill.anchor_right = ratio
	var theme = ThemeManager.active_theme
	_boss_bar_fill.color = theme.health_bar_foreground.lerp(theme.health_bar_low_color, 1.0 - ratio)

# ========== KILL FEED ==========

func _add_kill_feed_entry(entry_text: String) -> void:
	var theme = ThemeManager.active_theme
	var label = Label.new()
	label.text = entry_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", theme.ui_kill_feed_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_feed_container.add_child(label)
	_kill_feed_container.move_child(label, 0)

	while _kill_feed_container.get_child_count() > 4:
		var old = _kill_feed_container.get_child(_kill_feed_container.get_child_count() - 1)
		old.queue_free()

	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

# ========== DAMAGE FLASH ==========

func _trigger_damage_flash() -> void:
	_damage_flash.color = ThemeManager.active_theme.ui_damage_flash_color
	var tween = create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.15)

# ========== THEME ==========

func _on_theme_changed(_theme: ThemeData) -> void:
	_apply_theme()

func _apply_theme() -> void:
	var theme = ThemeManager.active_theme

	_health_bar_bg.color = theme.health_bar_background
	_health_label.add_theme_color_override("font_color", theme.ui_text_color)
	_health_title.add_theme_color_override("font_color", Color(theme.ui_text_color, 0.6))

	_weapon_panel_bg.color = theme.ui_panel_color
	_weapon_title.add_theme_color_override("font_color", Color(theme.ui_text_color, 0.6))
	_weapon_name_label.add_theme_color_override("font_color", theme.ui_text_color)
	_weapon_element_label.add_theme_color_override("font_color", Color(theme.ui_text_color, 0.7))

	_boss_name_label.add_theme_color_override("font_color", theme.ui_accent_color)
	_boss_bar_bg.color = theme.health_bar_background

	_ability_dash.apply_theme()
	_ability_aoe.apply_theme()
	_ability_life.apply_theme()
	_crosshair.apply_theme()
	_minimap.apply_theme()
```

- [ ] **Step 3: Verify Godot parses without errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

- [ ] **Step 4: Commit**

```bash
git add src/ui/hud.gd src/ui/hud.tscn
git commit -m "feat(hud): complete HUD rewrite with themed panels and game UI"
```

---

### Task 8: Level Integration

**Files:**
- Modify: `src/levels/generated_level.gd:76-77,126-134,171`

This task wires everything together. The HUD gets level_data for the minimap, the boss entity for the boss bar, death signals for the kill feed, and damage signals for floating numbers.

- [ ] **Step 1: Store HUD reference as member variable**

In `src/levels/generated_level.gd`, change the local `var hud` (line 76-77) to a member variable.

Add after line 11 (`var _is_boss_level: bool = false`):

```gdscript
var _hud: Control
```

Replace lines 76-77:

```gdscript
    var hud = HUDScene.instantiate()
    add_child(hud)
```

With:

```gdscript
    _hud = HUDScene.instantiate()
    add_child(_hud)
```

- [ ] **Step 2: Pass level_data to minimap and connect signals**

After the `add_child(_hud)` line (new line 77), add:

```gdscript
    _hud.setup_minimap(level_data)

    # Kill feed
    death_system.actor_died.connect(_hud.on_actor_died)

    # Floating damage numbers
    DamageEvents.damage_dealt.connect(_on_damage_dealt)
```

- [ ] **Step 3: Pass boss entity to HUD**

In `_spawn_boss()` (around line 134, after the `print` statement), add:

```gdscript
    if _hud:
        _hud.show_boss_bar(boss.ecs_entity)
```

Note: `boss` is a `MonsterEntity`, `boss.ecs_entity` is the `Entity` the HUD needs to read `C_Health` from.

- [ ] **Step 4: Add _on_damage_dealt handler**

Add this method before `_find_in_group` (around line 198):

```gdscript
func _on_damage_dealt(pos: Vector3, amount: int, element: String) -> void:
    var ft = DamageNumberFactory.create(element)
    add_child(ft)
    ft.show_text(pos, "-%d" % amount)
```

- [ ] **Step 5: Verify Godot parses without errors**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit 2>&1 | head -20
```

- [ ] **Step 6: Run full test suite**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_theming.gd -gexit
```

Expected: ALL PASS.

- [ ] **Step 7: Commit**

```bash
git add src/levels/generated_level.gd
git commit -m "feat(hud): wire HUD to level — minimap, boss bar, kill feed, damage numbers"
```

---

### Task 9: Smoke Tests

**Files:**
- Modify: `test/unit/test_theming.gd`

- [ ] **Step 1: Add HUD instantiation smoke tests**

Append to `test/unit/test_theming.gd`:

```gdscript
# --- HUD smoke tests ---
func test_hud_scene_instantiates():
    var scene = preload("res://src/ui/hud.tscn")
    var hud = scene.instantiate()
    assert_not_null(hud)
    # Add to tree so _ready fires
    add_child(hud)
    # Verify key child nodes were created
    await get_tree().process_frame
    assert_true(hud.has_method("setup_minimap"), "HUD should have setup_minimap method")
    assert_true(hud.has_method("show_boss_bar"), "HUD should have show_boss_bar method")
    assert_true(hud.has_method("on_actor_died"), "HUD should have on_actor_died method")
    hud.queue_free()

func test_crosshair_manager_instantiates():
    var cm = CrosshairManager.new()
    assert_not_null(cm)
    add_child(cm)
    cm.set_weapon(0, "")
    cm.set_weapon(1, "fire")
    cm.set_weapon(2, "ice")
    cm.set_weapon(3, "water")
    cm.queue_free()

func test_ability_indicator_instantiates():
    var ai = AbilityIndicator.new()
    assert_not_null(ai)
    add_child(ai)
    ai.setup("TEST", 5.0)
    ai.update_state(2.5)
    ai.update_state(0.0)
    ai.update_state(0.0, true)
    ai.queue_free()

func test_minimap_instantiates():
    var mm = Minimap.new()
    assert_not_null(mm)
    add_child(mm)
    mm.setup({"grid": [["room", "wall"], ["corridor_h", "empty"]], "width": 2, "height": 2})
    mm.queue_free()

func test_damage_number_factory_creates_floating_text():
    var ft = DamageNumberFactory.create("fire")
    assert_not_null(ft)
    assert_true(ft is FloatingText)
    ft.queue_free()
```

- [ ] **Step 2: Run full test suite**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gtest=test/unit/test_theming.gd -gexit
```

Expected: ALL PASS.

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_theming.gd
git commit -m "test(hud): add smoke tests for HUD, crosshair, abilities, minimap"
```
