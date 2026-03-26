class_name GameConfig
extends Node

@export_group("Movement")
@export_range(1.0, 20.0, 0.5) var player_speed: float = 5.0
@export_range(1.0, 20.0, 0.5) var jump_speed: float = 5.0
@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity: float = 0.002
@export_range(1.0, 30.0, 0.5) var gravity: float = 9.8

@export_group("Health")
@export_range(10, 1000, 10) var player_max_health: int = 100

@export_group("Multiplayer")
@export_range(1, 8, 1) var max_players: int = 4

@export_group("Grid")
@export_range(4, 32, 1) var level_grid_width: int = 12
@export_range(4, 32, 1) var level_grid_height: int = 12
@export_range(1.0, 10.0, 0.5) var level_tile_size: float = 4.0
@export_range(0, 999999, 1) var level_seed: int = 0

@export_group("Monsters")
@export_range(0, 10, 1) var monsters_per_room: int = 1
@export_range(0, 50, 1) var max_monsters_per_level: int = 5
@export_range(0.1, 10.0, 0.1) var monster_hp_mult: float = 1.0
@export_range(0.1, 10.0, 0.1) var monster_damage_mult: float = 1.0
@export_range(0.0, 1.0, 0.05) var monster_weapon_chance: float = 0.3
@export_range(0.5, 10.0, 0.5) var monster_ranged_cooldown: float = 3.0
@export_range(1, 50, 1) var monster_ranged_damage: int = 8

@export_group("Run Loop")
@export_range(1, 20, 1) var boss_depth: int = 4
@export_range(1, 10, 1) var shop_frequency: int = 2
@export_range(1, 100, 1) var kill_reward_base: int = 10
@export_range(0.0, 1.0, 0.05) var meta_currency_rate: float = 0.1

@export_group("Lighting")
@export_range(0.1, 5.0, 0.1) var light_range_mult: float = 1.0

@export_group("Modifier")
@export_enum("normal", "dense", "large", "dark", "horde", "boss") var current_modifier: String = "normal"

@export_group("Debug")
@export var god_mode: bool = true

# Non-UI properties (complex types, not auto-discovered)
var weapon_presets: Array[Dictionary] = [
	{"name": "Pistol", "damage": 10, "fire_rate": 0.3, "speed": 40.0, "element": ""},
	{"name": "Flamethrower", "damage": 5, "fire_rate": 0.1, "speed": 25.0, "element": "fire"},
	{"name": "Ice Rifle", "damage": 15, "fire_rate": 0.8, "speed": 35.0, "element": "ice"},
	{"name": "Water Gun", "damage": 3, "fire_rate": 0.05, "speed": 30.0, "element": "water"},
]
var monster_weapon_presets: Array[int] = [0, 1, 2, 3]
