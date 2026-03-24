class_name RunManager
extends Node

enum State { LOBBY, MAP, LEVEL, REWARD, SHOP, BOSS, VICTORY, GAME_OVER }

signal state_changed(new_state: int)
signal run_started()
signal run_ended(stats: RunStats)
signal currency_changed(amount: int)
signal level_cleared_signal()

var state: int = State.LOBBY
var current_depth: int = 0
var currency: int = 0
var active_upgrades: Array = []
var stats: RunStats = RunStats.new()
var map: RunMap
var last_selected_node_index: int = 0

func _process(delta: float) -> void:
    if state == State.LEVEL or state == State.BOSS:
        stats.time_elapsed += delta

func start_run() -> void:
    stats.reset()
    current_depth = 0
    currency = 0
    active_upgrades.clear()
    last_selected_node_index = 0
    map = RunMap.generate(Config.boss_depth)
    run_started.emit()
    _change_state(State.MAP)

func select_map_node(node_index: int) -> void:
    last_selected_node_index = node_index
    map.visit_node(current_depth, node_index)
    var node = map.get_node(current_depth, node_index)
    _apply_modifier(node.modifier)
    Config.level_seed = node.level_seed
    if node.modifier == "boss":
        _change_state(State.BOSS)
    else:
        _change_state(State.LEVEL)

func on_level_cleared() -> void:
    stats.levels_cleared += 1
    add_currency(50)
    if not stats.took_damage_this_level:
        add_currency(30)
    stats.took_damage_this_level = false
    current_depth += 1
    level_cleared_signal.emit()
    _change_state(State.REWARD)

func on_player_died() -> void:
    run_ended.emit(stats)
    _change_state(State.GAME_OVER)

func pick_upgrade(upgrade: UpgradeData) -> void:
    active_upgrades.append(upgrade)
    if current_depth >= Config.boss_depth:
        # Boss depth reached — placeholder until Plan 4B adds real boss
        run_ended.emit(stats)
        _change_state(State.GAME_OVER)
    else:
        _change_state(State.MAP)

func add_currency(amount: int) -> void:
    currency += amount
    stats.total_currency_earned += amount
    currency_changed.emit(currency)

func register_kill(max_hp: int) -> void:
    stats.kills += 1
    var reward = maxi(Config.kill_reward_base, max_hp / 10)
    add_currency(reward)

func return_to_lobby() -> void:
    _change_state(State.LOBBY)

func _change_state(new_state: int) -> void:
    state = new_state
    state_changed.emit(new_state)

func _apply_modifier(modifier: String) -> void:
    Config.level_grid_width = 12
    Config.level_grid_height = 12
    Config.monsters_per_room = 1
    Config.light_range_mult = 1.0
    Config.monster_hp_mult = 1.0

    match modifier:
        "dense":
            Config.monsters_per_room = 2
        "large":
            Config.level_grid_width = 16
            Config.level_grid_height = 16
        "dark":
            Config.light_range_mult = 0.5
        "horde":
            Config.monsters_per_room = 3
            Config.monster_hp_mult = 0.5
