extends Control

signal game_started(solo: bool)
signal meta_upgrades_pressed()
signal themes_pressed()

@onready var lobby_input: LineEdit = $VBoxContainer/LobbyInput
@onready var solo_button: Button = $VBoxContainer/SoloButton
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var player_list: ItemList = $VBoxContainer/PlayerList

func _ready():
	var bg = ColorRect.new()
	bg.color = ThemeManager.active_theme.ui_background_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)  # behind everything

	solo_button.pressed.connect(_on_solo)
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	start_button.pressed.connect(_on_start)
	start_button.visible = false
	Net.player_connected.connect(_on_player_connected)
	Net.player_disconnected.connect(_on_player_disconnected)
	Net.connection_established.connect(_on_connected)

	# Meta-progression display
	var vbox = $VBoxContainer
	if MetaSave:
		var meta_label = Label.new()
		meta_label.text = "Meta-Currency: %d | Best Loop: %d" % [MetaSave.meta_currency, MetaSave.best_loop]
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(meta_label)

		var upgrades_btn = Button.new()
		upgrades_btn.text = "Permanent Upgrades"
		upgrades_btn.pressed.connect(_on_meta_upgrades)
		vbox.add_child(upgrades_btn)

	var themes_btn = Button.new()
	themes_btn.text = "Themes"
	themes_btn.pressed.connect(_on_themes)
	vbox.add_child(themes_btn)

func _on_solo():
	game_started.emit(true)

func _on_host():
	var lobby_id = lobby_input.text.strip_edges()
	if lobby_id.is_empty():
		lobby_id = "lobby-%d" % randi()
		lobby_input.text = lobby_id
	status_label.text = "Creating lobby: %s..." % lobby_id
	Net.join_lobby(lobby_id)

func _on_join():
	var lobby_id = lobby_input.text.strip_edges()
	if lobby_id.is_empty():
		status_label.text = "Enter a lobby ID"
		return
	status_label.text = "Joining lobby: %s..." % lobby_id
	Net.join_lobby(lobby_id)

func _on_connected():
	status_label.text = "Connected! Peer ID: %d" % Net.my_peer_id
	player_list.add_item("You (Peer %d)" % Net.my_peer_id)
	host_button.visible = false
	join_button.visible = false
	solo_button.visible = false
	start_button.visible = true

func _on_start():
	_start_game_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func _start_game_rpc():
	game_started.emit(false)

func _on_player_connected(peer_id: int):
	player_list.add_item("Peer %d" % peer_id)
	status_label.text = "%d players connected" % player_list.item_count

func _on_meta_upgrades():
	meta_upgrades_pressed.emit()

func _on_themes():
	themes_pressed.emit()

func _on_player_disconnected(peer_id: int):
	for i in range(player_list.item_count):
		if player_list.get_item_text(i).contains(str(peer_id)):
			player_list.remove_item(i)
			break
