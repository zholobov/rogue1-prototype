# Phase 2: Registries + Migration

## Goal

Replace all `match`-based dispatch with registry lookups using Phase 1 definition classes. Migrate existing data structures (weapon presets, modifier configs, element registry internals, monster scenes) to typed definitions. Replace all string literals with StringName constants.

## Scope

- 2 new autoloads: WeaponRegistry, ModifierRegistry
- Refactor existing ElementRegistry internals
- Migrate ThemeData.monster_scenes to MonsterVariantDefinition
- Eliminate all `match` dispatch blocks (weapons, modifiers, elements)
- Replace all string literals with Phase 1 StringName constants across ~30 files
- Remove hardcoded element color fallbacks from WeaponModelFactory

Not covered: LevelBuilder splitting (Phase 3), indentation standardization (Phase 3).

---

## 1. WeaponRegistry

### File: `src/config/weapon_registry.gd` (NEW, autoload)

```gdscript
extends Node

var weapons: Array = []  # Array of WeaponDefinition

func _ready() -> void:
    _register_weapons()

func get_weapon(index: int) -> WeaponDefinition:
    if index >= 0 and index < weapons.size():
        return weapons[index]
    return null

func weapon_count() -> int:
    return weapons.size()
```

`_register_weapons()` creates 4 `WeaponDefinition` instances with stats (from current `Config.weapon_presets` data) and visual Callables (from current `WeaponModelFactory` build functions).

### Migration

- `Config.weapon_presets: Array[Dictionary]` → REMOVED from `game_config.gd`
- All reads of `Config.weapon_presets[i]` → `WeaponRegistry.get_weapon(i)`
- `WeaponModelFactory.create_viewmodel(index, element)` → `WeaponRegistry.get_weapon(index).build_viewmodel.call()`
- `WeaponModelFactory.create_world_model(index, element)` → `WeaponRegistry.get_weapon(index).build_world_model.call()`
- `WeaponModelFactory.create_hud_icon(index, element)` → `WeaponRegistry.get_weapon(index).build_hud_icon.call()`
- `crosshair.gd` `match _current_index:` → `WeaponRegistry.get_weapon(_current_index).build_crosshair.call(self)`
- `hud.gd` `range(4)` → `range(WeaponRegistry.weapon_count())`

### WeaponModelFactory Changes

The factory becomes a helper that provides the Callable implementations. Its 3 public `create_*` methods and their `match` blocks are removed. The 12 private `_build_*` methods stay and are referenced as Callables on the definitions:

```gdscript
# In weapon_registry._register_weapons():
var pistol = WeaponDefinition.new()
pistol.weapon_name = "Pistol"
pistol.damage = 10
pistol.fire_rate = 0.3
pistol.speed = 40.0
pistol.element = ElementNames.NONE
pistol.build_viewmodel = WeaponModelFactory._build_pistol_viewmodel
pistol.build_world_model = WeaponModelFactory._build_pistol_world
pistol.build_hud_icon = WeaponModelFactory._build_pistol_icon.bind(ElementNames.NONE)
pistol.build_crosshair = CrosshairManager._build_pistol  # moved from crosshair.gd
weapons.append(pistol)
```

Element glow is handled by the factory's existing `_apply_element_glow()` which the Callable calls internally. The `element` parameter is captured via `.bind()` on the Callable or read from the definition at call time.

### Crosshair Changes

The 4 `_build_pistol()`, `_build_flamethrower()`, `_build_ice_rifle()`, `_build_water_gun()` methods stay in `crosshair.gd` but become static/class methods referenced as Callables. The `_rebuild()` method's `match` block is replaced by:

```gdscript
func _rebuild():
    for child in get_children():
        child.queue_free()
    var weapon_def = WeaponRegistry.get_weapon(_current_index)
    if weapon_def and weapon_def.build_crosshair.is_valid():
        weapon_def.build_crosshair.call(self)
    _apply_tint()
```

---

## 2. ModifierRegistry

### File: `src/config/modifier_registry.gd` (NEW, autoload)

```gdscript
extends Node

var _modifiers: Dictionary = {}  # StringName -> ModifierDefinition

func _ready() -> void:
    _register_modifiers()

func get_modifier(name: StringName) -> ModifierDefinition:
    return _modifiers.get(name)

func get_all_names() -> Array:
    return _modifiers.keys()

func get_spawnable_names() -> Array:
    # All except boss (boss is placed, not randomly selected)
    return _modifiers.keys().filter(func(k): return k != Modifiers.BOSS)
```

`_register_modifiers()` creates 6 `ModifierDefinition` instances (normal, dense, large, dark, horde, boss) with all the data currently spread across 4 `match` blocks.

### Migration: run_manager._apply_modifier()

Before (match with 6 cases):
```gdscript
match modifier:
    "dense": Config.monsters_per_room = 2
    "large": Config.level_grid_width = 16; ...
    ...
```

After:
```gdscript
func _apply_modifier(modifier_name: StringName) -> void:
    var mod = ModifierRegistry.get_modifier(modifier_name)
    if not mod:
        return
    Config.current_modifier = modifier_name
    Config.level_grid_width = mod.grid_width
    Config.level_grid_height = mod.grid_height
    Config.monsters_per_room = mod.monsters_per_room
    Config.light_range_mult = mod.light_range_mult
    Config.monster_hp_mult = mod.monster_hp_mult
    Config.monster_damage_mult = mod.monster_damage_mult
    Config.max_monsters_per_level = mod.max_monsters_per_level
    # Loop scaling
    if stats.loop > 0:
        Config.monster_hp_mult *= (1.0 + 0.5 * stats.loop)
        Config.monster_damage_mult *= (1.0 + 0.25 * stats.loop)
```

### Migration: tile_rules.get_profile_weights()

Before (match with 6 cases returning dict):
```gdscript
static func get_profile_weights(modifier: String) -> Dictionary:
    match modifier:
        "dense": return {room = 2.5, ...}
        ...
```

After:
```gdscript
static func get_profile_weights(modifier_name: StringName) -> Dictionary:
    var mod = ModifierRegistry.get_modifier(modifier_name)
    if mod:
        return mod.tile_weights
    return ModifierRegistry.get_modifier(Modifiers.NORMAL).tile_weights
```

### Migration: level_generator._generate_room_seeds()

Before (match with 6 cases for room count/distance):

After:
```gdscript
var mod = ModifierRegistry.get_modifier(modifier)
if mod.pin_rooms_override.is_valid():
    return mod.pin_rooms_override.call(rng, width, height)
var room_count = rng.randi_range(mod.room_count_range.x, mod.room_count_range.y)
var min_dist = mod.room_min_dist
```

The boss modifier's `pin_rooms_override` Callable contains the 5x5 block pinning logic.

### Migration: run_map

`_random_modifier_excluding()` reads from `ModifierRegistry.get_spawnable_names()` instead of a hardcoded list.

---

## 3. ElementRegistry Refactor

### Changes to `src/config/element_registry.gd`

Internal storage changes from raw Dictionaries to `Array[ElementDefinition]`:

```gdscript
var _elements: Dictionary = {}  # StringName -> ElementDefinition

func add_element(def: ElementDefinition) -> void:
    _elements[def.element_name] = def

func get_element(name: StringName) -> ElementDefinition:
    return _elements.get(name)
```

The `_setup_defaults()` method creates `ElementDefinition` instances instead of raw dicts.

### WeaponModelFactory Element Color Fallbacks

The two hardcoded `match element:` fallback functions (`_get_element_color`, `_get_element_icon_color`) are deleted. All call sites use `ThemeManager.active_theme.get_element_color(element)` which already handles theme overrides with fallback to `ElementDefinition.default_color`.

---

## 4. MonsterVariant Migration

### ThemeData Changes

```gdscript
# Before:
var monster_scenes: Dictionary = {}  # {"basic": PackedScene, "boss": PackedScene}

# After:
var monster_variants: Array = []  # Array of MonsterVariantDefinition
```

### ThemeManager Changes

```gdscript
func get_monster_scene(variant_key: StringName) -> PackedScene:
    for v in active_theme.monster_variants:
        if v.variant_key == variant_key:
            return v.scene
    return null

func get_spawnable_variants() -> Array:
    return active_theme.monster_variants.filter(func(v): return not v.is_boss and v.spawn_weight > 0)
```

### generated_level._spawn_monsters() Changes

Before (hardcoded 50/25/25 probability):

After (weighted random from definitions):
```gdscript
var spawnable = ThemeManager.get_spawnable_variants()
if spawnable.size() > 0:
    var total_weight = 0.0
    for v in spawnable:
        total_weight += v.spawn_weight
    var roll = randf() * total_weight
    var cumulative = 0.0
    for v in spawnable:
        cumulative += v.spawn_weight
        if roll <= cumulative:
            monster.visual_variant = v.variant_key
            break
```

### Theme Factory Changes

All 3 theme factories (neon, stone, folk) migrate from:
```gdscript
t.monster_scenes = {"basic": load("res://..."), "boss": load("res://...")}
```
To:
```gdscript
var basic = MonsterVariantDefinition.new()
basic.variant_name = "Neon Basic"
basic.variant_key = &"basic"
basic.scene = load("res://...")
basic.spawn_weight = 2.0
t.monster_variants.append(basic)

var boss = MonsterVariantDefinition.new()
boss.variant_name = "Neon Boss"
boss.variant_key = &"boss"
boss.scene = load("res://...")
boss.is_boss = true
boss.spawn_weight = 0.0
t.monster_variants.append(boss)
```

---

## 5. String Literal Migration

Mechanical find-and-replace across all files. Examples:

| Before | After |
|--------|-------|
| `"fire"` | `ElementNames.FIRE` |
| `"burning"` | `ConditionNames.BURNING` |
| `"normal"` | `Modifiers.NORMAL` |
| `"forest_thicket"` | `WallStyles.FOREST_THICKET` |
| `"torch"` | `LightStyles.TORCH` |
| `"cracked_slab"` | `FloorStyles.CRACKED_SLAB` |

Only string literals used as identifiers are migrated. Display strings ("Pistol", "BOSS DEFEATED!") stay as-is.

---

## 6. New Files

| File | Type | Purpose |
|------|------|---------|
| `src/config/weapon_registry.gd` | Autoload | Holds WeaponDefinitions, replaces Config.weapon_presets |
| `src/config/modifier_registry.gd` | Autoload | Holds ModifierDefinitions, replaces 4 match blocks |

## 7. Modified Files

| File | Changes |
|------|---------|
| `src/config/game_config.gd` | Remove weapon_presets, remove modifier enum hint |
| `src/config/element_registry.gd` | Internal refactor to ElementDefinition |
| `src/effects/weapon_model_factory.gd` | Remove 3 public create_* methods + match blocks, keep private builders |
| `src/ui/crosshair.gd` | Remove match block, call definition Callable |
| `src/ui/hud.gd` | Dynamic weapon slot count |
| `src/entities/player.gd` | Read from WeaponRegistry |
| `src/run/run_manager.gd` | _apply_modifier uses ModifierRegistry |
| `src/generation/tile_rules.gd` | get_profile_weights uses ModifierRegistry |
| `src/generation/level_generator.gd` | _generate_room_seeds uses ModifierRegistry |
| `src/run/run_map.gd` | Modifier selection from registry |
| `src/themes/theme_data.gd` | monster_scenes → monster_variants |
| `src/themes/theme_manager.gd` | get_monster_scene iterates variants |
| `src/levels/generated_level.gd` | Weighted variant spawning |
| `themes/neon/neon_theme.gd` | MonsterVariantDefinition + constants |
| `themes/stone/stone_theme.gd` | Same |
| `themes/folk/folk_theme.gd` | Same |
| `project.godot` | Register 2 new autoloads |
| ~20 other files | String literal → StringName constant |
