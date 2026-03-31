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

func _register_modifiers() -> void:
    # Normal
    var normal = ModifierDefinition.new()
    normal.modifier_name = Modifiers.NORMAL
    normal.display_name = "Normal"
    normal.tile_weights = { "room": 1.5, "spawn": 1.5, "cor": 0.4, "door": 0.2, "wall": 3.5, "empty": 1.0 }
    normal.grid_width = 12
    normal.grid_height = 12
    normal.monsters_per_room = 1
    normal.max_monsters_per_level = 5
    normal.monster_hp_mult = 1.0
    normal.monster_damage_mult = 1.0
    normal.light_range_mult = 1.0
    normal.room_count_range = Vector2i(4, 7)
    normal.room_min_dist = 4
    normal.map_weight = 0.50
    _modifiers[normal.modifier_name] = normal

    # Dense
    var dense = ModifierDefinition.new()
    dense.modifier_name = Modifiers.DENSE
    dense.display_name = "Dense"
    dense.tile_weights = { "room": 2.5, "spawn": 2.5, "cor": 0.3, "door": 0.5, "wall": 2.0, "empty": 0.5 }
    dense.grid_width = 12
    dense.grid_height = 12
    dense.monsters_per_room = 2
    dense.max_monsters_per_level = 5
    dense.monster_hp_mult = 1.0
    dense.monster_damage_mult = 1.0
    dense.light_range_mult = 1.0
    dense.room_count_range = Vector2i(6, 9)
    dense.room_min_dist = 3
    dense.map_weight = 0.20
    _modifiers[dense.modifier_name] = dense

    # Large
    var large = ModifierDefinition.new()
    large.modifier_name = Modifiers.LARGE
    large.display_name = "Large"
    large.tile_weights = { "room": 1.0, "spawn": 1.0, "cor": 0.8, "door": 0.3, "wall": 3.0, "empty": 1.5 }
    large.grid_width = 16
    large.grid_height = 16
    large.monsters_per_room = 1
    large.max_monsters_per_level = 5
    large.monster_hp_mult = 1.0
    large.monster_damage_mult = 1.0
    large.light_range_mult = 1.0
    large.room_count_range = Vector2i(3, 5)
    large.room_min_dist = 5
    large.map_weight = 0.15
    _modifiers[large.modifier_name] = large

    # Dark
    var dark = ModifierDefinition.new()
    dark.modifier_name = Modifiers.DARK
    dark.display_name = "Dark"
    dark.tile_weights = { "room": 0.8, "spawn": 0.8, "cor": 0.5, "door": 0.15, "wall": 4.0, "empty": 1.5 }
    dark.grid_width = 12
    dark.grid_height = 12
    dark.monsters_per_room = 1
    dark.max_monsters_per_level = 5
    dark.monster_hp_mult = 1.0
    dark.monster_damage_mult = 1.0
    dark.light_range_mult = 0.5
    dark.room_count_range = Vector2i(5, 8)
    dark.room_min_dist = 3
    dark.map_weight = 0.10
    _modifiers[dark.modifier_name] = dark

    # Horde
    var horde = ModifierDefinition.new()
    horde.modifier_name = Modifiers.HORDE
    horde.display_name = "Horde"
    horde.tile_weights = { "room": 3.0, "spawn": 3.0, "cor": 0.3, "door": 0.6, "wall": 2.0, "empty": 0.3 }
    horde.grid_width = 12
    horde.grid_height = 12
    horde.monsters_per_room = 3
    horde.max_monsters_per_level = 5
    horde.monster_hp_mult = 0.5
    horde.monster_damage_mult = 1.0
    horde.light_range_mult = 1.0
    horde.room_count_range = Vector2i(3, 5)
    horde.room_min_dist = 5
    horde.map_weight = 0.05
    _modifiers[horde.modifier_name] = horde

    # Boss
    var boss = ModifierDefinition.new()
    boss.modifier_name = Modifiers.BOSS
    boss.display_name = "Boss"
    boss.tile_weights = { "room": 3.0, "spawn": 3.0, "cor": 0.2, "door": 0.3, "wall": 2.5, "empty": 0.5 }
    boss.grid_width = 14
    boss.grid_height = 14
    boss.monsters_per_room = 3
    boss.max_monsters_per_level = 0
    boss.monster_hp_mult = 2.0
    boss.monster_damage_mult = 1.0
    boss.light_range_mult = 1.0
    boss.room_count_range = Vector2i(1, 1)
    boss.room_min_dist = 0
    boss.map_weight = 0.0
    boss.pin_rooms_override = func(rng: RandomNumberGenerator, width: int, height: int) -> Dictionary:
        var pinned: Dictionary = {}
        var cx = int(width / 2.0)
        var cy = int(height / 2.0)
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
    _modifiers[boss.modifier_name] = boss
