extends Control

signal game_started()

@onready var lobby_input: LineEdit = $VBoxContainer/LobbyInput
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var player_list: ItemList = $VBoxContainer/PlayerList

func _ready():
    host_button.pressed.connect(_on_host)
    join_button.pressed.connect(_on_join)
    start_button.pressed.connect(_on_start)
    start_button.visible = false
    Net.player_connected.connect(_on_player_connected)
    Net.player_disconnected.connect(_on_player_disconnected)
    Net.connection_established.connect(_on_connected)

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
    start_button.visible = true

func _on_start():
    _start_game_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func _start_game_rpc():
    game_started.emit()

func _on_player_connected(peer_id: int):
    player_list.add_item("Peer %d" % peer_id)
    status_label.text = "%d players connected" % player_list.item_count

func _on_player_disconnected(peer_id: int):
    for i in range(player_list.item_count):
        if player_list.get_item_text(i).contains(str(peer_id)):
            player_list.remove_item(i)
            break
