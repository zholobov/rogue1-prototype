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
    # Apply permanent meta-upgrades
    if MetaSave:
        active_upgrades.append_array(MetaSave.get_starting_upgrades())
    map = RunMap.generate(Config.boss_depth)
    run_started.emit()
    _change_state(State.MAP)

func select_map_node(node_index: int) -> void:
    last_selected_node_index = node_index
    map.visit_node(current_depth, node_index)
    var node = map.get_node(current_depth, node_index)
    _apply_modifier(node.modifier)
    if ThemeManager and ThemeManager.active_group:
        var biome = ThemeManager.active_group.get_biome(node.biome_index)
        if biome:
            ThemeManager.set_biome(biome)
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
    if current_depth > Config.boss_depth:
        # Boss beaten — show victory screen
        _change_state(State.VICTORY)
    else:
        _change_state(State.REWARD)

func on_player_died() -> void:
    run_ended.emit(stats)
    if MetaSave:
        MetaSave.on_run_ended(stats)
    _change_state(State.GAME_OVER)

func pick_upgrade(upgrade: UpgradeData) -> void:
    active_upgrades.append(upgrade)
    if current_depth > 0 and current_depth % Config.shop_frequency == 0:
        _change_state(State.SHOP)
    else:
        _change_state(State.MAP)

func add_currency(amount: int) -> void:
    currency += amount
    stats.total_currency_earned += amount
    currency_changed.emit(currency)

func spend_currency(amount: int) -> bool:
    if currency < amount:
        return false
    currency -= amount
    currency_changed.emit(currency)
    return true

func register_kill(max_hp: int) -> void:
    stats.kills += 1
    var reward = maxi(Config.kill_reward_base, max_hp / 10)
    add_currency(reward)

func return_to_lobby() -> void:
    _change_state(State.LOBBY)

func continue_run() -> void:
    stats.loop += 1
    current_depth = 0
    last_selected_node_index = 0
    map = RunMap.generate(Config.boss_depth)
    _change_state(State.MAP)

func end_run() -> void:
    run_ended.emit(stats)
    if MetaSave:
        MetaSave.on_run_ended(stats)
    _change_state(State.GAME_OVER)

func finish_shopping() -> void:
    _change_state(State.MAP)

func _change_state(new_state: int) -> void:
    state = new_state
    state_changed.emit(new_state)

func _apply_modifier(modifier: String) -> void:
    Config.current_modifier = modifier
    Config.level_grid_width = 12
    Config.level_grid_height = 12
    Config.monsters_per_room = 1
    Config.light_range_mult = 1.0
    Config.monster_hp_mult = 1.0
    Config.monster_damage_mult = 1.0
    Config.max_monsters_per_level = 5

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
        "boss":
            Config.level_grid_width = 14
            Config.level_grid_height = 14
            Config.monsters_per_room = 3
            Config.monster_hp_mult = 2.0
            Config.max_monsters_per_level = 0  # No cap for boss

    # Loop scaling: +50% HP, +25% damage per loop
    if stats.loop > 0:
        Config.monster_hp_mult *= (1.0 + 0.5 * stats.loop)
        Config.monster_damage_mult *= (1.0 + 0.25 * stats.loop)
