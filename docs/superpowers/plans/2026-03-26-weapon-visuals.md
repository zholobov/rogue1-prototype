# Weapon Visuals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add visible weapon models — first-person viewmodels, third-person monster attachments, and HUD weapon icons — plus enable monsters to spawn with ranged weapons.

**Architecture:** WeaponModelFactory builds weapon meshes from geometric primitives (BoxMesh/CylinderMesh/SphereMesh). C_WeaponVisual component tracks which weapon to display. S_WeaponVisual system manages mesh lifecycle, attachment, and animations. Armed monsters reuse S_BossAI for ranged behavior with a visible weapon via WeaponMount.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS framework, GUT for unit tests

**Spec:** `docs/superpowers/specs/2026-03-26-weapon-visuals-design.md`

**Indentation rules:**
- TABS: `game_config.gd`, `s_player_input.gd`, `hud.gd`, `level_builder.gd`
- 4-SPACES: all new files, `player.gd`, `monster.gd`, `generated_level.gd`, `s_weapon.gd`, `s_boss_ai.gd`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `src/effects/weapon_model_factory.gd` | Static factory: create viewmodel, world model, and HUD icon meshes |
| `src/components/c_weapon_visual.gd` | Component: tracks weapon_index, element, show_viewmodel, just_fired |
| `src/systems/s_weapon_visual.gd` | System: spawns/destroys weapon meshes, recoil/switch animation, idle sway |
| `test/unit/test_weapon_visuals.gd` | GUT tests for factory, component, and system |

### Modified Files

| File | Changes |
|------|---------|
| `src/entities/player.gd` | Add C_WeaponVisual in _ready(), update in _equip_weapon() and setup() |
| `src/systems/s_weapon.gd` | Set C_WeaponVisual.just_fired when firing |
| `src/entities/monster.gd` | Add C_WeaponVisual in setup_as_boss() |
| `src/levels/generated_level.gd` | Register S_WeaponVisual, arm monsters on spawn, muzzle point lookup |
| `src/config/game_config.gd` | Add monster_weapon_chance, monster_weapon_presets, monster_ranged_cooldown, monster_ranged_damage |
| `src/ui/hud.gd` | Add weapon icon to panel via create_hud_icon() |
| `themes/neon/monster_basic.tscn` | Add WeaponMount Marker3D |
| `themes/neon/monster_boss.tscn` | Add WeaponMount Marker3D |
| `themes/stone/monster_basic.tscn` | Add WeaponMount Marker3D |
| `themes/stone/monster_boss.tscn` | Add WeaponMount Marker3D |

---

## Task 1: C_WeaponVisual Component + Tests

**Files:**
- Create: `src/components/c_weapon_visual.gd`
- Create: `test/unit/test_weapon_visuals.gd`

- [ ] **Step 1: Create test file**

Create `test/unit/test_weapon_visuals.gd`:

```gdscript
extends GutTest

# --- C_WeaponVisual defaults ---

func test_weapon_visual_defaults():
    var wv = C_WeaponVisual.new()
    assert_eq(wv.weapon_index, -1)
    assert_eq(wv.element, "")
    assert_eq(wv.show_viewmodel, false)
    assert_eq(wv.just_fired, false)
```

- [ ] **Step 2: Create component**

Create `src/components/c_weapon_visual.gd`:

```gdscript
class_name C_WeaponVisual
extends Component

@export var weapon_index: int = -1
@export var element: String = ""
@export var show_viewmodel: bool = false
@export var just_fired: bool = false
```

- [ ] **Step 3: Run tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_weapon_visuals.gd
```

- [ ] **Step 4: Commit**

```bash
git add src/components/c_weapon_visual.gd test/unit/test_weapon_visuals.gd
git commit -m "feat: add C_WeaponVisual component for weapon model tracking"
```

---

## Task 2: WeaponModelFactory — Pistol Viewmodel

**Files:**
- Create: `src/effects/weapon_model_factory.gd`
- Modify: `test/unit/test_weapon_visuals.gd`

- [ ] **Step 1: Add factory tests**

Append to `test/unit/test_weapon_visuals.gd`:

```gdscript
# --- WeaponModelFactory ---

func test_factory_create_viewmodel_pistol():
    var model = WeaponModelFactory.create_viewmodel(0, "")
    assert_not_null(model)
    assert_true(model is Node3D)
    assert_eq(model.name, "WeaponViewmodel")
    # Should have MuzzlePoint
    var muzzle = model.get_node_or_null("MuzzlePoint")
    assert_not_null(muzzle, "Viewmodel should have MuzzlePoint")
    # Should have multiple mesh children
    assert_true(model.get_child_count() >= 10, "Pistol should have 10+ primitives")
    model.queue_free()

func test_factory_create_viewmodel_all_weapons():
    for i in range(4):
        var model = WeaponModelFactory.create_viewmodel(i, "")
        assert_not_null(model, "Weapon %d viewmodel should exist" % i)
        var muzzle = model.get_node_or_null("MuzzlePoint")
        assert_not_null(muzzle, "Weapon %d should have MuzzlePoint" % i)
        model.queue_free()

func test_factory_create_world_model():
    var model = WeaponModelFactory.create_world_model(0, "")
    assert_not_null(model)
    assert_eq(model.name, "WeaponWorldModel")
    assert_true(model.get_child_count() >= 4, "World model should have 4+ primitives")
    model.queue_free()

func test_factory_create_hud_icon():
    var icon = WeaponModelFactory.create_hud_icon(0, "")
    assert_not_null(icon)
    assert_true(icon is Control)
    assert_true(icon.get_child_count() >= 3, "HUD icon should have 3+ ColorRects")
    icon.queue_free()

func test_factory_element_glow():
    var model = WeaponModelFactory.create_viewmodel(1, "fire")
    assert_not_null(model)
    # Check that at least one child has emission enabled
    var has_emission = false
    for child in model.get_children():
        if child is MeshInstance3D and child.material_override:
            var mat = child.material_override as StandardMaterial3D
            if mat and mat.emission_enabled:
                has_emission = true
                break
    assert_true(has_emission, "Fire weapon should have emissive accent")
    model.queue_free()

func test_factory_invalid_index_returns_null():
    var model = WeaponModelFactory.create_viewmodel(99, "")
    assert_null(model)
```

- [ ] **Step 2: Create weapon_model_factory.gd with full implementation**

Create `src/effects/weapon_model_factory.gd`. This is a large file — the factory builds all 4 weapon shapes. Read the spec for shape descriptions. Each weapon is a composition of `MeshInstance3D` children with `StandardMaterial3D` materials.

```gdscript
class_name WeaponModelFactory
extends RefCounted

# Material colors (theme-independent)
const BASE_METAL = Color(0.55, 0.55, 0.60)
const DARK_METAL = Color(0.35, 0.35, 0.38)
const GRIP_COLOR = Color(0.27, 0.20, 0.13)

static func create_viewmodel(weapon_index: int, element: String) -> Node3D:
    var root: Node3D
    match weapon_index:
        0: root = _build_pistol_viewmodel()
        1: root = _build_flamethrower_viewmodel()
        2: root = _build_ice_rifle_viewmodel()
        3: root = _build_water_gun_viewmodel()
        _: return null
    root.name = "WeaponViewmodel"
    _apply_element_glow(root, element)
    return root

static func create_world_model(weapon_index: int, element: String) -> Node3D:
    var root: Node3D
    match weapon_index:
        0: root = _build_pistol_world()
        1: root = _build_flamethrower_world()
        2: root = _build_ice_rifle_world()
        3: root = _build_water_gun_world()
        _: return null
    root.name = "WeaponWorldModel"
    root.scale = Vector3(0.6, 0.6, 0.6)
    _apply_element_glow(root, element)
    return root

static func create_hud_icon(weapon_index: int, element: String) -> Control:
    var root = Control.new()
    root.custom_minimum_size = Vector2(64, 48)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    match weapon_index:
        0: _build_pistol_icon(root, element)
        1: _build_flamethrower_icon(root, element)
        2: _build_ice_rifle_icon(root, element)
        3: _build_water_gun_icon(root, element)
    return root

# --- Material helpers ---

static func _make_mat(color: Color, roughness: float = 0.7) -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat

static func _make_emissive_mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color.darkened(0.5)
    mat.roughness = 0.5
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    return mat

static func _add_box(parent: Node3D, pos: Vector3, box_size: Vector3, mat: StandardMaterial3D, node_name: String = "") -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = box_size
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if node_name != "":
        mi.name = node_name
    parent.add_child(mi)
    return mi

static func _add_sphere(parent: Node3D, pos: Vector3, radius: float, mat: StandardMaterial3D, node_name: String = "") -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if node_name != "":
        mi.name = node_name
    parent.add_child(mi)
    return mi

static func _add_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: StandardMaterial3D, node_name: String = "") -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if node_name != "":
        mi.name = node_name
    parent.add_child(mi)
    return mi

static func _add_muzzle(parent: Node3D, pos: Vector3) -> void:
    var marker = Marker3D.new()
    marker.name = "MuzzlePoint"
    marker.position = pos
    parent.add_child(marker)

# --- Element glow ---

static func _get_element_color(element: String) -> Color:
    if ThemeManager and ThemeManager.active_theme:
        return ThemeManager.active_theme.get_element_color(element)
    match element:
        "fire": return Color(1.0, 0.5, 0.1)
        "ice": return Color(0.0, 0.8, 1.0)
        "water": return Color(0.0, 0.5, 1.0)
        _: return Color.WHITE

static func _apply_element_glow(root: Node3D, element: String) -> void:
    if element == "":
        return
    var color = _get_element_color(element)
    for child in root.get_children():
        if child is MeshInstance3D and child.name.begins_with("Accent"):
            child.material_override = _make_emissive_mat(color)

# --- Pistol ---

static func _build_pistol_viewmodel() -> Node3D:
    var root = Node3D.new()
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)

    # Barrel
    _add_box(root, Vector3(0, 0.06, -0.18), Vector3(0.04, 0.035, 0.22), base)
    # Front sight
    _add_box(root, Vector3(0, 0.085, -0.27), Vector3(0.015, 0.015, 0.01), dark)
    # Rear sight
    _add_box(root, Vector3(0, 0.085, -0.08), Vector3(0.025, 0.015, 0.01), dark)
    # Slide body
    _add_box(root, Vector3(0, 0.03, -0.1), Vector3(0.05, 0.04, 0.18), base)
    # Panel line top
    _add_box(root, Vector3(0, 0.052, -0.1), Vector3(0.052, 0.003, 0.17), dark)
    # Panel line bottom
    _add_box(root, Vector3(0, 0.008, -0.1), Vector3(0.052, 0.003, 0.17), dark)
    # Ejection port
    _add_box(root, Vector3(0.02, 0.04, -0.06), Vector3(0.015, 0.02, 0.03), dark)
    # Muzzle
    _add_sphere(root, Vector3(0, 0.06, -0.29), 0.012, _make_mat(Color(0.15, 0.15, 0.15)))
    # Trigger guard
    _add_box(root, Vector3(0, -0.02, -0.06), Vector3(0.035, 0.003, 0.04), dark)
    # Trigger
    _add_box(root, Vector3(0, -0.01, -0.05), Vector3(0.008, 0.02, 0.006), base)
    # Grip
    _add_box(root, Vector3(0, -0.06, -0.04), Vector3(0.035, 0.07, 0.03), grip)
    # Grip lines
    _add_box(root, Vector3(0, -0.04, -0.04), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.055, -0.04), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.07, -0.04), Vector3(0.036, 0.004, 0.031), dark)
    # Accent (for element glow)
    _add_box(root, Vector3(0, 0.052, -0.18), Vector3(0.042, 0.004, 0.06), base, "AccentStrip")
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.06, -0.32))
    return root

static func _build_pistol_world() -> Node3D:
    var root = Node3D.new()
    var base = _make_mat(BASE_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    _add_box(root, Vector3(0, 0.05, -0.15), Vector3(0.04, 0.035, 0.2), base)
    _add_box(root, Vector3(0, 0.02, -0.08), Vector3(0.05, 0.04, 0.15), base)
    _add_box(root, Vector3(0, -0.04, -0.04), Vector3(0.035, 0.06, 0.03), grip)
    _add_box(root, Vector3(0, 0.052, -0.15), Vector3(0.042, 0.004, 0.06), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.05, -0.26))
    return root

# --- Flamethrower ---

static func _build_flamethrower_viewmodel() -> Node3D:
    var root = Node3D.new()
    var barrel_col = Color(0.47, 0.27, 0.0)
    var barrel_mat = _make_mat(barrel_col)
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var tank_col = Color(0.27, 0.2, 0.0)
    var tank_mat = _make_mat(tank_col)

    # Wide barrel
    _add_box(root, Vector3(0, 0.05, -0.2), Vector3(0.06, 0.05, 0.28), barrel_mat)
    # Barrel rings
    _add_box(root, Vector3(0, 0.05, -0.30), Vector3(0.065, 0.055, 0.015), dark)
    _add_box(root, Vector3(0, 0.05, -0.22), Vector3(0.065, 0.055, 0.015), dark)
    _add_box(root, Vector3(0, 0.05, -0.14), Vector3(0.065, 0.055, 0.015), dark)
    # Body
    _add_box(root, Vector3(0, 0.01, -0.05), Vector3(0.07, 0.05, 0.2), base)
    # Accent strip
    _add_box(root, Vector3(0, 0.038, -0.05), Vector3(0.05, 0.005, 0.12), base, "AccentStrip")
    # Panel line
    _add_box(root, Vector3(0, -0.015, -0.05), Vector3(0.072, 0.003, 0.19), dark)
    # Fuel tank (sphere scaled as ellipsoid)
    var tank = _add_sphere(root, Vector3(0, -0.08, -0.02), 0.04, tank_mat)
    tank.scale = Vector3(1.0, 1.4, 1.0)
    # Tank ring
    _add_cylinder(root, Vector3(0, -0.08, -0.02), 0.032, 0.005, dark)
    # Connector
    _add_box(root, Vector3(0, -0.03, -0.02), Vector3(0.02, 0.03, 0.015), base)
    # Igniter
    _add_box(root, Vector3(-0.025, 0.04, -0.32), Vector3(0.015, 0.015, 0.015), base)
    # Grip
    _add_box(root, Vector3(0.025, 0.0, 0.04), Vector3(0.03, 0.05, 0.025), grip)
    _add_box(root, Vector3(0.025, 0.005, 0.04), Vector3(0.031, 0.004, 0.026), dark)
    _add_box(root, Vector3(0.025, -0.01, 0.04), Vector3(0.031, 0.004, 0.026), dark)
    # Indicator light
    _add_sphere(root, Vector3(-0.02, 0.035, -0.1), 0.006, base, "AccentLight")
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.05, -0.36))
    return root

static func _build_flamethrower_world() -> Node3D:
    var root = Node3D.new()
    var barrel_mat = _make_mat(Color(0.47, 0.27, 0.0))
    var base = _make_mat(BASE_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var tank_mat = _make_mat(Color(0.27, 0.2, 0.0))
    _add_box(root, Vector3(0, 0.05, -0.2), Vector3(0.06, 0.05, 0.28), barrel_mat)
    _add_box(root, Vector3(0, 0.01, -0.05), Vector3(0.07, 0.05, 0.2), base)
    var tank = _add_sphere(root, Vector3(0, -0.06, -0.02), 0.035, tank_mat)
    tank.scale = Vector3(1.0, 1.3, 1.0)
    _add_box(root, Vector3(0.025, 0.0, 0.04), Vector3(0.03, 0.05, 0.025), grip)
    _add_box(root, Vector3(0, 0.038, -0.05), Vector3(0.05, 0.005, 0.12), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.05, -0.36))
    return root

# --- Ice Rifle ---

static func _build_ice_rifle_viewmodel() -> Node3D:
    var root = Node3D.new()
    var rifle_col = Color(0.33, 0.47, 0.67)
    var rifle_mat = _make_mat(rifle_col)
    var dark_rifle = _make_mat(Color(0.27, 0.33, 0.4))
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)

    # Long barrel
    _add_box(root, Vector3(0, 0.05, -0.22), Vector3(0.035, 0.03, 0.35), rifle_mat)
    # Barrel rings
    _add_box(root, Vector3(0, 0.05, -0.35), Vector3(0.04, 0.035, 0.01), dark_rifle)
    _add_box(root, Vector3(0, 0.05, -0.28), Vector3(0.04, 0.035, 0.01), dark_rifle)
    _add_box(root, Vector3(0, 0.05, -0.21), Vector3(0.04, 0.035, 0.01), dark_rifle)
    # Muzzle glow
    _add_sphere(root, Vector3(0, 0.05, -0.40), 0.01, base, "AccentMuzzle")
    # Receiver
    _add_box(root, Vector3(0, 0.025, -0.02), Vector3(0.06, 0.04, 0.2), dark_rifle)
    # Accent strip
    _add_box(root, Vector3(0, 0.047, -0.02), Vector3(0.04, 0.004, 0.14), rifle_mat, "AccentStrip")
    # Panel line
    _add_box(root, Vector3(0, 0.003, -0.02), Vector3(0.062, 0.003, 0.19), dark)
    # Scope
    _add_box(root, Vector3(0, 0.08, -0.05), Vector3(0.03, 0.025, 0.08), dark_rifle)
    _add_sphere(root, Vector3(0, 0.08, -0.09), 0.008, base, "AccentLensFront")
    _add_sphere(root, Vector3(0, 0.08, -0.01), 0.008, base, "AccentLensRear")
    # Stock
    _add_box(root, Vector3(0, 0.035, 0.12), Vector3(0.04, 0.035, 0.08), dark_rifle)
    _add_box(root, Vector3(0, 0.01, 0.14), Vector3(0.04, 0.05, 0.06), dark_rifle)
    # Grip
    _add_box(root, Vector3(0, -0.03, 0.02), Vector3(0.03, 0.06, 0.025), grip)
    _add_box(root, Vector3(0, -0.015, 0.02), Vector3(0.031, 0.004, 0.026), dark)
    _add_box(root, Vector3(0, -0.035, 0.02), Vector3(0.031, 0.004, 0.026), dark)
    # Trigger guard + trigger
    _add_box(root, Vector3(0, -0.005, -0.01), Vector3(0.035, 0.003, 0.04), dark)
    _add_box(root, Vector3(0, 0.0, -0.005), Vector3(0.008, 0.02, 0.006), base)
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.05, -0.42))
    return root

static func _build_ice_rifle_world() -> Node3D:
    var root = Node3D.new()
    var rifle_mat = _make_mat(Color(0.33, 0.47, 0.67))
    var dark_rifle = _make_mat(Color(0.27, 0.33, 0.4))
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var base = _make_mat(BASE_METAL)
    _add_box(root, Vector3(0, 0.05, -0.22), Vector3(0.035, 0.03, 0.35), rifle_mat)
    _add_box(root, Vector3(0, 0.025, -0.02), Vector3(0.06, 0.04, 0.2), dark_rifle)
    _add_box(root, Vector3(0, 0.08, -0.05), Vector3(0.03, 0.025, 0.08), dark_rifle)
    _add_box(root, Vector3(0, -0.03, 0.02), Vector3(0.03, 0.06, 0.025), grip)
    _add_box(root, Vector3(0, 0.047, -0.02), Vector3(0.04, 0.004, 0.14), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.05, -0.42))
    return root

# --- Water Gun ---

static func _build_water_gun_viewmodel() -> Node3D:
    var root = Node3D.new()
    var water_col = Color(0.2, 0.33, 0.67)
    var water_mat = _make_mat(water_col)
    var dark_water = _make_mat(Color(0.16, 0.27, 0.53))
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var tank_col = Color(0.1, 0.2, 0.47)

    # Stubby barrel
    _add_box(root, Vector3(0, 0.04, -0.15), Vector3(0.055, 0.045, 0.2), water_mat)
    # Barrel rings
    _add_box(root, Vector3(0, 0.04, -0.22), Vector3(0.06, 0.05, 0.015), dark_water)
    _add_box(root, Vector3(0, 0.04, -0.14), Vector3(0.06, 0.05, 0.015), dark_water)
    # Nozzle
    _add_box(root, Vector3(0, 0.04, -0.27), Vector3(0.03, 0.03, 0.02), dark_water)
    _add_sphere(root, Vector3(0, 0.04, -0.29), 0.012, base, "AccentNozzle")
    # Body
    _add_box(root, Vector3(0, 0.0, -0.03), Vector3(0.065, 0.05, 0.18), dark_water)
    # Accent strip
    _add_box(root, Vector3(0, 0.027, -0.03), Vector3(0.045, 0.004, 0.12), water_mat, "AccentStrip")
    # Panel line
    _add_box(root, Vector3(0, -0.025, -0.03), Vector3(0.067, 0.003, 0.17), dark)
    # Water tank (sphere)
    var tank = _add_sphere(root, Vector3(0, 0.1, -0.05), 0.045, _make_mat(Color(tank_col)))
    tank.scale = Vector3(1.2, 0.9, 1.0)
    # Tank cap
    _add_box(root, Vector3(0, 0.145, -0.05), Vector3(0.03, 0.015, 0.025), dark_water)
    # Water indicator
    _add_sphere(root, Vector3(0, 0.1, -0.05), 0.012, base, "AccentIndicator")
    # Connector
    _add_box(root, Vector3(0, 0.06, -0.05), Vector3(0.02, 0.02, 0.015), dark_water)
    # Grip
    _add_box(root, Vector3(0, -0.05, 0.02), Vector3(0.035, 0.07, 0.03), grip)
    _add_box(root, Vector3(0, -0.03, 0.02), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.045, 0.02), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.06, 0.02), Vector3(0.036, 0.004, 0.031), dark)
    # Trigger guard + pump trigger
    _add_box(root, Vector3(0, -0.01, -0.02), Vector3(0.035, 0.003, 0.04), dark)
    _add_box(root, Vector3(0, -0.005, -0.015), Vector3(0.008, 0.02, 0.008), water_mat)
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.04, -0.30))
    return root

static func _build_water_gun_world() -> Node3D:
    var root = Node3D.new()
    var water_mat = _make_mat(Color(0.2, 0.33, 0.67))
    var dark_water = _make_mat(Color(0.16, 0.27, 0.53))
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var base = _make_mat(BASE_METAL)
    _add_box(root, Vector3(0, 0.04, -0.15), Vector3(0.055, 0.045, 0.2), water_mat)
    _add_box(root, Vector3(0, 0.0, -0.03), Vector3(0.065, 0.05, 0.18), dark_water)
    var tank = _add_sphere(root, Vector3(0, 0.1, -0.05), 0.04, _make_mat(Color(0.1, 0.2, 0.47)))
    tank.scale = Vector3(1.2, 0.9, 1.0)
    _add_box(root, Vector3(0, -0.05, 0.02), Vector3(0.035, 0.07, 0.03), grip)
    _add_box(root, Vector3(0, 0.027, -0.03), Vector3(0.045, 0.004, 0.12), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.04, -0.30))
    return root

# --- HUD Icons (2D silhouettes from ColorRects) ---

static func _icon_rect(parent: Control, pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
    var r = ColorRect.new()
    r.position = pos
    r.size = sz
    r.color = color
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(r)
    return r

static func _get_element_icon_color(element: String) -> Color:
    match element:
        "fire": return Color(1.0, 0.4, 0.05, 0.6)
        "ice": return Color(0.0, 0.8, 1.0, 0.6)
        "water": return Color(0.0, 0.53, 1.0, 0.6)
        _: return Color(0.6, 0.6, 0.6, 0.0)  # invisible for no element

static func _build_pistol_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(8, 8), Vector2(40, 10), Color(0.5, 0.5, 0.52))    # barrel
    _icon_rect(root, Vector2(12, 18), Vector2(32, 16), Color(0.38, 0.38, 0.4))  # body
    _icon_rect(root, Vector2(22, 34), Vector2(14, 14), GRIP_COLOR)              # grip
    _icon_rect(root, Vector2(4, 10), Vector2(6, 6), Color(0.25, 0.25, 0.25))   # muzzle
    if accent.a > 0:
        _icon_rect(root, Vector2(12, 16), Vector2(24, 3), accent)               # element accent

static func _build_flamethrower_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(2, 10), Vector2(50, 12), Color(0.47, 0.27, 0.0))  # barrel
    _icon_rect(root, Vector2(14, 22), Vector2(38, 14), Color(0.38, 0.38, 0.4)) # body
    _icon_rect(root, Vector2(24, 36), Vector2(20, 12), Color(0.27, 0.2, 0.0))  # tank (approx)
    _icon_rect(root, Vector2(0, 12), Vector2(6, 8), Color(1.0, 0.4, 0.0, 0.4)) # muzzle glow
    if accent.a > 0:
        _icon_rect(root, Vector2(16, 24), Vector2(22, 3), accent)

static func _build_ice_rifle_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(0, 16), Vector2(55, 9), Color(0.33, 0.47, 0.67))   # long barrel
    _icon_rect(root, Vector2(22, 25), Vector2(36, 13), Color(0.27, 0.33, 0.4))  # receiver
    _icon_rect(root, Vector2(28, 8), Vector2(16, 7), Color(0.22, 0.27, 0.33))   # scope
    _icon_rect(root, Vector2(50, 22), Vector2(14, 16), Color(0.27, 0.33, 0.4))  # stock
    _icon_rect(root, Vector2(0, 18), Vector2(4, 5), Color(0.0, 0.8, 1.0, 0.5)) # muzzle glow
    if accent.a > 0:
        _icon_rect(root, Vector2(24, 27), Vector2(26, 3), accent)

static func _build_water_gun_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(4, 20), Vector2(40, 12), Color(0.2, 0.33, 0.67))   # barrel
    _icon_rect(root, Vector2(16, 32), Vector2(34, 14), Color(0.16, 0.27, 0.53)) # body
    _icon_rect(root, Vector2(20, 4), Vector2(24, 16), Color(0.1, 0.2, 0.47))    # tank (approx rect)
    _icon_rect(root, Vector2(44, 44), Vector2(12, 4), Color(0.15, 0.24, 0.48))  # grip hint
    _icon_rect(root, Vector2(2, 22), Vector2(6, 8), Color(0.0, 0.53, 1.0, 0.4)) # nozzle glow
    if accent.a > 0:
        _icon_rect(root, Vector2(18, 34), Vector2(24, 3), accent)
```

- [ ] **Step 3: Run tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_weapon_visuals.gd
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/effects/weapon_model_factory.gd test/unit/test_weapon_visuals.gd
git commit -m "feat: add WeaponModelFactory with 4 weapon viewmodels, world models, and HUD icons"
```

---

## Task 3: S_WeaponVisual System

**Files:**
- Create: `src/systems/s_weapon_visual.gd`

- [ ] **Step 1: Create the system**

Create `src/systems/s_weapon_visual.gd`:

```gdscript
class_name S_WeaponVisual
extends System

var _last_index: Dictionary = {}  # entity instance_id -> last weapon_index
var _weapon_nodes: Dictionary = {}  # entity instance_id -> Node3D (weapon mesh)
var _recoil_tweens: Dictionary = {}  # entity instance_id -> Tween

func query() -> QueryBuilder:
    return q.with_all([C_WeaponVisual])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var wv := entity.get_component(C_WeaponVisual) as C_WeaponVisual
        if wv.weapon_index < 0:
            continue

        var eid = entity.get_instance_id()
        var body = entity.get_parent() as CharacterBody3D
        if not body:
            continue

        # Detect weapon change
        var last = _last_index.get(eid, -1)
        if last != wv.weapon_index:
            _swap_weapon(entity, wv, body, eid)
            _last_index[eid] = wv.weapon_index

        var weapon_node = _weapon_nodes.get(eid) as Node3D
        if not weapon_node or not is_instance_valid(weapon_node):
            continue

        # Fire recoil
        if wv.just_fired:
            wv.just_fired = false
            if wv.show_viewmodel:
                _play_recoil(weapon_node, eid)

        # Idle sway (viewmodel only)
        if wv.show_viewmodel:
            var t = Time.get_ticks_msec() / 1000.0
            weapon_node.position.x = 0.35 + sin(t * 2.0) * 0.003
            weapon_node.position.y = -0.35 + cos(t * 1.5) * 0.002

        # Element pulse
        if wv.element != "":
            var pulse = 1.5 + sin(Time.get_ticks_msec() / 500.0) * 0.5
            _set_accent_energy(weapon_node, pulse)

func _swap_weapon(entity: Entity, wv: C_WeaponVisual, body: CharacterBody3D, eid: int) -> void:
    # Remove old
    var old_node = _weapon_nodes.get(eid)
    if old_node and is_instance_valid(old_node):
        old_node.queue_free()
    _weapon_nodes.erase(eid)

    # Create new
    var new_node: Node3D
    if wv.show_viewmodel:
        new_node = WeaponModelFactory.create_viewmodel(wv.weapon_index, wv.element)
    else:
        new_node = WeaponModelFactory.create_world_model(wv.weapon_index, wv.element)

    if not new_node:
        return

    if wv.show_viewmodel:
        # Attach to camera
        var camera = body.get_node_or_null("Camera3D")
        if camera:
            new_node.position = Vector3(0.35, -0.35, -0.6)
            new_node.rotation_degrees = Vector3(0, -5, 0)
            camera.add_child(new_node)
    else:
        # Attach to WeaponMount or fallback position
        var mount = _find_weapon_mount(body)
        if mount:
            mount.add_child(new_node)
        else:
            new_node.position = Vector3(0.4, 0.3, -0.3)
            body.add_child(new_node)

    _weapon_nodes[eid] = new_node

func _find_weapon_mount(body: Node) -> Node:
    # Check direct children
    var mount = body.get_node_or_null("WeaponMount")
    if mount:
        return mount
    # Check in VisualRoot (theme scene override)
    var visual_root = body.get_node_or_null("VisualRoot")
    if visual_root:
        mount = visual_root.get_node_or_null("WeaponMount")
        if mount:
            return mount
    return null

func _play_recoil(weapon_node: Node3D, eid: int) -> void:
    # Kill existing recoil tween
    var old_tween = _recoil_tweens.get(eid)
    if old_tween and old_tween.is_valid():
        old_tween.kill()

    var base_pos = weapon_node.position
    var base_rot = weapon_node.rotation_degrees
    var tree = weapon_node.get_tree()
    if not tree:
        return
    var tween = tree.create_tween()
    # Kick back
    tween.tween_property(weapon_node, "position:z", base_pos.z + 0.05, 0.05)
    tween.parallel().tween_property(weapon_node, "rotation_degrees:x", base_rot.x + 3.0, 0.05)
    # Return
    tween.tween_property(weapon_node, "position:z", base_pos.z, 0.1)
    tween.parallel().tween_property(weapon_node, "rotation_degrees:x", base_rot.x, 0.1)
    _recoil_tweens[eid] = tween

func _set_accent_energy(weapon_node: Node3D, energy: float) -> void:
    for child in weapon_node.get_children():
        if child is MeshInstance3D and child.name.begins_with("Accent"):
            var mat = child.material_override as StandardMaterial3D
            if mat and mat.emission_enabled:
                mat.emission_energy_multiplier = energy
```

- [ ] **Step 2: Commit**

```bash
git add src/systems/s_weapon_visual.gd
git commit -m "feat: add S_WeaponVisual system — mesh lifecycle, recoil, sway, element pulse"
```

---

## Task 4: Wire Player + S_Weapon Integration

**Files:**
- Modify: `src/entities/player.gd:20-27,38-48,70-81`
- Modify: `src/systems/s_weapon.gd:22-26`
- Modify: `src/levels/generated_level.gd:61-63`

- [ ] **Step 1: Add C_WeaponVisual to player**

In `src/entities/player.gd` (4-spaces), add after the `C_PlayerStats` add_component line (line 27):

```gdscript
    ecs_entity.add_component(C_WeaponVisual.new())
```

- [ ] **Step 2: Set show_viewmodel in setup()**

In `src/entities/player.gd`, add at the end of `setup()` (after `Input.mouse_mode` block, around line 48):

```gdscript
    var wv := get_component(C_WeaponVisual) as C_WeaponVisual
    if wv:
        wv.show_viewmodel = is_local
        wv.weapon_index = _current_weapon_index
        wv.element = get_component(C_Weapon).element if get_component(C_Weapon) else ""
```

- [ ] **Step 3: Update C_WeaponVisual in _equip_weapon()**

In `src/entities/player.gd`, add at the end of `_equip_weapon()` (after line 81):

```gdscript
    var wv := get_component(C_WeaponVisual) as C_WeaponVisual
    if wv:
        wv.weapon_index = index
        wv.element = weapon.element
```

- [ ] **Step 4: Set just_fired in S_Weapon**

In `src/systems/s_weapon.gd` (4-spaces), add after the `projectile_requested.emit(body, weapon)` line (line 26):

```gdscript
            var wv = entity.get_component(C_WeaponVisual)
            if wv:
                wv.just_fired = true
```

- [ ] **Step 5: Register S_WeaponVisual in generated_level.gd**

In `src/levels/generated_level.gd` (4-spaces), add after the `weapon_system` registration (after line 63):

```gdscript
    ECS.world.add_system(S_WeaponVisual.new())
```

- [ ] **Step 6: Update muzzle point in _on_projectile_requested**

In `src/levels/generated_level.gd`, update `_on_projectile_requested` to use muzzle point if available. Find the line that calculates `spawn_pos` (around `camera.global_position + (-camera.global_transform.basis.z * 1.0)`) and replace with:

```gdscript
    var muzzle = owner_body.get_node_or_null("Camera3D/WeaponViewmodel/MuzzlePoint")
    var spawn_pos: Vector3
    if muzzle:
        spawn_pos = muzzle.global_position
    else:
        spawn_pos = camera.global_position + (-camera.global_transform.basis.z * 1.0)
```

- [ ] **Step 7: Verify manually**

Run the game. Verify:
1. First-person weapon model visible at bottom-right of screen
2. Weapon changes when pressing 1-4
3. Recoil animation on firing
4. Element glow on flamethrower/ice rifle/water gun
5. Muzzle flash still appears at correct position

- [ ] **Step 8: Commit**

```bash
git add src/entities/player.gd src/systems/s_weapon.gd src/levels/generated_level.gd
git commit -m "feat: wire player viewmodel — C_WeaponVisual, just_fired flag, muzzle point"
```

---

## Task 5: HUD Weapon Icon

**Files:**
- Modify: `src/ui/hud.gd`

- [ ] **Step 1: Add weapon icon to HUD**

In `src/ui/hud.gd` (TABS), add a variable after `_weapon_element_label`:

```gdscript
var _weapon_icon: Control
var _last_hud_weapon_index: int = -1
```

In `_build_weapon_panel()`, after creating `_weapon_panel_bg` (after line 140), add the icon container:

```gdscript
	_weapon_icon = Control.new()
	_weapon_icon.position = Vector2(8, 4)
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_container.add_child(_weapon_icon)
```

Increase the panel height to fit. Change `_weapon_panel_bg.size` from `Vector2(200, 46)` to `Vector2(200, 56)`. Shift the weapon name/element labels and slots down by 10px.

- [ ] **Step 2: Update _update_weapon() to refresh icon**

In `_update_weapon()`, add before the weapon name update:

```gdscript
		# Update weapon icon
		if idx != _last_hud_weapon_index:
			_last_hud_weapon_index = idx
			for child in _weapon_icon.get_children():
				child.queue_free()
			var element_str = weapon.element if weapon.element != "" else ""
			var icon = WeaponModelFactory.create_hud_icon(idx, element_str)
			_weapon_icon.add_child(icon)
```

- [ ] **Step 3: Commit**

```bash
git add src/ui/hud.gd
git commit -m "feat: add weapon silhouette icon to HUD weapon panel"
```

---

## Task 6: Monster Weapon Config + Spawning

**Files:**
- Modify: `src/config/game_config.gd`
- Modify: `src/levels/generated_level.gd`

- [ ] **Step 1: Add monster weapon config**

In `src/config/game_config.gd` (TABS), add after `var monster_damage_mult`:

```gdscript
	var monster_weapon_chance: float = 0.0
	var monster_weapon_presets: Array[int] = [0, 1, 2, 3]
	var monster_ranged_cooldown: float = 3.0
	var monster_ranged_damage: int = 8
```

- [ ] **Step 2: Arm monsters on spawn**

In `src/levels/generated_level.gd` (4-spaces), in `_spawn_monsters()`, after a monster is spawned and added to the scene (after the HP/damage scaling block), add:

```gdscript
            # Arm monster with weapon if chance roll succeeds
            if Config.monster_weapon_chance > 0.0 and randf() < Config.monster_weapon_chance:
                var wi = Config.monster_weapon_presets[randi() % Config.monster_weapon_presets.size()]
                var preset = Config.weapon_presets[wi] if wi < Config.weapon_presets.size() else Config.weapon_presets[0]
                # Add ranged AI
                var boss_ai_comp = C_BossAI.new()
                boss_ai_comp.ranged_cooldown = Config.monster_ranged_cooldown
                boss_ai_comp.projectile_damage = Config.monster_ranged_damage
                boss_ai_comp.projectile_speed = preset.speed
                monster.ecs_entity.add_component(boss_ai_comp)
                # Add weapon visual
                var wv = C_WeaponVisual.new()
                wv.weapon_index = wi
                wv.element = preset.element
                monster.ecs_entity.add_component(wv)
                # Make ranged instead of melee
                var ai := monster.ecs_entity.get_component(C_MonsterAI) as C_MonsterAI
                if ai:
                    ai.attack_range = 15.0
```

- [ ] **Step 3: Add C_WeaponVisual to boss in monster.gd**

In `src/entities/monster.gd` (4-spaces), at the end of `setup_as_boss()` (after the `boss_ai.projectile_damage` line), add:

```gdscript
    var wv = C_WeaponVisual.new()
    wv.weapon_index = 0  # Pistol shape
    wv.element = ""
    ecs_entity.add_component(wv)
```

- [ ] **Step 4: Commit**

```bash
git add src/config/game_config.gd src/levels/generated_level.gd src/entities/monster.gd
git commit -m "feat: add monster weapon spawning — armed monsters with ranged attacks"
```

---

## Task 7: WeaponMount in Monster Theme Scenes

**Files:**
- Modify: `themes/neon/monster_basic.tscn`
- Modify: `themes/neon/monster_boss.tscn`
- Modify: `themes/stone/monster_basic.tscn`
- Modify: `themes/stone/monster_boss.tscn`

- [ ] **Step 1: Add WeaponMount to all 4 scenes**

For each `.tscn` file, add a `Marker3D` node named `WeaponMount` as a child of the root node. Use the Edit tool to add the node definition.

Positions per scene:
- `themes/neon/monster_basic.tscn`: `Vector3(0.5, 0.4, -0.3)`
- `themes/neon/monster_boss.tscn`: `Vector3(0.7, 0.6, -0.4)`
- `themes/stone/monster_basic.tscn`: `Vector3(0.7, 0.2, -0.3)`
- `themes/stone/monster_boss.tscn`: `Vector3(0.9, 0.3, -0.4)`

Read each `.tscn` file first to understand its structure, then add the WeaponMount node at the end of the node list.

- [ ] **Step 2: Commit**

```bash
git add themes/neon/monster_basic.tscn themes/neon/monster_boss.tscn themes/stone/monster_basic.tscn themes/stone/monster_boss.tscn
git commit -m "feat: add WeaponMount Marker3D to all monster theme scenes"
```

---

## Task 8: Final Tests + Integration Smoke Test

**Files:**
- Modify: `test/unit/test_weapon_visuals.gd`

- [ ] **Step 1: Add integration smoke tests**

Append to `test/unit/test_weapon_visuals.gd`:

```gdscript
# --- S_WeaponVisual smoke ---

func test_weapon_visual_system_instantiates():
    var sys = S_WeaponVisual.new()
    assert_not_null(sys)

# --- Monster weapon config ---

func test_monster_weapon_config_defaults():
    assert_almost_eq(Config.monster_weapon_chance, 0.0, 0.001)
    assert_eq(Config.monster_weapon_presets.size(), 4)
    assert_almost_eq(Config.monster_ranged_cooldown, 3.0, 0.001)
    assert_eq(Config.monster_ranged_damage, 8)
```

- [ ] **Step 2: Run all weapon visual tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_weapon_visuals.gd
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_weapon_visuals.gd
git commit -m "test: add integration smoke tests for weapon visuals"
```
