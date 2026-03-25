extends Node

const GeneratedLevel = preload("res://src/levels/generated_level.tscn")
const PlayerScene = preload("res://src/entities/player.tscn")
const LobbyScene = preload("res://src/ui/lobby_ui.tscn")

var current_scene: Node = null
var is_solo: bool = false

func _ready():
	RunManager.state_changed.connect(_on_state_changed)
	_show_lobby()

func _on_state_changed(new_state: int) -> void:
	_clear_current()

	match new_state:
		RunManager.State.LOBBY:
			_show_lobby()
		RunManager.State.MAP:
			_show_map()
		RunManager.State.LEVEL, RunManager.State.BOSS:
			# BOSS plays as normal level for now — real boss fight added in Plan 4B
			_start_level()
		RunManager.State.REWARD:
			_show_reward()
		RunManager.State.SHOP:
			_show_shop()
		RunManager.State.VICTORY:
			_show_victory()
		RunManager.State.GAME_OVER:
			_show_game_over()

func _clear_current() -> void:
	if current_scene:
		# Use call_deferred to avoid freeing nodes mid-signal-emission
		current_scene.call_deferred("queue_free")
		current_scene = null
	# Release mouse for UI screens
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_lobby() -> void:
	var lobby = LobbyScene.instantiate()
	lobby.game_started.connect(_on_game_started)
	lobby.meta_upgrades_pressed.connect(_on_meta_upgrades)
	lobby.themes_pressed.connect(_on_themes)
	add_child(lobby)
	current_scene = lobby

func _on_game_started(solo: bool) -> void:
	is_solo = solo
	RunManager.start_run()

func _on_meta_upgrades() -> void:
	_clear_current()
	var screen = MetaUpgradesScreen.new()
	screen.back_pressed.connect(_on_meta_upgrades_back)
	add_child(screen)
	current_scene = screen

func _on_meta_upgrades_back() -> void:
	_clear_current()
	_show_lobby()

func _on_themes() -> void:
	_clear_current()
	var screen = preload("res://src/ui/theme_selector.gd").new()
	screen.back_pressed.connect(_on_themes_back)
	add_child(screen)
	current_scene = screen

func _on_themes_back() -> void:
	_clear_current()
	_show_lobby()

func _show_map() -> void:
	var map_screen = MapScreen.new()
	map_screen.node_selected.connect(_on_map_node_selected)
	add_child(map_screen)
	current_scene = map_screen

func _on_map_node_selected(node_index: int) -> void:
	RunManager.select_map_node(node_index)

func _start_level() -> void:
	var level = GeneratedLevel.instantiate()
	add_child(level)
	current_scene = level

	if is_solo:
		_spawn_player(level, 1, true)
	else:
		_spawn_player(level, Net.my_peer_id, true)
		for peer_id in Net.peers:
			_spawn_player(level, peer_id, false)

func _spawn_player(level: Node3D, peer_id: int, is_local: bool) -> void:
	var player = PlayerScene.instantiate()
	player.name = "Player_%d" % peer_id

	var spawn_pos = Vector3(0, 1, 0)
	if level.has_method("get_player_spawn"):
		spawn_pos = level.get_player_spawn()

	player.position = spawn_pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	level.add_child(player)
	player.setup(peer_id, is_local)
	player.apply_upgrades()

func _show_reward() -> void:
	var reward = RewardScreen.new()
	reward.upgrade_picked.connect(_on_upgrade_picked)
	add_child(reward)
	current_scene = reward

func _on_upgrade_picked(upgrade: UpgradeData) -> void:
	RunManager.pick_upgrade(upgrade)

func _show_game_over() -> void:
	var screen = GameOverScreen.new()
	screen.return_pressed.connect(_on_return_to_lobby)
	add_child(screen)
	current_scene = screen

func _on_return_to_lobby() -> void:
	RunManager.return_to_lobby()

func _show_victory() -> void:
	var screen = VictoryScreen.new()
	screen.continue_pressed.connect(_on_continue_run)
	screen.end_run_pressed.connect(_on_end_run)
	add_child(screen)
	current_scene = screen

func _on_continue_run() -> void:
	RunManager.continue_run()

func _on_end_run() -> void:
	RunManager.end_run()

func _show_shop() -> void:
	var shop = ShopScreen.new()
	shop.shop_finished.connect(_on_shop_finished)
	add_child(shop)
	current_scene = shop

func _on_shop_finished() -> void:
	RunManager.finish_shopping()

