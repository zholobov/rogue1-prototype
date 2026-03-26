# Theme/Biome Refactor — Design Spec

## Goal

Introduce a `ThemeGroup` concept that wraps multiple `ThemeData` instances (biomes) under one theme. A theme like "Russian Folk Tales" can have 3 biomes (Dark Forest, Golden Palace, Winter Realm), each with its own colors, materials, monsters, and textures. Each level in a run uses a biome selected at the map node. Existing single-biome themes (Neon, Stone) work unchanged.

## Scope

- New `ThemeGroup` class wrapping `Array[ThemeData]`
- `ThemeManager` gains group awareness while keeping `active_theme` API unchanged
- `MapNode` gains `biome_index` for per-level biome selection
- Map UI shows biome name on nodes
- Lobby dropdown uses group names
- Zero changes to any system that reads `ThemeManager.active_theme`

Not covered: the Russian Folk Tales content itself (separate spec).

---

## 1. ThemeGroup Class

File: `src/themes/theme_group.gd` (4-space indentation)

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

Lightweight container. No logic beyond random selection and safe access.

---

## 2. ThemeData Changes

File: `src/themes/theme_data.gd`

Add one property:

```gdscript
@export var biome_name: String = ""
```

This is the biome's display name (e.g., "Neon", "Stone", "Dark Forest"). Shown on map nodes. Existing `theme_name` remains and is used for the group name.

Existing theme factories set it:
- `neon_theme.gd`: `t.biome_name = "Neon"`
- `stone_theme.gd`: `t.biome_name = "Stone"`

---

## 3. ThemeManager Changes

File: `src/themes/theme_manager.gd`

### New Properties

```gdscript
var available_groups: Array[ThemeGroup] = []
var active_group: ThemeGroup
```

### Existing Properties (kept for backward compatibility)

```gdscript
var active_theme: ThemeData          # the current biome — unchanged
var available_themes: Array[ThemeData]  # flat list of all biomes — unchanged
```

### Modified `_load_themes()`

```gdscript
func _load_themes() -> void:
    # Build groups
    var neon_biome = NeonTheme.create()
    neon_biome.biome_name = "Neon"
    var neon_group = ThemeGroup.new()
    neon_group.group_name = "Neon Dungeon"
    neon_group.description = "Glowing neon corridors"
    neon_group.biomes = [neon_biome]
    available_groups.append(neon_group)

    var stone_biome = StoneTheme.create()
    stone_biome.biome_name = "Stone"
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

### Modified `set_theme()`

```gdscript
func set_theme(theme_name_to_set: String) -> void:
    # Search by group name first
    for group in available_groups:
        if group.group_name == theme_name_to_set:
            active_group = group
            active_theme = group.biomes[0]
            theme_changed.emit(active_theme)
            return
    # Fallback: search by biome name in current group
    for biome in active_group.biomes:
        if biome.theme_name == theme_name_to_set or biome.biome_name == theme_name_to_set:
            active_theme = biome
            theme_changed.emit(active_theme)
            return
```

### New Method

```gdscript
func set_biome(biome: ThemeData) -> void:
    active_theme = biome
    theme_changed.emit(active_theme)
```

Called by `RunManager` when a level starts, to set the biome for that specific level.

### New Helper

```gdscript
func get_available_group_names() -> PackedStringArray:
    var names: PackedStringArray = []
    for group in available_groups:
        names.append(group.group_name)
    return names
```

---

## 4. RunMap / MapNode Changes

File: `src/run/run_map.gd`

### MapNode

Add `biome_index: int` to MapNode data:

```gdscript
# Existing:
level_seed: int
modifier: String
connections: Array[int]
visited: bool

# New:
biome_index: int   # index into ThemeManager.active_group.biomes
```

### Map Generation

In `RunMap.generate()`, when creating each MapNode, assign a random biome index:

```gdscript
var biome_count = ThemeManager.active_group.biomes.size() if ThemeManager else 1
node.biome_index = randi() % biome_count
```

For single-biome themes, every node gets `biome_index = 0`.

---

## 5. RunManager Changes

File: `src/run/run_manager.gd`

### Level Start

In `select_map_node()` (or wherever the level transition happens), before changing state to LEVEL/BOSS, set the biome:

```gdscript
var node = map.get_node(node_index)
if ThemeManager and ThemeManager.active_group:
    var biome = ThemeManager.active_group.get_biome(node.biome_index)
    if biome:
        ThemeManager.set_biome(biome)
```

This ensures `ThemeManager.active_theme` is set to the correct biome before `GeneratedLevel` reads it.

### Boss Level

Boss level always uses biome_index from the boss MapNode (last node in the map). No special handling needed — it's just another node with a biome_index.

---

## 6. Map Screen UI Changes

File: `src/ui/map_screen.gd`

Each map node button shows the biome name below the modifier label, but only when the active group has more than one biome:

```gdscript
if ThemeManager.active_group.biomes.size() > 1:
    var biome = ThemeManager.active_group.get_biome(node.biome_index)
    if biome:
        label.text += "\n[%s]" % biome.biome_name
```

For single-biome themes, nodes look exactly as they do now.

---

## 7. Lobby Theme Selector Changes

File: `src/ui/lobby_ui.gd`

The `OptionButton` dropdown currently lists `available_themes` (ThemeData instances). Change to list `available_groups` (ThemeGroup instances):

```gdscript
var available = ThemeManager.available_groups
for i in range(available.size()):
    theme_option.add_item(available[i].group_name)
    if available[i] == ThemeManager.active_group:
        current_idx = i
```

Handler calls `ThemeManager.set_theme(group_name)` as before.

---

## 8. New Files

| File | Responsibility |
|---|---|
| `src/themes/theme_group.gd` | ThemeGroup class — wraps biomes under a theme name |

## 9. Modified Files

| File | Changes |
|---|---|
| `src/themes/theme_data.gd` | Add `biome_name: String` property |
| `src/themes/theme_manager.gd` | Add `available_groups`, `active_group`, `set_biome()`, modify `_load_themes()` and `set_theme()` |
| `src/run/run_map.gd` | Add `biome_index` to MapNode, assign random biome in generation |
| `src/run/run_manager.gd` | Set biome via `ThemeManager.set_biome()` before level start |
| `src/ui/map_screen.gd` | Show biome name on multi-biome nodes |
| `src/ui/lobby_ui.gd` | Dropdown uses group names instead of biome names |
| `themes/neon/neon_theme.gd` | Set `biome_name = "Neon"` |
| `themes/stone/stone_theme.gd` | Set `biome_name = "Stone"` |

## 10. Backward Compatibility

- `ThemeManager.active_theme` — unchanged, always returns a `ThemeData`
- `ThemeManager.available_themes` — unchanged, flat list of all biomes across all groups
- `ThemeManager.theme_changed` signal — unchanged, emits `ThemeData`
- All systems reading `active_theme` — zero changes needed
- `ThemeData.theme_name` — kept, still works for all existing lookups
- Playground `ConfigSectionBuilder` — unchanged, reads from `ThemeManager.active_theme`
