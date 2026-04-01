extends Control

signal game_started(solo: bool)
signal meta_upgrades_pressed()
signal themes_pressed()
signal playground_pressed()

@onready var lobby_input: LineEdit = $MarginContainer/RootVBox/Columns/RightColumn/JoinRow/LobbyInput
@onready var solo_button: Button = $MarginContainer/RootVBox/Columns/LeftColumn/SoloButton
@onready var host_button: Button = $MarginContainer/RootVBox/Columns/RightColumn/HostButton
@onready var join_button: Button = $MarginContainer/RootVBox/Columns/RightColumn/JoinRow/JoinButton
@onready var start_button: Button = $MarginContainer/RootVBox/Columns/RightColumn/StartButton
@onready var status_label: Label = $MarginContainer/RootVBox/Columns/RightColumn/StatusLabel
@onready var player_list: ItemList = $MarginContainer/RootVBox/Columns/RightColumn/PlayerList
@onready var join_separator: Label = $MarginContainer/RootVBox/Columns/RightColumn/JoinSeparator
@onready var join_row: HBoxContainer = $MarginContainer/RootVBox/Columns/RightColumn/JoinRow

var _lobby_code_row: HBoxContainer
var _lobby_code_label: Label
var _lobby_code: String = ""

func _ready():
    var bg = ColorRect.new()
    bg.color = ThemeManager.active_theme.ui_background_color
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    move_child(bg, 0)

    solo_button.pressed.connect(_on_solo)
    host_button.pressed.connect(_on_host)
    join_button.pressed.connect(_on_join)
    start_button.pressed.connect(_on_start)
    start_button.visible = false
    Net.player_connected.connect(_on_player_connected)
    Net.player_disconnected.connect(_on_player_disconnected)
    Net.connection_established.connect(_on_connected)

    # Style headers
    var active_theme = ThemeManager.active_theme
    for header in [
        $MarginContainer/RootVBox/Title,
        $MarginContainer/RootVBox/Columns/LeftColumn/SoloHeader,
        $MarginContainer/RootVBox/Columns/LeftColumn/FeaturesHeader,
        $MarginContainer/RootVBox/Columns/RightColumn/MultiplayerHeader,
    ]:
        header.add_theme_color_override("font_color", active_theme.ui_accent_color)

    $MarginContainer/RootVBox/Title.add_theme_font_size_override("font_size", 20)
    join_separator.add_theme_font_size_override("font_size", 11)
    join_separator.add_theme_color_override("font_color", Color(active_theme.ui_text_color, 0.5))

    # Build lobby code display (hidden until connected)
    _lobby_code_row = HBoxContainer.new()
    _lobby_code_row.add_theme_constant_override("separation", 8)
    _lobby_code_row.visible = false
    var right_col = $MarginContainer/RootVBox/Columns/RightColumn
    right_col.add_child(_lobby_code_row)
    right_col.move_child(_lobby_code_row, 1)  # After MultiplayerHeader

    _lobby_code_label = Label.new()
    _lobby_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _lobby_code_label.add_theme_font_size_override("font_size", 14)
    _lobby_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _lobby_code_row.add_child(_lobby_code_label)

    var copy_btn = Button.new()
    copy_btn.text = "Copy"
    copy_btn.pressed.connect(_on_copy_lobby_code)
    _lobby_code_row.add_child(copy_btn)

    # Left column: solo features
    var left = $MarginContainer/RootVBox/Columns/LeftColumn
    if MetaSave:
        var meta_label = Label.new()
        meta_label.text = "Meta-Currency: %d | Best Loop: %d" % [MetaSave.meta_currency, MetaSave.best_loop]
        meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        meta_label.add_theme_font_size_override("font_size", 11)
        left.add_child(meta_label)

        var upgrades_btn = Button.new()
        upgrades_btn.text = "Permanent Upgrades"
        upgrades_btn.pressed.connect(_on_meta_upgrades)
        left.add_child(upgrades_btn)

    var theme_row = HBoxContainer.new()
    theme_row.add_theme_constant_override("separation", 8)
    left.add_child(theme_row)
    var theme_label = Label.new()
    theme_label.text = "Theme:"
    theme_label.add_theme_font_size_override("font_size", 12)
    theme_row.add_child(theme_label)
    var theme_option = OptionButton.new()
    theme_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var groups = ThemeManager.available_groups
    var current_idx = 0
    for i in range(groups.size()):
        theme_option.add_item(groups[i].group_name)
        if groups[i] == ThemeManager.active_group:
            current_idx = i
    theme_option.selected = current_idx
    theme_option.item_selected.connect(_on_theme_selected.bind(groups))
    theme_row.add_child(theme_option)

    var playground_btn = Button.new()
    playground_btn.text = "Level Playground"
    playground_btn.pressed.connect(_on_playground)
    left.add_child(playground_btn)

func _on_solo():
    game_started.emit(true)

func _on_host():
    var lobby_id = lobby_input.text.strip_edges()
    if lobby_id.is_empty():
        lobby_id = "lobby-%d" % randi()
        lobby_input.text = lobby_id
    _lobby_code = lobby_id
    status_label.text = "Creating lobby: %s..." % lobby_id
    Net.join_lobby(lobby_id)

func _on_join():
    var lobby_id = lobby_input.text.strip_edges()
    if lobby_id.is_empty():
        status_label.text = "Enter a lobby ID"
        return
    _lobby_code = lobby_id
    status_label.text = "Joining lobby: %s..." % lobby_id
    Net.join_lobby(lobby_id)

func _on_connected():
    _lobby_code_label.text = _lobby_code
    _lobby_code_row.visible = true
    status_label.text = "Share this code with your friend"
    player_list.visible = true
    player_list.add_item("You (Peer %d)" % Net.my_peer_id)
    host_button.visible = false
    join_separator.visible = false
    join_row.visible = false
    solo_button.visible = false
    start_button.visible = true

func _on_start():
    _start_game_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func _start_game_rpc():
    game_started.emit(false)

func _on_copy_lobby_code():
    DisplayServer.clipboard_set(_lobby_code)
    status_label.text = "Copied to clipboard!"

func _on_player_connected(peer_id: int):
    player_list.add_item("Peer %d" % peer_id)
    status_label.text = "%d players connected" % player_list.item_count

func _on_meta_upgrades():
    meta_upgrades_pressed.emit()

func _on_themes():
    themes_pressed.emit()

func _on_theme_selected(index: int, groups: Array):
    if index >= 0 and index < groups.size():
        ThemeManager.set_theme(groups[index].group_name)

func _on_playground():
    playground_pressed.emit()

func _on_player_disconnected(peer_id: int):
    for i in range(player_list.item_count):
        if player_list.get_item_text(i).contains(str(peer_id)):
            player_list.remove_item(i)
            break
