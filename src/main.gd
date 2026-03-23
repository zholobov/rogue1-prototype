extends Node

const TestLevel = preload("res://src/levels/test_level.tscn")
const PlayerScene = preload("res://src/entities/player.tscn")
const LobbyScene = preload("res://src/ui/lobby_ui.tscn")

var lobby_ui: Control
var current_level: Node3D
var is_solo: bool = false

func _ready():
	lobby_ui = LobbyScene.instantiate()
	add_child(lobby_ui)
	lobby_ui.game_started.connect(_on_game_started)

func _on_game_started(solo: bool):
	is_solo = solo
	lobby_ui.queue_free()
	_start_game()

func _start_game():
	current_level = TestLevel.instantiate()
	add_child(current_level)

	if is_solo:
		# Solo mode: use peer_id 1, no networking
		_spawn_player(1, true)
	else:
		# Multiplayer: spawn local + remote players
		_spawn_player(Net.my_peer_id, true)
		for peer_id in Net.peers:
			_spawn_player(peer_id, false)
		Net.player_connected.connect(_on_player_joined)
		Net.player_disconnected.connect(_on_player_left)

func _spawn_player(peer_id: int, is_local: bool) -> void:
	var player = PlayerScene.instantiate()
	player.name = "Player_%d" % peer_id
	var spawn = current_level.get_node("SpawnPoint")
	player.position = spawn.position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	current_level.add_child(player)
	player.setup(peer_id, is_local)

func _on_player_joined(peer_id: int):
	_spawn_player(peer_id, false)

func _on_player_left(peer_id: int):
	var player_node = current_level.get_node_or_null("Player_%d" % peer_id)
	if player_node:
		player_node.queue_free()
