# Phase 1: Foundation — Definition Classes + StringName Constants

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add typed definition classes and StringName constant classes that serve as the foundation for registry-based extensibility in Phase 2.

**Architecture:** 6 constant classes provide compile-time-safe identifiers for all string-based domains (elements, conditions, modifiers, wall/light/floor styles). 4 definition classes (WeaponDefinition, ModifierDefinition, ElementDefinition, MonsterVariantDefinition) encapsulate all data needed to define each concept. Phase 1 is purely additive — no existing code changes.

**Tech Stack:** Godot 4.6, GDScript, GUT for tests

**Spec:** `docs/superpowers/specs/2026-03-26-phase1-foundation-design.md`

**Indentation:** ALL new files use 4-spaces (project majority convention).

---

## File Structure

### New Files (10 source + 1 test)

| File | Class | Responsibility |
|------|-------|----------------|
| `src/constants/elements.gd` | `ElementNames` | StringName constants for element identifiers |
| `src/constants/conditions.gd` | `ConditionNames` | StringName constants for condition identifiers |
| `src/constants/modifiers.gd` | `Modifiers` | StringName constants for modifier identifiers |
| `src/constants/wall_styles.gd` | `WallStyles` | StringName constants for wall style identifiers |
| `src/constants/light_styles.gd` | `LightStyles` | StringName constants for light source style identifiers |
| `src/constants/floor_styles.gd` | `FloorStyles` | StringName constants for floor style identifiers |
| `src/definitions/weapon_definition.gd` | `WeaponDefinition` | Stats + visual Callables per weapon |
| `src/definitions/modifier_definition.gd` | `ModifierDefinition` | Tile weights + config overrides per modifier |
| `src/definitions/element_definition.gd` | `ElementDefinition` | Gameplay data + default color per element |
| `src/definitions/monster_variant_definition.gd` | `MonsterVariantDefinition` | Scene + spawn weight + stats per monster type |
| `test/unit/test_definitions.gd` | — | GUT tests for all new classes |

### Modified Files

None. Phase 1 is purely additive.

---

## Task 1: StringName Constant Classes

**Files:**
- Create: `src/constants/elements.gd`
- Create: `src/constants/conditions.gd`
- Create: `src/constants/modifiers.gd`
- Create: `src/constants/wall_styles.gd`
- Create: `src/constants/light_styles.gd`
- Create: `src/constants/floor_styles.gd`
- Create: `test/unit/test_definitions.gd`

- [ ] **Step 1: Create all 6 constant files**

Create `src/constants/elements.gd`:
```gdscript
class_name ElementNames
extends RefCounted

const FIRE = &"fire"
const ICE = &"ice"
const WATER = &"water"
const OIL = &"oil"
const NONE = &""
```

Create `src/constants/conditions.gd`:
```gdscript
class_name ConditionNames
extends RefCounted

const BURNING = &"burning"
const FROZEN = &"frozen"
const WET = &"wet"
const OILY = &"oily"
const NONE = &""
```

Create `src/constants/modifiers.gd`:
```gdscript
class_name Modifiers
extends RefCounted

const NORMAL = &"normal"
const DENSE = &"dense"
const LARGE = &"large"
const DARK = &"dark"
const HORDE = &"horde"
const BOSS = &"boss"
```

Create `src/constants/wall_styles.gd`:
```gdscript
class_name WallStyles
extends RefCounted

const DEFAULT = &"default"
const FOREST_THICKET = &"forest_thicket"
const PALACE_ORNATE = &"palace_ornate"
const ICE_CRYSTAL = &"ice_crystal"
```

Create `src/constants/light_styles.gd`:
```gdscript
class_name LightStyles
extends RefCounted

const FLOATING = &"floating"
const TORCH = &"torch"
const MUSHROOM = &"mushroom"
const CRYSTAL = &"crystal"
```

Create `src/constants/floor_styles.gd`:
```gdscript
class_name FloorStyles
extends RefCounted

const PLAIN = &"plain"
const CRACKED_SLAB = &"cracked_slab"
```

- [ ] **Step 2: Create test file with constant tests**

Create `test/unit/test_definitions.gd`:
```gdscript
extends GutTest

# --- StringName Constants ---

func test_element_names_fire():
    assert_eq(ElementNames.FIRE, &"fire")
    assert_eq(ElementNames.ICE, &"ice")
    assert_eq(ElementNames.WATER, &"water")
    assert_eq(ElementNames.NONE, &"")

func test_condition_names():
    assert_eq(ConditionNames.BURNING, &"burning")
    assert_eq(ConditionNames.FROZEN, &"frozen")
    assert_eq(ConditionNames.WET, &"wet")

func test_modifiers():
    assert_eq(Modifiers.NORMAL, &"normal")
    assert_eq(Modifiers.BOSS, &"boss")

func test_wall_styles():
    assert_eq(WallStyles.DEFAULT, &"default")
    assert_eq(WallStyles.FOREST_THICKET, &"forest_thicket")

func test_light_styles():
    assert_eq(LightStyles.TORCH, &"torch")
    assert_eq(LightStyles.MUSHROOM, &"mushroom")

func test_floor_styles():
    assert_eq(FloorStyles.PLAIN, &"plain")
    assert_eq(FloorStyles.CRACKED_SLAB, &"cracked_slab")

func test_string_name_comparison():
    # Verify StringName constants work as dictionary keys
    var d = {ElementNames.FIRE: "hot", ElementNames.ICE: "cold"}
    assert_eq(d[ElementNames.FIRE], "hot")
    assert_eq(d[&"fire"], "hot")  # interoperable with literal StringName
```

- [ ] **Step 3: Run tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_definitions.gd
```

- [ ] **Step 4: Commit**

```bash
git add src/constants/ test/unit/test_definitions.gd
git commit -m "feat: add StringName constant classes for all string-based domains"
```

---

## Task 2: WeaponDefinition

**Files:**
- Create: `src/definitions/weapon_definition.gd`
- Modify: `test/unit/test_definitions.gd`

- [ ] **Step 1: Create WeaponDefinition**

Create `src/definitions/weapon_definition.gd`:
```gdscript
class_name WeaponDefinition
extends RefCounted

var weapon_name: String = ""
var damage: int = 10
var fire_rate: float = 0.3
var speed: float = 30.0
var element: StringName = ElementNames.NONE
var build_viewmodel: Callable   # func() -> Node3D
var build_world_model: Callable # func() -> Node3D
var build_crosshair: Callable   # func(parent: Control) -> void
var build_hud_icon: Callable    # func() -> Control
```

- [ ] **Step 2: Add tests**

Append to `test/unit/test_definitions.gd`:
```gdscript
# --- WeaponDefinition ---

func test_weapon_definition_defaults():
    var w = WeaponDefinition.new()
    assert_eq(w.weapon_name, "")
    assert_eq(w.damage, 10)
    assert_almost_eq(w.fire_rate, 0.3, 0.001)
    assert_eq(w.element, ElementNames.NONE)

func test_weapon_definition_with_values():
    var w = WeaponDefinition.new()
    w.weapon_name = "Pistol"
    w.damage = 15
    w.element = ElementNames.FIRE
    w.build_viewmodel = func(): return Node3D.new()
    assert_eq(w.weapon_name, "Pistol")
    assert_eq(w.element, ElementNames.FIRE)
    assert_not_null(w.build_viewmodel)

func test_weapon_definition_callable():
    var w = WeaponDefinition.new()
    var called = false
    w.build_viewmodel = func():
        called = true
        return Node3D.new()
    var result = w.build_viewmodel.call()
    assert_true(result is Node3D)
```

- [ ] **Step 3: Run tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_definitions.gd
```

- [ ] **Step 4: Commit**

```bash
git add src/definitions/weapon_definition.gd test/unit/test_definitions.gd
git commit -m "feat: add WeaponDefinition class with stats and visual Callables"
```

---

## Task 3: ModifierDefinition

**Files:**
- Create: `src/definitions/modifier_definition.gd`
- Modify: `test/unit/test_definitions.gd`

- [ ] **Step 1: Create ModifierDefinition**

Create `src/definitions/modifier_definition.gd`:
```gdscript
class_name ModifierDefinition
extends RefCounted

var modifier_name: StringName = Modifiers.NORMAL
var display_name: String = "NORMAL"

# WFC tile weights
var tile_weights: Dictionary = {
    "room": 1.5, "spawn": 1.5, "cor": 0.4,
    "door": 0.2, "wall": 3.5, "empty": 1.0
}

# Grid size
var grid_width: int = 12
var grid_height: int = 12

# Monster config
var monsters_per_room: int = 1
var max_monsters_per_level: int = 5
var monster_hp_mult: float = 1.0
var monster_damage_mult: float = 1.0

# Lighting
var light_range_mult: float = 1.0

# Room seed generation
var room_count_range: Vector2i = Vector2i(4, 7)
var room_min_dist: int = 4

# Map selection weight
var map_weight: float = 1.0

# Boss special: custom room pinning (null Callable for normal modifiers)
var pin_rooms_override: Callable
```

- [ ] **Step 2: Add tests**

Append to `test/unit/test_definitions.gd`:
```gdscript
# --- ModifierDefinition ---

func test_modifier_definition_defaults():
    var m = ModifierDefinition.new()
    assert_eq(m.modifier_name, Modifiers.NORMAL)
    assert_eq(m.grid_width, 12)
    assert_eq(m.grid_height, 12)
    assert_eq(m.monsters_per_room, 1)
    assert_almost_eq(m.monster_hp_mult, 1.0, 0.001)

func test_modifier_definition_dense():
    var m = ModifierDefinition.new()
    m.modifier_name = Modifiers.DENSE
    m.display_name = "DENSE"
    m.monsters_per_room = 2
    m.tile_weights = {"room": 2.5, "spawn": 2.5, "cor": 0.3, "door": 0.5, "wall": 2.0, "empty": 0.5}
    assert_eq(m.modifier_name, Modifiers.DENSE)
    assert_eq(m.monsters_per_room, 2)
    assert_almost_eq(m.tile_weights["room"], 2.5, 0.001)

func test_modifier_definition_tile_weights_keys():
    var m = ModifierDefinition.new()
    assert_true(m.tile_weights.has("room"))
    assert_true(m.tile_weights.has("wall"))
    assert_true(m.tile_weights.has("cor"))
```

- [ ] **Step 3: Run tests and commit**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_definitions.gd
git add src/definitions/modifier_definition.gd test/unit/test_definitions.gd
git commit -m "feat: add ModifierDefinition class with tile weights and config overrides"
```

---

## Task 4: ElementDefinition

**Files:**
- Create: `src/definitions/element_definition.gd`
- Modify: `test/unit/test_definitions.gd`

- [ ] **Step 1: Create ElementDefinition**

Create `src/definitions/element_definition.gd`:
```gdscript
class_name ElementDefinition
extends RefCounted

var element_name: StringName = ElementNames.NONE
var display_name: String = ""
var condition_name: StringName = ConditionNames.NONE
var condition_duration: float = 3.0
var default_color: Color = Color.WHITE
var damage_per_tick: float = 0.0
var interactions: Array = []  # [{combine_with: StringName, produces: StringName}]
```

- [ ] **Step 2: Add tests**

Append to `test/unit/test_definitions.gd`:
```gdscript
# --- ElementDefinition ---

func test_element_definition_defaults():
    var e = ElementDefinition.new()
    assert_eq(e.element_name, ElementNames.NONE)
    assert_eq(e.condition_name, ConditionNames.NONE)
    assert_almost_eq(e.condition_duration, 3.0, 0.001)

func test_element_definition_fire():
    var e = ElementDefinition.new()
    e.element_name = ElementNames.FIRE
    e.display_name = "Fire"
    e.condition_name = ConditionNames.BURNING
    e.condition_duration = 5.0
    e.default_color = Color(1.0, 0.5, 0.1)
    e.damage_per_tick = 2.0
    e.interactions = [{"combine_with": ConditionNames.OILY, "produces": ConditionNames.BURNING}]
    assert_eq(e.element_name, ElementNames.FIRE)
    assert_eq(e.condition_name, ConditionNames.BURNING)
    assert_eq(e.interactions.size(), 1)

func test_element_definition_color():
    var e = ElementDefinition.new()
    e.default_color = Color(0.0, 0.8, 1.0)
    assert_almost_eq(e.default_color.b, 1.0, 0.001)
```

- [ ] **Step 3: Run tests and commit**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_definitions.gd
git add src/definitions/element_definition.gd test/unit/test_definitions.gd
git commit -m "feat: add ElementDefinition class with gameplay data and default color"
```

---

## Task 5: MonsterVariantDefinition

**Files:**
- Create: `src/definitions/monster_variant_definition.gd`
- Modify: `test/unit/test_definitions.gd`

- [ ] **Step 1: Create MonsterVariantDefinition**

Create `src/definitions/monster_variant_definition.gd`:
```gdscript
class_name MonsterVariantDefinition
extends RefCounted

var variant_name: String = ""
var variant_key: StringName = &"basic"
var scene: PackedScene
var spawn_weight: float = 1.0
var hp_mult: float = 1.0
var speed_mult: float = 1.0
var is_boss: bool = false
```

- [ ] **Step 2: Add tests**

Append to `test/unit/test_definitions.gd`:
```gdscript
# --- MonsterVariantDefinition ---

func test_monster_variant_defaults():
    var v = MonsterVariantDefinition.new()
    assert_eq(v.variant_name, "")
    assert_eq(v.variant_key, &"basic")
    assert_almost_eq(v.spawn_weight, 1.0, 0.001)
    assert_almost_eq(v.hp_mult, 1.0, 0.001)
    assert_false(v.is_boss)

func test_monster_variant_boss():
    var v = MonsterVariantDefinition.new()
    v.variant_name = "Zmey Boss"
    v.variant_key = &"boss"
    v.is_boss = true
    v.spawn_weight = 0.0
    v.hp_mult = 5.0
    assert_true(v.is_boss)
    assert_almost_eq(v.spawn_weight, 0.0, 0.001)

func test_monster_variant_weighted_selection():
    # Verify the data supports weighted random selection
    var variants = [
        MonsterVariantDefinition.new(),
        MonsterVariantDefinition.new(),
        MonsterVariantDefinition.new(),
    ]
    variants[0].variant_name = "Basic"
    variants[0].spawn_weight = 2.0
    variants[1].variant_name = "Fast"
    variants[1].spawn_weight = 1.0
    variants[2].variant_name = "Tank"
    variants[2].spawn_weight = 1.0

    var total_weight = 0.0
    for v in variants:
        total_weight += v.spawn_weight
    assert_almost_eq(total_weight, 4.0, 0.001)
```

- [ ] **Step 3: Run tests and commit**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_definitions.gd
git add src/definitions/monster_variant_definition.gd test/unit/test_definitions.gd
git commit -m "feat: add MonsterVariantDefinition class with scene, weight, and stats"
```
