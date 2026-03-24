class_name GameConfig
extends Node

# Movement
@export var player_speed: float = 5.0
@export var jump_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 9.8

# Health
@export var player_max_health: int = 100

# Multiplayer
@export var max_players: int = 4

# Weapon presets
var weapon_presets: Array[Dictionary] = [
	{"name": "Pistol", "damage": 10, "fire_rate": 0.3, "speed": 40.0, "element": ""},
	{"name": "Flamethrower", "damage": 5, "fire_rate": 0.1, "speed": 25.0, "element": "fire"},
	{"name": "Ice Rifle", "damage": 15, "fire_rate": 0.8, "speed": 35.0, "element": "ice"},
	{"name": "Water Gun", "damage": 3, "fire_rate": 0.05, "speed": 30.0, "element": "water"},
]

# Level generation
@export var level_grid_width: int = 12
@export var level_grid_height: int = 12
@export var level_tile_size: float = 4.0
@export var level_seed: int = 0  # 0 = random seed
@export var monsters_per_room: int = 1
@export var max_monsters_per_level: int = 5

# Run loop
@export var boss_depth: int = 4
@export var shop_frequency: int = 2
@export var kill_reward_base: int = 10
@export var meta_currency_rate: float = 0.1

# Modifier support (set by RunManager before level load)
var current_modifier: String = "normal"
var light_range_mult: float = 1.0
var monster_hp_mult: float = 1.0

# Debug
var god_mode: bool = true
