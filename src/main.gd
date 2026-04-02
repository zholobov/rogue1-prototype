extends Node

const GeneratedLevel = preload("res://src/levels/generated_level.tscn")
const LobbyScene = preload("res://src/ui/lobby_ui.tscn")

var current_scene: Node = null
var is_solo: bool = false
var _peers_finished: Dictionary = {}  # peer_id -> bool, for reward/shop wait-for-all

func _ready():
    RunManager.state_changed.connect(_on_state_changed)
    multiplayer.server_disconnected.connect(_on_host_disconnected)
    _show_lobby()

func _on_host_disconnected() -> void:
    _clear_current()
    Net.disconnect_all()
    is_solo = false
    RunManager.return_to_lobby()
    GameLog.info("[Main] Host disconnected — returning to lobby")

func _on_state_changed(new_state: int) -> void:
    if Net.is_active and Net.is_host:
        # Send level config BEFORE state change so client has correct seed
        if new_state == RunManager.State.LEVEL or new_state == RunManager.State.BOSS:
            # Pre-generate grid so it's available for the RPC
            var gen = LevelGenerator.new()
            var seed_val = Config.level_seed if Config.level_seed != 0 else randi()
            Config.level_seed = seed_val
            gen.tile_rules.setup_profile(Config.current_modifier)
            Config.synced_grid = gen.generate_grid(gen.tile_rules, Config.level_grid_width, Config.level_grid_height, seed_val, Config.current_modifier)
            # Flatten the 2D grid for RPC
            var flat_grid: PackedStringArray = PackedStringArray()
            for row in Config.synced_grid:
                for cell in row:
                    flat_grid.append(cell)
            _sync_level_config.rpc(
                Config.level_seed,
                Config.level_grid_width,
                Config.level_grid_height,
                Config.monster_hp_mult,
                Config.monster_damage_mult,
                Config.monsters_per_room,
                Config.max_monsters_per_level,
                Config.light_range_mult,
                Config.current_modifier,
                flat_grid
            )
        GameLog.info("[Main] Broadcasting state %d to clients via RPC" % new_state)
        _sync_state_change.rpc(new_state)
    else:
        GameLog.info("[Main] Applying state %d locally" % new_state)
        _apply_state_change(new_state)

@rpc("authority", "call_local", "reliable")
func _sync_state_change(new_state: int) -> void:
    _apply_state_change(new_state)

func _apply_state_change(new_state: int) -> void:
    _clear_current()

    match new_state:
        RunManager.State.LOBBY:
            _show_lobby()
        RunManager.State.MAP:
            _show_map()
        RunManager.State.LEVEL, RunManager.State.BOSS:
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
    lobby.playground_pressed.connect(_on_playground)
    add_child(lobby)
    current_scene = lobby

func _on_game_started(solo: bool) -> void:
    GameLog.info("[Main] _on_game_started(solo=%s)" % str(solo))
    is_solo = solo
    if solo and Net.is_active:
        Net.disconnect_all()
        multiplayer.multiplayer_peer = null
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

func _on_playground() -> void:
    _clear_current()
    var screen = preload("res://src/ui/level_playground.gd").new()
    screen.back_pressed.connect(_on_playground_back)
    add_child(screen)
    current_scene = screen

func _on_playground_back() -> void:
    _clear_current()
    _show_lobby()

func _show_map() -> void:
    var map_screen = MapScreen.new()
    map_screen.node_selected.connect(_on_map_node_selected)
    add_child(map_screen)
    current_scene = map_screen

func _on_map_node_selected(node_index: int) -> void:
    if Net.is_active and not Net.is_host:
        return
    RunManager.select_map_node(node_index)

@rpc("authority", "reliable")
func _sync_level_config(seed_val: int, width: int, height: int, hp_mult: float, dmg_mult: float, mpr: int, max_m: int, light: float, modifier: StringName, flat_grid: PackedStringArray) -> void:
    Config.level_seed = seed_val
    Config.level_grid_width = width
    Config.level_grid_height = height
    Config.monster_hp_mult = hp_mult
    Config.monster_damage_mult = dmg_mult
    Config.monsters_per_room = mpr
    Config.max_monsters_per_level = max_m
    Config.light_range_mult = light
    Config.current_modifier = modifier
    # Reconstruct 2D grid from flat array
    Config.synced_grid = []
    var idx := 0
    for y in range(height):
        var row: Array = []
        for x in range(width):
            row.append(flat_grid[idx])
            idx += 1
        Config.synced_grid.append(row)

func _start_level() -> void:
    var level = GeneratedLevel.instantiate()
    add_child(level)
    current_scene = level

    if is_solo:
        level.spawn_player(1, true)
    elif Net.is_host:
        # Host spawns all players — MultiplayerSpawner replicates to clients
        level.spawn_player(Net.my_peer_id, true)
        for peer_id in Net.peers:
            level.spawn_player(peer_id, false)
    # Clients: players arrive via MultiplayerSpawner, auto-setup in _ready()

func _show_reward() -> void:
    _reset_peers_finished()
    var reward = RewardScreen.new()
    reward.upgrade_picked.connect(_on_upgrade_picked)
    add_child(reward)
    current_scene = reward

func _on_upgrade_picked(upgrade: UpgradeData) -> void:
    if is_solo:
        RunManager.pick_upgrade(upgrade)
        return
    # In multiplayer, each player picks locally, then notifies host
    RunManager.active_upgrades.append(upgrade)
    if Net.is_active:
        _notify_reward_done.rpc_id(1, Net.my_peer_id)

@rpc("any_peer", "reliable")
func _notify_reward_done(peer_id: int) -> void:
    if not Net.is_host:
        return
    _peers_finished[peer_id] = true
    _check_all_finished(RunManager.State.REWARD)

func _reset_peers_finished() -> void:
    _peers_finished.clear()
    if Net.is_active and Net.is_host:
        _peers_finished[Net.my_peer_id] = false
        for pid in Net.peers:
            _peers_finished[pid] = false

func _check_all_finished(from_state: int) -> void:
    for pid in _peers_finished:
        if not _peers_finished[pid]:
            return
    # All players done — advance state (skip pick_upgrade to avoid appending null)
    if from_state == RunManager.State.REWARD:
        if RunManager.current_depth > 0 and RunManager.current_depth % Config.shop_frequency == 0:
            RunManager._change_state(RunManager.State.SHOP)
        else:
            RunManager._change_state(RunManager.State.MAP)
    elif from_state == RunManager.State.SHOP:
        RunManager.finish_shopping()

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
    _reset_peers_finished()
    var shop = ShopScreen.new()
    shop.shop_finished.connect(_on_shop_finished)
    add_child(shop)
    current_scene = shop

func _on_shop_finished() -> void:
    if is_solo:
        RunManager.finish_shopping()
        return
    if Net.is_active:
        _notify_shop_done.rpc_id(1, Net.my_peer_id)

@rpc("any_peer", "reliable")
func _notify_shop_done(peer_id: int) -> void:
    if not Net.is_host:
        return
    _peers_finished[peer_id] = true
    _check_all_finished(RunManager.State.SHOP)

