# Theme/Biome Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce ThemeGroup to wrap multiple ThemeData biomes per theme, enabling multi-biome themes like Russian Folk Tales while keeping existing single-biome themes working unchanged.

**Architecture:** New ThemeGroup class wraps Array[ThemeData]. ThemeManager gains group awareness (available_groups, active_group, set_biome). MapNode gains biome_index assigned during map generation. RunManager sets the biome before level load. All existing code reading ThemeManager.active_theme is untouched.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS framework, GUT for tests

**Spec:** `docs/superpowers/specs/2026-03-26-theme-biome-refactor-design.md`

**Indentation rules:**
- TABS: `lobby_ui.gd`, `game_config.gd`
- 4-SPACES: all new files, `theme_manager.gd`, `run_map.gd`, `run_manager.gd`, `map_screen.gd`, `theme_data.gd`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `src/themes/theme_group.gd` | ThemeGroup class — wraps biomes under a theme name |
| `test/unit/test_theme_biome.gd` | GUT tests for ThemeGroup and biome selection |

### Modified Files

| File | Changes |
|------|---------|
| `src/themes/theme_data.gd` | Add `biome_name: String` property |
| `src/themes/theme_manager.gd` | Add `available_groups`, `active_group`, `set_biome()`, rewrite `_load_themes()` and `set_theme()` |
| `src/run/run_map.gd` | Add `biome_index` to MapNode, assign in generation |
| `src/run/run_manager.gd` | Call `ThemeManager.set_biome()` before level start |
| `src/ui/map_screen.gd` | Show biome name on multi-biome nodes |
| `src/ui/lobby_ui.gd` | Dropdown uses group names |
| `themes/neon/neon_theme.gd` | Set `biome_name = "Neon"` |
| `themes/stone/stone_theme.gd` | Set `biome_name = "Stone"` |

---

## Task 1: ThemeGroup Class + ThemeData.biome_name + Tests

**Files:**
- Create: `src/themes/theme_group.gd`
- Create: `test/unit/test_theme_biome.gd`
- Modify: `src/themes/theme_data.gd`

- [ ] **Step 1: Create test file**

Create `test/unit/test_theme_biome.gd`:

```gdscript
extends GutTest

func test_theme_group_defaults():
    var g = ThemeGroup.new()
    assert_eq(g.group_name, "")
    assert_eq(g.biomes.size(), 0)

func test_theme_group_get_biome():
    var g = ThemeGroup.new()
    var b1 = ThemeData.new()
    b1.biome_name = "Forest"
    var b2 = ThemeData.new()
    b2.biome_name = "Palace"
    g.biomes = [b1, b2]
    assert_eq(g.get_biome(0).biome_name, "Forest")
    assert_eq(g.get_biome(1).biome_name, "Palace")
    # Out of range falls back to first
    assert_eq(g.get_biome(99).biome_name, "Forest")

func test_theme_group_get_random_biome():
    var g = ThemeGroup.new()
    var b = ThemeData.new()
    b.biome_name = "Only"
    g.biomes = [b]
    assert_eq(g.get_random_biome().biome_name, "Only")

func test_theme_group_empty_returns_null():
    var g = ThemeGroup.new()
    assert_null(g.get_random_biome())
    assert_null(g.get_biome(0))

func test_theme_data_has_biome_name():
    var t = ThemeData.new()
    assert_eq(t.biome_name, "")
    t.biome_name = "Test"
    assert_eq(t.biome_name, "Test")
```

- [ ] **Step 2: Add biome_name to ThemeData**

In `src/themes/theme_data.gd` (4-spaces), add after `theme_name`:

```gdscript
@export var biome_name: String = ""
```

- [ ] **Step 3: Create ThemeGroup**

Create `src/themes/theme_group.gd`:

```gdscript
class_name ThemeGroup
extends RefCounted

var group_name: String = ""
var description: String = ""
var biomes: Array[ThemeData] = []

func get_random_biome() -> ThemeData:
    if biomes.is_empty():
        return null
    return biomes[randi() % biomes.size()]

func get_biome(index: int) -> ThemeData:
    if index >= 0 and index < biomes.size():
        return biomes[index]
    return biomes[0] if not biomes.is_empty() else null
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_theme_biome.gd
```

- [ ] **Step 5: Commit**

```bash
git add src/themes/theme_group.gd src/themes/theme_data.gd test/unit/test_theme_biome.gd
git commit -m "feat: add ThemeGroup class and biome_name property on ThemeData"
```

---

## Task 2: ThemeManager — Add Group Support

**Files:**
- Modify: `src/themes/theme_manager.gd`
- Modify: `themes/neon/neon_theme.gd`
- Modify: `themes/stone/stone_theme.gd`

- [ ] **Step 1: Set biome_name in existing theme factories**

In `themes/neon/neon_theme.gd` (4-spaces), add after `t.theme_name = ...`:

```gdscript
    t.biome_name = "Neon"
```

In `themes/stone/stone_theme.gd` (4-spaces), add after `t.theme_name = ...`:

```gdscript
    t.biome_name = "Stone"
```

- [ ] **Step 2: Rewrite ThemeManager**

Replace the entire `src/themes/theme_manager.gd` with:

```gdscript
extends Node

signal theme_changed(theme: ThemeData)

var active_theme: ThemeData
var available_themes: Array[ThemeData] = []

var active_group: ThemeGroup
var available_groups: Array[ThemeGroup] = []

func _ready() -> void:
    _load_themes()
    if available_groups.size() > 0:
        active_group = available_groups[0]
        active_theme = active_group.biomes[0]
        TextureFactory.generate_for_theme(active_theme)

func set_theme(theme_name_to_set: String) -> void:
    # Search by group name
    for group in available_groups:
        if group.group_name == theme_name_to_set:
            active_group = group
            active_theme = group.biomes[0]
            TextureFactory.generate_for_theme(active_theme)
            theme_changed.emit(active_theme)
            return
    # Fallback: search by biome name
    for biome in active_group.biomes:
        if biome.theme_name == theme_name_to_set or biome.biome_name == theme_name_to_set:
            set_biome(biome)
            return

func set_biome(biome: ThemeData) -> void:
    active_theme = biome
    TextureFactory.generate_for_theme(biome)
    theme_changed.emit(active_theme)

func get_palette() -> Array[Color]:
    return active_theme.get_palette_array()

func get_monster_scene(type: String) -> PackedScene:
    if active_theme.monster_scenes.has(type):
        return active_theme.monster_scenes[type]
    return null

func get_projectile_scene() -> PackedScene:
    return active_theme.projectile_scene

func _load_themes() -> void:
    var neon_biome = NeonTheme.create()
    var neon_group = ThemeGroup.new()
    neon_group.group_name = "Neon Dungeon"
    neon_group.description = "Glowing neon corridors"
    neon_group.biomes = [neon_biome]
    available_groups.append(neon_group)

    var stone_biome = StoneTheme.create()
    var stone_group = ThemeGroup.new()
    stone_group.group_name = "Stone Dungeon"
    stone_group.description = "Ancient stone halls"
    stone_group.biomes = [stone_biome]
    available_groups.append(stone_group)

    # Flat list for backward compat
    for group in available_groups:
        available_themes.append_array(group.biomes)

    active_group = available_groups[0]
    active_theme = active_group.biomes[0]
```

- [ ] **Step 3: Verify existing theming tests pass**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_theming.gd
```

All existing theming tests should pass since `active_theme` and `available_themes` still work.

- [ ] **Step 4: Commit**

```bash
git add src/themes/theme_manager.gd themes/neon/neon_theme.gd themes/stone/stone_theme.gd
git commit -m "feat: add ThemeGroup support to ThemeManager with backward-compatible API"
```

---

## Task 3: MapNode biome_index + RunManager Integration

**Files:**
- Modify: `src/run/run_map.gd`
- Modify: `src/run/run_manager.gd`

- [ ] **Step 1: Add biome_index to MapNode**

In `src/run/run_map.gd` (4-spaces), add to the MapNode class after `var visited`:

```gdscript
    var biome_index: int = 0
```

- [ ] **Step 2: Assign random biome in map generation**

In `RunMap.generate()`, after setting the modifier for each node (after `node.modifier = _random_modifier_excluding(used_modifiers)`), add:

```gdscript
            var biome_count = ThemeManager.active_group.biomes.size() if ThemeManager and ThemeManager.active_group else 1
            node.biome_index = randi() % biome_count
```

Also for the boss node, after `boss_node.modifier = "boss"`:

```gdscript
    var biome_count = ThemeManager.active_group.biomes.size() if ThemeManager and ThemeManager.active_group else 1
    boss_node.biome_index = randi() % biome_count
```

- [ ] **Step 3: Set biome before level load in RunManager**

In `src/run/run_manager.gd` (4-spaces), in `select_map_node()`, add after `_apply_modifier(node.modifier)` and before `Config.level_seed = node.level_seed`:

```gdscript
    if ThemeManager and ThemeManager.active_group:
        var biome = ThemeManager.active_group.get_biome(node.biome_index)
        if biome:
            ThemeManager.set_biome(biome)
```

- [ ] **Step 4: Commit**

```bash
git add src/run/run_map.gd src/run/run_manager.gd
git commit -m "feat: assign random biome per map node, set biome before level load"
```

---

## Task 4: Map Screen + Lobby UI

**Files:**
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/lobby_ui.gd`

- [ ] **Step 1: Show biome name on map nodes**

In `src/ui/map_screen.gd` (4-spaces), after `btn.text = node.modifier.to_upper()` (line 78), add:

```gdscript
            if ThemeManager and ThemeManager.active_group and ThemeManager.active_group.biomes.size() > 1:
                var biome = ThemeManager.active_group.get_biome(node.biome_index)
                if biome:
                    btn.text += "\n[%s]" % biome.biome_name
```

- [ ] **Step 2: Update lobby dropdown to use groups**

In `src/ui/lobby_ui.gd` (TABS), replace the theme dropdown section:

Change:
```gdscript
	var available = ThemeManager.available_themes
	var current_idx = 0
	for i in range(available.size()):
		theme_option.add_item(available[i].theme_name)
		if available[i] == ThemeManager.active_theme:
			current_idx = i
	theme_option.selected = current_idx
	theme_option.item_selected.connect(_on_theme_selected.bind(available))
```

To:
```gdscript
	var groups = ThemeManager.available_groups
	var current_idx = 0
	for i in range(groups.size()):
		theme_option.add_item(groups[i].group_name)
		if groups[i] == ThemeManager.active_group:
			current_idx = i
	theme_option.selected = current_idx
	theme_option.item_selected.connect(_on_theme_selected.bind(groups))
```

And update `_on_theme_selected`:

```gdscript
func _on_theme_selected(index: int, groups: Array):
	if index >= 0 and index < groups.size():
		ThemeManager.set_theme(groups[index].group_name)
```

- [ ] **Step 3: Verify manually**

Run the game. Verify:
1. Lobby dropdown shows "Neon Dungeon" and "Stone Dungeon" (group names)
2. Switching themes still works
3. Map screen shows modifier names on nodes (no biome label since single-biome themes)
4. Playing a level uses the correct theme visuals

- [ ] **Step 4: Commit**

```bash
git add src/ui/map_screen.gd src/ui/lobby_ui.gd
git commit -m "feat: map shows biome name on multi-biome nodes, lobby uses group names"
```

---

## Task 5: Integration Tests

**Files:**
- Modify: `test/unit/test_theme_biome.gd`

- [ ] **Step 1: Add integration tests**

Append to `test/unit/test_theme_biome.gd`:

```gdscript
# --- ThemeManager group integration ---

func test_theme_manager_has_groups():
    assert_true(ThemeManager.available_groups.size() >= 2, "Should have at least 2 theme groups")

func test_theme_manager_active_group_not_null():
    assert_not_null(ThemeManager.active_group)
    assert_true(ThemeManager.active_group.biomes.size() > 0)

func test_theme_manager_set_theme_by_group_name():
    ThemeManager.set_theme("Stone Dungeon")
    assert_eq(ThemeManager.active_group.group_name, "Stone Dungeon")
    assert_eq(ThemeManager.active_theme.biome_name, "Stone")
    # Reset
    ThemeManager.set_theme("Neon Dungeon")

func test_theme_manager_set_biome():
    var biome = ThemeManager.active_group.biomes[0]
    ThemeManager.set_biome(biome)
    assert_eq(ThemeManager.active_theme, biome)

func test_existing_themes_have_biome_name():
    for group in ThemeManager.available_groups:
        for biome in group.biomes:
            assert_true(biome.biome_name != "", "%s should have biome_name" % group.group_name)

func test_backward_compat_available_themes():
    assert_true(ThemeManager.available_themes.size() >= 2, "Flat list should have all biomes")
    for t in ThemeManager.available_themes:
        assert_true(t is ThemeData)
```

- [ ] **Step 2: Run all biome tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_theme_biome.gd
```

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_theme_biome.gd
git commit -m "test: add integration tests for ThemeGroup and biome selection"
```
