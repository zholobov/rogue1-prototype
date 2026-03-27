# Phase 2: Registries + Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all `match`-based dispatch with registry lookups, migrate data structures to definition classes, and replace all string literals with StringName constants.

**Architecture:** Two new autoloads (WeaponRegistry, ModifierRegistry) hold typed definitions. ElementRegistry internals refactored to use ElementDefinition. ThemeData.monster_scenes migrated to MonsterVariantDefinition array. All match blocks eliminated. All identifier string literals replaced with constants.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS framework, GUT for tests

**Spec:** `docs/superpowers/specs/2026-03-26-phase2-registries-design.md`

**Indentation:** 4-spaces for all files (project majority convention).

**IMPORTANT:** This is a large refactor. Each task must leave the codebase in a WORKING state. Tasks are ordered so that registries are created first, then consumers are migrated one at a time.

---

## File Structure

### New Files

| File | Purpose |
|------|---------|
| `src/config/weapon_registry.gd` | Autoload holding WeaponDefinitions |
| `src/config/modifier_registry.gd` | Autoload holding ModifierDefinitions |
| `test/unit/test_registries.gd` | Tests for both registries |

### Modified Files (by task)

| Task | Files Modified |
|------|---------------|
| Task 1 | weapon_registry.gd (new), weapon_model_factory.gd, project.godot |
| Task 2 | player.gd, game_config.gd, generated_level.gd |
| Task 3 | crosshair.gd, hud.gd |
| Task 4 | modifier_registry.gd (new), project.godot |
| Task 5 | run_manager.gd, tile_rules.gd, level_generator.gd, run_map.gd, game_config.gd |
| Task 6 | element_registry.gd |
| Task 7 | weapon_model_factory.gd (remove fallbacks) |
| Task 8 | theme_data.gd, theme_manager.gd, generated_level.gd, neon_theme.gd, stone_theme.gd, folk_theme.gd |
| Task 9 | ~25 files (string literal migration) |

---

## Task 1: WeaponRegistry Autoload

**Files:**
- Create: `src/config/weapon_registry.gd`
- Create: `test/unit/test_registries.gd`
- Modify: `src/effects/weapon_model_factory.gd` — make builder functions static/accessible
- Modify: `project.godot` — register autoload

- [ ] **Step 1: Make WeaponModelFactory builder functions accessible as Callables**

In `src/effects/weapon_model_factory.gd`, the private `_build_*_viewmodel()`, `_build_*_world()`, `_build_*_icon()` functions need to be callable from outside. They are already `static` — just need to be referenced. No code change needed if they're already static. Verify by reading the file.

Also ensure each viewmodel builder applies element glow internally (read element from a parameter or the definition).

- [ ] **Step 2: Create weapon_registry.gd**

Create `src/config/weapon_registry.gd`:

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

func _register_weapons() -> void:
    # Pistol
    var pistol = WeaponDefinition.new()
    pistol.weapon_name = "Pistol"
    pistol.damage = 10
    pistol.fire_rate = 0.3
    pistol.speed = 40.0
    pistol.element = ElementNames.NONE
    pistol.build_viewmodel = func(): return WeaponModelFactory._build_pistol_viewmodel()
    pistol.build_world_model = func(): return WeaponModelFactory._build_pistol_world()
    pistol.build_hud_icon = func(): return WeaponModelFactory._build_pistol_icon(ElementNames.NONE)
    weapons.append(pistol)

    # Flamethrower
    var flame = WeaponDefinition.new()
    flame.weapon_name = "Flamethrower"
    flame.damage = 5
    flame.fire_rate = 0.1
    flame.speed = 25.0
    flame.element = ElementNames.FIRE
    flame.build_viewmodel = func(): return WeaponModelFactory._build_flamethrower_viewmodel()
    flame.build_world_model = func(): return WeaponModelFactory._build_flamethrower_world()
    flame.build_hud_icon = func(): return WeaponModelFactory._build_flamethrower_icon(ElementNames.FIRE)
    weapons.append(flame)

    # Ice Rifle
    var ice = WeaponDefinition.new()
    ice.weapon_name = "Ice Rifle"
    ice.damage = 15
    ice.fire_rate = 0.8
    ice.speed = 35.0
    ice.element = ElementNames.ICE
    ice.build_viewmodel = func(): return WeaponModelFactory._build_ice_rifle_viewmodel()
    ice.build_world_model = func(): return WeaponModelFactory._build_ice_rifle_world()
    ice.build_hud_icon = func(): return WeaponModelFactory._build_ice_rifle_icon(ElementNames.ICE)
    weapons.append(ice)

    # Water Gun
    var water = WeaponDefinition.new()
    water.weapon_name = "Water Gun"
    water.damage = 3
    water.fire_rate = 0.05
    water.speed = 30.0
    water.element = ElementNames.WATER
    water.build_viewmodel = func(): return WeaponModelFactory._build_water_gun_viewmodel()
    water.build_world_model = func(): return WeaponModelFactory._build_water_gun_world()
    water.build_hud_icon = func(): return WeaponModelFactory._build_water_gun_icon(ElementNames.WATER)
    weapons.append(water)
```

Note: The element glow must be applied inside the builder. Read `WeaponModelFactory.create_viewmodel()` to see how `_apply_element_glow` is called after building, and replicate that in the Callable wrapper.

- [ ] **Step 3: Register autoload in project.godot**

Add `WeaponRegistry="*res://src/config/weapon_registry.gd"` to the `[autoload]` section. Place it AFTER `ThemeManager` (since weapon builders may reference ThemeManager).

- [ ] **Step 4: Create tests**

Create `test/unit/test_registries.gd`:

```gdscript
extends GutTest

func test_weapon_registry_has_4_weapons():
    assert_eq(WeaponRegistry.weapon_count(), 4)

func test_weapon_registry_get_weapon():
    var w = WeaponRegistry.get_weapon(0)
    assert_not_null(w)
    assert_eq(w.weapon_name, "Pistol")
    assert_eq(w.element, ElementNames.NONE)

func test_weapon_registry_all_have_names():
    for i in range(WeaponRegistry.weapon_count()):
        var w = WeaponRegistry.get_weapon(i)
        assert_true(w.weapon_name != "", "Weapon %d should have a name" % i)

func test_weapon_registry_all_have_callables():
    for i in range(WeaponRegistry.weapon_count()):
        var w = WeaponRegistry.get_weapon(i)
        assert_true(w.build_viewmodel.is_valid(), "Weapon %d needs build_viewmodel" % i)
        assert_true(w.build_world_model.is_valid(), "Weapon %d needs build_world_model" % i)
        assert_true(w.build_hud_icon.is_valid(), "Weapon %d needs build_hud_icon" % i)

func test_weapon_registry_invalid_index():
    assert_null(WeaponRegistry.get_weapon(99))
    assert_null(WeaponRegistry.get_weapon(-1))

func test_weapon_registry_elements():
    assert_eq(WeaponRegistry.get_weapon(0).element, ElementNames.NONE)
    assert_eq(WeaponRegistry.get_weapon(1).element, ElementNames.FIRE)
    assert_eq(WeaponRegistry.get_weapon(2).element, ElementNames.ICE)
    assert_eq(WeaponRegistry.get_weapon(3).element, ElementNames.WATER)
```

- [ ] **Step 5: Commit**

```bash
git add src/config/weapon_registry.gd test/unit/test_registries.gd project.godot
git commit -m "feat: add WeaponRegistry autoload with 4 weapon definitions"
```

---

## Task 2: Migrate Player + Config to WeaponRegistry

**Files:**
- Modify: `src/entities/player.gd`
- Modify: `src/config/game_config.gd`
- Modify: `src/levels/generated_level.gd`

- [ ] **Step 1: Migrate player._equip_weapon() to use WeaponRegistry**

In `src/entities/player.gd`, change `_equip_weapon()` to read from `WeaponRegistry` instead of `Config.weapon_presets`:

```gdscript
func _equip_weapon(index: int) -> void:
    if index >= WeaponRegistry.weapon_count():
        return
    _current_weapon_index = index
    var weapon_def = WeaponRegistry.get_weapon(index)
    var weapon := get_component(C_Weapon) as C_Weapon
    var ps := get_component(C_PlayerStats) as C_PlayerStats
    weapon.damage = int(weapon_def.damage * (ps.damage_mult if ps else 1.0))
    weapon.fire_rate = weapon_def.fire_rate * (1.0 / (1.0 + (ps.fire_rate_bonus if ps else 0.0)))
    weapon.projectile_speed = weapon_def.speed * (1.0 + (ps.proj_speed_bonus if ps else 0.0))
    weapon.element = weapon_def.element
    weapon.cooldown_remaining = 0.0
    # Update visual
    var wv := get_component(C_WeaponVisual) as C_WeaponVisual
    if wv:
        wv.weapon_index = index
        wv.element = weapon_def.element
```

Also change `_input()` loop: `for i in range(Config.weapon_presets.size())` → `for i in range(WeaponRegistry.weapon_count())`

- [ ] **Step 2: Migrate armed monster spawning in generated_level.gd**

Change `Config.weapon_presets[weapon_index]` references to `WeaponRegistry.get_weapon(weapon_index)` in `_spawn_monsters()`.

- [ ] **Step 3: Remove weapon_presets from game_config.gd**

Remove the `weapon_presets` array from `game_config.gd`. Also remove `monster_weapon_presets` (move to use `WeaponRegistry.weapon_count()` for the range).

- [ ] **Step 4: Verify the game still works — run manually**

- [ ] **Step 5: Commit**

```bash
git add src/entities/player.gd src/config/game_config.gd src/levels/generated_level.gd
git commit -m "refactor: migrate weapon reads to WeaponRegistry, remove Config.weapon_presets"
```

---

## Task 3: Migrate Crosshair + HUD to WeaponRegistry

**Files:**
- Modify: `src/ui/crosshair.gd`
- Modify: `src/ui/hud.gd`
- Modify: `src/effects/weapon_model_factory.gd`
- Modify: `src/systems/s_weapon_visual.gd`

- [ ] **Step 1: Replace crosshair match block**

In `src/ui/crosshair.gd`, replace the `match _current_index:` block in `_rebuild()` with:

```gdscript
func _rebuild():
    for child in get_children():
        child.queue_free()
    var weapon_def = WeaponRegistry.get_weapon(_current_index)
    if weapon_def and weapon_def.build_crosshair.is_valid():
        weapon_def.build_crosshair.call(self)
    _apply_tint()
```

The existing `_build_pistol()`, `_build_flamethrower()`, etc. methods stay in crosshair.gd. Register them as Callables in WeaponRegistry._register_weapons():

```gdscript
pistol.build_crosshair = CrosshairManager._build_pistol
```

Wait — `CrosshairManager` is a class name but crosshair methods take `self` (the instance). The Callables need to be bound to the instance. Instead, have `_rebuild()` pass `self` and the methods accept it as a parameter. Or use a simpler approach: keep the match in crosshair.gd for now and just call `WeaponRegistry.get_weapon(index)` to verify the index is valid. Actually the simplest: store the crosshair builder as a static function that takes the parent Control:

```gdscript
# In weapon_registry._register_weapons():
pistol.build_crosshair = func(parent: Control): CrosshairBuilder.build_pistol(parent)
```

Where `CrosshairBuilder` is the renamed crosshair build logic. But this is getting complex. Simpler approach: leave the `_build_*` methods as instance methods on CrosshairManager, and in the registry store the method NAME as a StringName:

Actually simplest: just eliminate the match. The crosshair already has `set_weapon(index, element)` called from HUD. Just change `_rebuild()`:

```gdscript
func _rebuild():
    for child in get_children():
        child.queue_free()
    match _current_index:
        0: _build_pistol()
        1: _build_flamethrower()
        2: _build_ice_rifle()
        3: _build_water_gun()
    _apply_tint()
```

This match stays for now since crosshair shapes are instance methods that use `self` extensively (adding children to the Control). Moving them to Callables would require passing the parent node. This is a Phase 2 compromise — the match stays but is the ONLY remaining match. Document this as tech debt for a future cleanup.

REVISED: Keep crosshair match as-is. Only change HUD.

- [ ] **Step 2: Replace HUD weapon slot hardcoded range(4)**

In `src/ui/hud.gd`, find `for i in range(4):` in `_build_weapon_panel()` and change to `for i in range(WeaponRegistry.weapon_count()):`.

- [ ] **Step 3: Replace WeaponModelFactory public methods in S_WeaponVisual**

In `src/systems/s_weapon_visual.gd`, change `_swap_weapon()`:

Before:
```gdscript
new_node = WeaponModelFactory.create_viewmodel(wv.weapon_index, wv.element)
# or
new_node = WeaponModelFactory.create_world_model(wv.weapon_index, wv.element)
```

After:
```gdscript
var weapon_def = WeaponRegistry.get_weapon(wv.weapon_index)
if weapon_def:
    if wv.show_viewmodel:
        new_node = weapon_def.build_viewmodel.call()
    else:
        new_node = weapon_def.build_world_model.call()
```

- [ ] **Step 4: Replace WeaponModelFactory.create_hud_icon in HUD**

In `hud.gd`, change the HUD icon creation from `WeaponModelFactory.create_hud_icon(idx, element_str)` to `WeaponRegistry.get_weapon(idx).build_hud_icon.call()`.

- [ ] **Step 5: Remove public create_* methods from WeaponModelFactory**

Remove `create_viewmodel()`, `create_world_model()`, `create_hud_icon()` from `weapon_model_factory.gd`. Keep all private `_build_*` methods.

- [ ] **Step 6: Commit**

```bash
git add src/ui/crosshair.gd src/ui/hud.gd src/systems/s_weapon_visual.gd src/effects/weapon_model_factory.gd
git commit -m "refactor: HUD + S_WeaponVisual use WeaponRegistry, remove factory public methods"
```

---

## Task 4: ModifierRegistry Autoload

**Files:**
- Create: `src/config/modifier_registry.gd`
- Modify: `project.godot`
- Modify: `test/unit/test_registries.gd`

- [ ] **Step 1: Create modifier_registry.gd**

Create `src/config/modifier_registry.gd` with all 6 modifier definitions. Read the current match blocks in `run_manager.gd`, `tile_rules.gd`, `level_generator.gd` to extract the exact values for each modifier.

The boss modifier's `pin_rooms_override` Callable contains the 5x5 block pinning logic currently in `level_generator._generate_room_seeds()`.

- [ ] **Step 2: Register autoload**

Add `ModifierRegistry="*res://src/config/modifier_registry.gd"` to `project.godot`.

- [ ] **Step 3: Add tests**

Append to `test/unit/test_registries.gd`:

```gdscript
func test_modifier_registry_has_6_modifiers():
    assert_eq(ModifierRegistry.get_all_names().size(), 6)

func test_modifier_registry_get_normal():
    var m = ModifierRegistry.get_modifier(Modifiers.NORMAL)
    assert_not_null(m)
    assert_eq(m.grid_width, 12)

func test_modifier_registry_get_dense():
    var m = ModifierRegistry.get_modifier(Modifiers.DENSE)
    assert_not_null(m)
    assert_eq(m.monsters_per_room, 2)

func test_modifier_registry_boss_has_pin_override():
    var m = ModifierRegistry.get_modifier(Modifiers.BOSS)
    assert_not_null(m)
    assert_true(m.pin_rooms_override.is_valid())

func test_modifier_registry_spawnable_excludes_boss():
    var spawnable = ModifierRegistry.get_spawnable_names()
    assert_false(Modifiers.BOSS in spawnable)
    assert_true(Modifiers.NORMAL in spawnable)
```

- [ ] **Step 4: Commit**

```bash
git add src/config/modifier_registry.gd project.godot test/unit/test_registries.gd
git commit -m "feat: add ModifierRegistry autoload with 6 modifier definitions"
```

---

## Task 5: Migrate Modifier Consumers

**Files:**
- Modify: `src/run/run_manager.gd`
- Modify: `src/generation/tile_rules.gd`
- Modify: `src/generation/level_generator.gd`
- Modify: `src/run/run_map.gd`
- Modify: `src/config/game_config.gd`

- [ ] **Step 1: Replace run_manager._apply_modifier()**

Replace the entire match block with registry lookup. See spec section 2 for the exact code.

- [ ] **Step 2: Replace tile_rules.get_profile_weights()**

Replace the match block with `ModifierRegistry.get_modifier(modifier_name).tile_weights`. Also refactor `setup_profile()` to use the registry.

- [ ] **Step 3: Replace level_generator._generate_room_seeds()**

Replace the match block with registry lookup of `room_count_range`, `room_min_dist`, and `pin_rooms_override`.

- [ ] **Step 4: Replace run_map modifier selection**

Replace the hardcoded `all_modifiers` list with `ModifierRegistry.get_spawnable_names()`.

- [ ] **Step 5: Remove modifier enum from game_config.gd**

The `@export_enum("normal","dense","large","dark","horde","boss")` annotation on `current_modifier` can stay (it's for the editor dropdown) but should read from the registry if possible. At minimum keep it as-is since it's display-only.

- [ ] **Step 6: Commit**

```bash
git add src/run/run_manager.gd src/generation/tile_rules.gd src/generation/level_generator.gd src/run/run_map.gd src/config/game_config.gd
git commit -m "refactor: migrate all modifier match blocks to ModifierRegistry lookups"
```

---

## Task 6: ElementRegistry Refactor

**Files:**
- Modify: `src/config/element_registry.gd`

- [ ] **Step 1: Refactor internals to use ElementDefinition**

Replace raw dictionaries with `ElementDefinition` instances. Keep the public API (`get_element()`, `add_element()`, `add_interaction()`) but change the return type and internal storage.

The `_setup_defaults()` method creates `ElementDefinition` instances:
```gdscript
var fire = ElementDefinition.new()
fire.element_name = ElementNames.FIRE
fire.display_name = "Fire"
fire.condition_name = ConditionNames.BURNING
fire.condition_duration = 5.0
fire.default_color = Color(1.0, 0.5, 0.1)
fire.damage_per_tick = 2.0
_elements[fire.element_name] = fire
```

- [ ] **Step 2: Update callers if return type changed**

Check all callers of `ElementRegistry.get_element()` — they currently get a Dictionary. If changing to `ElementDefinition`, update field access (`.name` → `.element_name`, etc.).

- [ ] **Step 3: Commit**

```bash
git add src/config/element_registry.gd
git commit -m "refactor: ElementRegistry internals use ElementDefinition"
```

---

## Task 7: Remove Element Color Fallbacks from WeaponModelFactory

**Files:**
- Modify: `src/effects/weapon_model_factory.gd`

- [ ] **Step 1: Delete _get_element_color and _get_element_icon_color**

Remove the two static functions with hardcoded `match element:` blocks. Replace all call sites with `ThemeManager.active_theme.get_element_color(element)`.

- [ ] **Step 2: Commit**

```bash
git add src/effects/weapon_model_factory.gd
git commit -m "refactor: remove hardcoded element color fallbacks from WeaponModelFactory"
```

---

## Task 8: MonsterVariant Migration

**Files:**
- Modify: `src/themes/theme_data.gd`
- Modify: `src/themes/theme_manager.gd`
- Modify: `src/levels/generated_level.gd`
- Modify: `themes/neon/neon_theme.gd`
- Modify: `themes/stone/stone_theme.gd`
- Modify: `themes/folk/folk_theme.gd`

- [ ] **Step 1: Change ThemeData.monster_scenes to monster_variants**

In `theme_data.gd`, replace `var monster_scenes: Dictionary = {}` with `var monster_variants: Array = []`.

- [ ] **Step 2: Update ThemeManager**

Change `get_monster_scene()` to iterate `monster_variants` by `variant_key`. Add `get_spawnable_variants()` method.

- [ ] **Step 3: Update generated_level.gd**

Replace hardcoded 50/25/25 probability with weighted random selection from `ThemeManager.get_spawnable_variants()`.

- [ ] **Step 4: Migrate all 3 theme factories**

Convert `monster_scenes = {"basic": load(...)}` to `monster_variants.append(MonsterVariantDefinition.new())` pattern in neon_theme.gd, stone_theme.gd, and folk_theme.gd.

- [ ] **Step 5: Commit**

```bash
git add src/themes/theme_data.gd src/themes/theme_manager.gd src/levels/generated_level.gd themes/neon/neon_theme.gd themes/stone/stone_theme.gd themes/folk/folk_theme.gd
git commit -m "refactor: migrate monster_scenes to MonsterVariantDefinition array"
```

---

## Task 9: String Literal → StringName Constants Migration

**Files:** ~25 files across the codebase

- [ ] **Step 1: Migrate element string literals**

Find all `"fire"`, `"ice"`, `"water"`, `"oil"` used as identifiers (not display text) and replace with `ElementNames.FIRE`, etc. Files: element_registry.gd, s_damage.gd, game_config.gd (weapon_registry now), folk_theme.gd, neon_theme.gd, stone_theme.gd, vfx_factory.gd, damage_number_factory.gd.

- [ ] **Step 2: Migrate condition string literals**

Find all `"burning"`, `"frozen"`, `"wet"`, `"oily"` and replace with `ConditionNames.*`. Files: element_registry.gd, s_conditions.gd, s_damage.gd.

- [ ] **Step 3: Migrate modifier string literals**

Find all `"normal"`, `"dense"`, `"large"`, `"dark"`, `"horde"`, `"boss"` used as identifiers and replace with `Modifiers.*`. Files: run_manager.gd, run_map.gd, level_generator.gd, tile_rules.gd, generated_level.gd, game_config.gd, level_playground.gd.

- [ ] **Step 4: Migrate wall/light/floor style string literals**

Find all `"default"`, `"forest_thicket"`, `"palace_ornate"`, `"ice_crystal"`, `"floating"`, `"torch"`, `"mushroom"`, `"crystal"`, `"plain"`, `"cracked_slab"` and replace with constants. Files: level_builder.gd, theme_data.gd, folk_theme.gd, stone_theme.gd, level_playground.gd.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: replace all identifier string literals with StringName constants"
```
