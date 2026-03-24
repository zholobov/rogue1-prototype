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
