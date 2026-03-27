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
