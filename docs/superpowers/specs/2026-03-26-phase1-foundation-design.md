# Phase 1: Foundation — Definition Classes + StringName Constants

## Goal

Introduce typed definition classes and StringName constant classes that will serve as the foundation for replacing all `match`-based dispatch with registry lookups in Phase 2. Phase 1 adds the new classes without changing any existing behavior — they coexist with the old code.

## Scope

- 6 StringName constant classes (one per domain)
- 4 definition classes (Weapon, Modifier, Element, MonsterVariant)
- No changes to existing files
- No behavior changes

Not covered: migration of existing code to use these classes (Phase 2), LevelBuilder splitting (Phase 3), indentation standardization (Phase 3).

---

## 1. StringName Constants

Each domain that currently uses string literals for identification gets a constants class. All follow the same pattern: `class_name`, `extends RefCounted`, `const` fields using `&"..."` StringName syntax.

### File: `src/constants/elements.gd`

```gdscript
class_name Elements
extends RefCounted

const FIRE = &"fire"
const ICE = &"ice"
const WATER = &"water"
const OIL = &"oil"
const NONE = &""
```

### File: `src/constants/conditions.gd`

```gdscript
class_name Conditions
extends RefCounted

const BURNING = &"burning"
const FROZEN = &"frozen"
const WET = &"wet"
const OILY = &"oily"
const NONE = &""
```

### File: `src/constants/modifiers.gd`

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

### File: `src/constants/wall_styles.gd`

```gdscript
class_name WallStyles
extends RefCounted

const DEFAULT = &"default"
const FOREST_THICKET = &"forest_thicket"
const PALACE_ORNATE = &"palace_ornate"
const ICE_CRYSTAL = &"ice_crystal"
```

### File: `src/constants/light_styles.gd`

```gdscript
class_name LightStyles
extends RefCounted

const FLOATING = &"floating"
const TORCH = &"torch"
const MUSHROOM = &"mushroom"
const CRYSTAL = &"crystal"
```

### File: `src/constants/floor_styles.gd`

```gdscript
class_name FloorStyles
extends RefCounted

const PLAIN = &"plain"
const CRACKED_SLAB = &"cracked_slab"
```

### Usage

Before: `t.wall_style = "forest_thicket"` — string literal, typo-prone, no autocomplete.

After: `t.wall_style = WallStyles.FOREST_THICKET` — compiler catches typos, IDE autocomplete, grep-friendly.

---

## 2. WeaponDefinition

### File: `src/definitions/weapon_definition.gd`

```gdscript
class_name WeaponDefinition
extends RefCounted

var weapon_name: String
var damage: int
var fire_rate: float
var speed: float
var element: StringName       # Elements.FIRE, Elements.NONE, etc.
var build_viewmodel: Callable  # func() -> Node3D
var build_world_model: Callable # func() -> Node3D
var build_crosshair: Callable  # func(parent: Control) -> void
var build_hud_icon: Callable   # func() -> Control
```

Each weapon is fully self-contained: stats + all visual builders in one object. The Callables are set in code (like ThemeData properties in theme factories).

In Phase 2, `GameConfig.weapon_presets` (currently `Array[Dictionary]`) will be replaced by `Array[WeaponDefinition]`. The existing `WeaponModelFactory` match blocks will be replaced by calling `weapon_def.build_viewmodel.call()`. The `crosshair.gd` match block will be replaced by `weapon_def.build_crosshair.call(self)`. The HUD `range(4)` will become `range(Config.weapon_presets.size())`.

---

## 3. ModifierDefinition

### File: `src/definitions/modifier_definition.gd`

```gdscript
class_name ModifierDefinition
extends RefCounted

var modifier_name: StringName  # Modifiers.DENSE, etc.
var display_name: String       # "DENSE" for map UI

# WFC tile weights
var tile_weights: Dictionary = {
    "room": 1.5, "spawn": 1.5, "cor": 0.4,
    "door": 0.2, "wall": 3.5, "empty": 1.0
}

# Grid size overrides
var grid_width: int = 12
var grid_height: int = 12

# Monster scaling
var monsters_per_room: int = 1
var max_monsters_per_level: int = 5
var monster_hp_mult: float = 1.0
var monster_damage_mult: float = 1.0

# Lighting
var light_range_mult: float = 1.0

# Room seed generation
var room_count_range: Vector2i = Vector2i(4, 7)  # min, max
var room_min_dist: int = 4

# Map selection weight (higher = more likely to appear)
var map_weight: float = 1.0

# Boss special: custom room pinning (null for normal modifiers)
var pin_rooms_override: Callable  # func(rng, width, height) -> Dictionary
```

In Phase 2, all 4 `match modifier:` blocks (in `run_manager.gd`, `level_generator.gd`, `tile_rules.gd`, `run_map.gd`) will collapse to single `registry.get(modifier_name)` lookups.

---

## 4. ElementDefinition

### File: `src/definitions/element_definition.gd`

```gdscript
class_name ElementDefinition
extends RefCounted

var element_name: StringName    # Elements.FIRE, etc.
var display_name: String        # "Fire" for UI
var condition_name: StringName  # Conditions.BURNING
var condition_duration: float   # default duration in seconds
var default_color: Color        # fallback color if theme doesn't override
var damage_per_tick: float      # condition DoT (0 = no DoT)

# Interactions: what happens when this condition combines with another
var interactions: Array = []    # Array of {combine_with: StringName, produces: StringName}
```

ThemeData keeps `element_colors: Dictionary` for per-theme color overrides. Visual lookup becomes:
```gdscript
func get_element_color(element: StringName) -> Color:
    if element_colors.has(element):
        return element_colors[element]
    var def = ElementRegistry.get(element)
    if def:
        return def.default_color
    return Color.WHITE
```

---

## 5. MonsterVariantDefinition

### File: `src/definitions/monster_variant_definition.gd`

```gdscript
class_name MonsterVariantDefinition
extends RefCounted

var variant_name: String         # "Leshy", "Kikimora", "Vodyanoy"
var variant_key: StringName      # &"basic", &"variant1", &"variant2", &"boss"
var scene: PackedScene           # the .tscn scene
var spawn_weight: float = 1.0   # for weighted random selection (0 = never random-spawned)
var hp_mult: float = 1.0        # per-variant HP scaling
var speed_mult: float = 1.0     # per-variant speed scaling
var is_boss: bool = false        # boss = spawned by _spawn_boss(), not random
```

In Phase 2, `ThemeData.monster_scenes: Dictionary` will be replaced by `monster_variants: Array[MonsterVariantDefinition]`. The spawn code will iterate the array, filter out bosses, and do weighted random selection. Adding a 4th or 5th variant per biome: just append to the array.

---

## 6. New Files Summary

| File | Class | Purpose |
|---|---|---|
| `src/constants/elements.gd` | `Elements` | `&"fire"`, `&"ice"`, `&"water"`, `&"oil"` |
| `src/constants/conditions.gd` | `Conditions` | `&"burning"`, `&"frozen"`, `&"wet"`, `&"oily"` |
| `src/constants/modifiers.gd` | `Modifiers` | `&"normal"`, `&"dense"`, `&"large"`, `&"dark"`, `&"horde"`, `&"boss"` |
| `src/constants/wall_styles.gd` | `WallStyles` | `&"default"`, `&"forest_thicket"`, `&"palace_ornate"`, `&"ice_crystal"` |
| `src/constants/light_styles.gd` | `LightStyles` | `&"floating"`, `&"torch"`, `&"mushroom"`, `&"crystal"` |
| `src/constants/floor_styles.gd` | `FloorStyles` | `&"plain"`, `&"cracked_slab"` |
| `src/definitions/weapon_definition.gd` | `WeaponDefinition` | Stats + visual Callables per weapon |
| `src/definitions/modifier_definition.gd` | `ModifierDefinition` | Tile weights + config overrides per modifier |
| `src/definitions/element_definition.gd` | `ElementDefinition` | Gameplay data + default color per element |
| `src/definitions/monster_variant_definition.gd` | `MonsterVariantDefinition` | Scene + spawn weight + scaling per monster type |

## 7. Modified Files

None. Phase 1 only adds new files. Existing code continues to work unchanged with string literals. Phase 2 will migrate consumers to use the constants and definitions.

## 8. Naming Conflict

The class name `Conditions` conflicts with the existing `C_Conditions` component. However, `C_Conditions` is a component (data on an entity), while `Conditions` is a constants class (compile-time identifiers). They serve different purposes and have different names — no actual conflict. Usage: `Conditions.BURNING` (constant) vs `C_Conditions` (component class).

Similarly, `Elements` could conflict with the `Elements` autoload (currently named `ElementRegistry` in code but registered as `Elements` in project.godot). To avoid this, the constants class can be named `ElementNames` instead:

| Domain | Constants Class | Avoids Conflict With |
|---|---|---|
| Elements | `ElementNames` | `Elements` autoload |
| Conditions | `ConditionNames` | `C_Conditions` component |
| Modifiers | `Modifiers` | (no conflict) |
| Wall styles | `WallStyles` | (no conflict) |
| Light styles | `LightStyles` | (no conflict) |
| Floor styles | `FloorStyles` | (no conflict) |
