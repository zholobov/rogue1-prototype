# Game Loop Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a playable roguelite game loop: lobby → branching map → level → reward → repeat until boss depth, then game over.

**Architecture:** New RunManager autoload owns run state and drives transitions via signals. Main.gd listens to state_changed to swap scenes/UI. RunMap generates a branching map upfront. UpgradeData defines stat/weapon/defensive upgrades. C_PlayerStats holds computed modifiers read by existing systems. Boss fight, shop, special abilities, and meta-progression are deferred to Plans 4B/4C.

**Tech Stack:** Godot 4.6, GL Compatibility, GDScript, GECS ECS

**Spec:** `docs/superpowers/specs/2026-03-24-game-loop-progression-design.md`

**Scope:** Plan 4A of 3. Covers spec sections 1 (RunManager — partial), 2 (Map), 3 (Upgrades — stat/weapon/defensive only), 4 (Reward), 6 (Currency — partial), 7 (Level completion), 8 (Game Over only), 10 (C_PlayerStats only), 11 (S_HpRegen only), 12 (modified files). Defers: shop, boss, victory, special abilities (dash/AoE/lifesteal), meta-progression.

**Indentation rules:**
- TABS: `main.gd`, `game_config.gd`, `s_player_input.gd`, `lobby_ui.gd`, `level_builder.gd`, `hud.gd`
- 4-SPACES: everything else (including all new files)

---

## File Structure

**Create:**
- `src/run/run_stats.gd` — Run statistics tracker
- `src/run/upgrade_data.gd` — Upgrade data class + static pool + roll helper
- `src/run/run_map.gd` — MapNode + RunMap + generation
- `src/run/run_manager.gd` — RunManager autoload (state machine, signals, run state)
- `src/components/c_player_stats.gd` — Player stat modifier component
- `src/systems/s_hp_regen.gd` — HP regeneration system
- `src/ui/map_screen.gd` — Branching map UI
- `src/ui/reward_screen.gd` — Upgrade reward pick UI
- `src/ui/game_over_screen.gd` — Death stats UI

**Modify:**
- `src/config/game_config.gd` — Add boss_depth, shop_frequency, kill_reward_base, light_range_mult, monster_hp_mult
- `src/levels/generated_level.gd` — Track monsters_remaining, emit level_cleared, horde HP scaling
- `src/systems/s_death.gd` — Dynamic kill reward text
- `src/systems/s_damage.gd` — Read C_PlayerStats damage_reduction, condition_duration_mult, track damage stats
- `src/systems/s_player_input.gd` — Read C_PlayerStats.speed_mult
- `src/entities/player.gd` — Add C_PlayerStats, apply upgrades at level start, weapon bonuses in _equip_weapon
- `src/main.gd` — RunManager-driven scene flow
- `project.godot` — Register RunManager autoload

---

### Task 1: Data Resources (RunStats + UpgradeData)

**Files:**
- Create: `src/run/run_stats.gd`
- Create: `src/run/upgrade_data.gd`

- [ ] **Step 0: Create src/run directory**

```bash
mkdir -p src/run
```

- [ ] **Step 1: Create RunStats**

```gdscript
class_name RunStats
extends RefCounted

var kills: int = 0
var damage_dealt: int = 0
var time_elapsed: float = 0.0
var levels_cleared: int = 0
var loop: int = 0
var took_damage_this_level: bool = false
var total_currency_earned: int = 0

func reset() -> void:
    kills = 0
    damage_dealt = 0
    time_elapsed = 0.0
    levels_cleared = 0
    loop = 0
    took_damage_this_level = false
    total_currency_earned = 0
```

- [ ] **Step 2: Create UpgradeData with pool and roll helper**

```gdscript
class_name UpgradeData
extends RefCounted

var upgrade_name: String
var description: String
var category: String    # "stat", "weapon", "defensive"
var rarity: String      # "common", "rare", "epic"
var property: String    # C_PlayerStats field to modify
var value: float
var cost: int           # shop price (0 = reward-only)

static var _pool: Array = []

static func get_pool() -> Array:
    if _pool.is_empty():
        _pool = [
            # Stat boosts (common)
            _make("Max HP +20", "+20 max health", "stat", "common", "max_health_bonus", 20.0, 30),
            _make("Speed +15%", "+15% movement speed", "stat", "common", "speed_mult", 0.15, 30),
            _make("Damage +10%", "+10% damage", "stat", "common", "damage_mult", 0.10, 30),
            # Weapon (common)
            _make("Fire Rate +20%", "+20% fire rate", "weapon", "common", "fire_rate_bonus", 0.20, 30),
            _make("Proj Speed +25%", "+25% projectile speed", "weapon", "common", "proj_speed_bonus", 0.25, 30),
            # Defensive (rare)
            _make("HP Regen +2/s", "+2 HP per second", "defensive", "rare", "hp_regen", 2.0, 60),
            _make("Armor 15%", "-15% damage taken", "defensive", "rare", "damage_reduction", 0.15, 60),
            _make("Resist 30%", "-30% condition duration", "defensive", "rare", "condition_duration_reduction", 0.30, 60),
        ]
    return _pool

static func _make(n: String, d: String, cat: String, r: String, prop: String, val: float, c: int) -> UpgradeData:
    var u = UpgradeData.new()
    u.upgrade_name = n
    u.description = d
    u.category = cat
    u.rarity = r
    u.property = prop
    u.value = val
    u.cost = c
    return u

static func roll_random(count: int, loop: int) -> Array:
    var pool = get_pool()
    var weighted: Array = []

    # Rarity weights by loop
    var weights: Dictionary
    if loop >= 1:
        weights = {"common": 0.50, "rare": 0.35, "epic": 0.15}
    else:
        weights = {"common": 0.70, "rare": 0.25, "epic": 0.05}

    # Build weighted list: include each upgrade proportional to its rarity weight
    for upgrade in pool:
        var w = weights.get(upgrade.rarity, 0.0)
        if randf() < w * 3.0:  # Scale up so most upgrades pass the filter
            weighted.append(upgrade)

    weighted.shuffle()

    # Take first `count` unique entries
    var result: Array = []
    for upgrade in weighted:
        if result.size() >= count:
            break
        if upgrade not in result:
            result.append(upgrade)

    # Fallback: if not enough, fill from full pool
    if result.size() < count:
        var shuffled = pool.duplicate()
        shuffled.shuffle()
        for upgrade in shuffled:
            if result.size() >= count:
                break
            if upgrade not in result:
                result.append(upgrade)

    return result
```

- [ ] **Step 3: Verify files load**

Run: Open Godot editor. Check Output for parse errors on `run_stats.gd` and `upgrade_data.gd`.

- [ ] **Step 4: Commit**

```bash
git add src/run/run_stats.gd src/run/upgrade_data.gd
git commit -m "feat: add RunStats and UpgradeData resources with upgrade pool"
```

---

### Task 2: C_PlayerStats Component

**Files:**
- Create: `src/components/c_player_stats.gd`

- [ ] **Step 1: Create C_PlayerStats**

```gdscript
class_name C_PlayerStats
extends Component

# Stat modifiers — recalculated from RunManager.active_upgrades at level start
var max_health_bonus: int = 0
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var damage_reduction: float = 0.0
var hp_regen: float = 0.0
var condition_duration_mult: float = 1.0
var fire_rate_bonus: float = 0.0
var proj_speed_bonus: float = 0.0

func recalculate(upgrades: Array) -> void:
    # Reset to base
    max_health_bonus = 0
    damage_mult = 1.0
    speed_mult = 1.0
    damage_reduction = 0.0
    hp_regen = 0.0
    condition_duration_mult = 1.0
    fire_rate_bonus = 0.0
    proj_speed_bonus = 0.0

    # Stack additively from all upgrades
    for upgrade in upgrades:
        match upgrade.property:
            "max_health_bonus":
                max_health_bonus += int(upgrade.value)
            "damage_mult":
                damage_mult += upgrade.value
            "speed_mult":
                speed_mult += upgrade.value
            "damage_reduction":
                damage_reduction += upgrade.value
            "hp_regen":
                hp_regen += upgrade.value
            "condition_duration_reduction":
                condition_duration_mult -= upgrade.value
            "fire_rate_bonus":
                fire_rate_bonus += upgrade.value
            "proj_speed_bonus":
                proj_speed_bonus += upgrade.value

    # Clamp
    condition_duration_mult = maxf(condition_duration_mult, 0.1)
    damage_reduction = minf(damage_reduction, 0.9)
```

- [ ] **Step 2: Commit**

```bash
git add src/components/c_player_stats.gd
git commit -m "feat: add C_PlayerStats modifier component"
```

---

### Task 3: Config Additions

**Files:**
- Modify: `src/config/game_config.gd` (uses TABS)

- [ ] **Step 1: Add run-loop config values**

At the end of `game_config.gd`, before the `# Debug` section, add (NOTE: use TABS for indentation — this file uses TABS):

```gdscript
# Run loop
@export var boss_depth: int = 4
@export var shop_frequency: int = 2
@export var kill_reward_base: int = 10
@export var meta_currency_rate: float = 0.1

# Modifier support (set by RunManager before level load)
var light_range_mult: float = 1.0
var monster_hp_mult: float = 1.0
```

- [ ] **Step 2: Commit**

```bash
git add src/config/game_config.gd
git commit -m "feat: add run-loop config values"
```

---

### Task 4: RunMap Data + Generation

**Files:**
- Create: `src/run/run_map.gd`

- [ ] **Step 1: Create RunMap with MapNode and generation**

```gdscript
class_name RunMap
extends RefCounted

var layers: Array = []  # Array of Array[MapNode]

static func generate(boss_depth: int) -> RunMap:
    var map = RunMap.new()

    # Generate layers 0 to boss_depth - 1 (normal levels)
    for depth in range(boss_depth):
        var layer: Array = []
        var node_count = randi_range(2, 3)
        for i in range(node_count):
            var node = MapNode.new()
            node.level_seed = randi()
            node.modifier = _random_modifier()
            layer.append(node)
        map.layers.append(layer)

    # Boss layer (single node)
    var boss_node = MapNode.new()
    boss_node.level_seed = randi()
    boss_node.modifier = "boss"
    map.layers.append([boss_node])

    # Generate connections: each node connects to 1-2 nodes in next layer
    for depth in range(map.layers.size() - 1):
        var current_layer = map.layers[depth]
        var next_layer = map.layers[depth + 1]

        for node in current_layer:
            var conn_count = randi_range(1, mini(2, next_layer.size()))
            var indices: Array = []
            for idx in range(next_layer.size()):
                indices.append(idx)
            indices.shuffle()
            node.connections = indices.slice(0, conn_count)

        # Ensure every node in next layer is reachable
        for next_idx in range(next_layer.size()):
            var reachable = false
            for node in current_layer:
                if next_idx in node.connections:
                    reachable = true
                    break
            if not reachable:
                # Connect a random current node to this unreachable next node
                current_layer[randi() % current_layer.size()].connections.append(next_idx)

    return map

static func _random_modifier() -> String:
    var roll = randf()
    if roll < 0.50:
        return "normal"
    elif roll < 0.70:
        return "dense"
    elif roll < 0.85:
        return "large"
    elif roll < 0.95:
        return "dark"
    else:
        return "horde"

func get_node(depth: int, index: int) -> MapNode:
    return layers[depth][index]

func visit_node(depth: int, index: int) -> void:
    layers[depth][index].visited = true

func get_reachable_indices(depth: int, prev_index: int) -> Array:
    if depth == 0:
        # All nodes in first layer are reachable
        var indices: Array = []
        for i in range(layers[0].size()):
            indices.append(i)
        return indices
    return layers[depth - 1][prev_index].connections
```

MapNode class (same file, above RunMap):

```gdscript
class_name MapNode
extends RefCounted

var level_seed: int = 0
var modifier: String = "normal"
var connections: Array = []  # indices into next layer
var visited: bool = false
```

**IMPORTANT:** GDScript only allows one `class_name` per file. Put MapNode as an inner class or use a separate file. Simplest: make MapNode an inner class of RunMap.

The full file should be:

```gdscript
class_name RunMap
extends RefCounted

var layers: Array = []  # Array of Array[MapNode]

class MapNode:
    var level_seed: int = 0
    var modifier: String = "normal"
    var connections: Array = []
    var visited: bool = false

static func generate(boss_depth: int) -> RunMap:
    var map = RunMap.new()

    for depth in range(boss_depth):
        var layer: Array = []
        var node_count = randi_range(2, 3)
        for i in range(node_count):
            var node = MapNode.new()
            node.level_seed = randi()
            node.modifier = _random_modifier()
            layer.append(node)
        map.layers.append(layer)

    # Boss layer
    var boss_node = MapNode.new()
    boss_node.level_seed = randi()
    boss_node.modifier = "boss"
    map.layers.append([boss_node])

    # Connect layers
    for depth in range(map.layers.size() - 1):
        var current_layer = map.layers[depth]
        var next_layer = map.layers[depth + 1]

        for node in current_layer:
            var conn_count = randi_range(1, mini(2, next_layer.size()))
            var indices: Array = []
            for idx in range(next_layer.size()):
                indices.append(idx)
            indices.shuffle()
            node.connections = indices.slice(0, conn_count)

        # Ensure all next-layer nodes reachable
        for next_idx in range(next_layer.size()):
            var reachable = false
            for node in current_layer:
                if next_idx in node.connections:
                    reachable = true
                    break
            if not reachable:
                current_layer[randi() % current_layer.size()].connections.append(next_idx)

    return map

static func _random_modifier() -> String:
    var roll = randf()
    if roll < 0.50:
        return "normal"
    elif roll < 0.70:
        return "dense"
    elif roll < 0.85:
        return "large"
    elif roll < 0.95:
        return "dark"
    else:
        return "horde"

func get_node(depth: int, index: int) -> MapNode:
    return layers[depth][index]

func visit_node(depth: int, index: int) -> void:
    layers[depth][index].visited = true

func get_reachable_indices(depth: int, prev_index: int) -> Array:
    if depth == 0:
        var indices: Array = []
        for i in range(layers[0].size()):
            indices.append(i)
        return indices
    return layers[depth - 1][prev_index].connections
```

- [ ] **Step 2: Commit**

```bash
git add src/run/run_map.gd
git commit -m "feat: add RunMap with branching map generation"
```

---

### Task 5: RunManager Autoload

**Files:**
- Create: `src/run/run_manager.gd`

- [ ] **Step 1: Create RunManager state machine**

```gdscript
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
```

- [ ] **Step 2: Commit**

```bash
git add src/run/run_manager.gd
git commit -m "feat: add RunManager state machine autoload"
```

---

### Task 6: Level Completion + Currency Integration

**Files:**
- Modify: `src/levels/generated_level.gd` (4-spaces)
- Modify: `src/systems/s_death.gd` (4-spaces)

- [ ] **Step 1: Add monster tracking and level_cleared to GeneratedLevel**

In `generated_level.gd`, add a member variable after `var level_data`:

```gdscript
var monsters_remaining: int = 0
var death_system: S_Death
```

In `_ready()`, after the line `ECS.world.add_system(S_Death.new())` (line 43), replace that line with:

```gdscript
    death_system = S_Death.new()
    death_system.actor_died.connect(_on_actor_died)
    ECS.world.add_system(death_system)
```

Replace `_spawn_monsters()` entirely with:

```gdscript
func _spawn_monsters() -> void:
    monsters_remaining = 0
    var spawn_points = get_spawn_points()
    for i in range(1, spawn_points.size()):
        for _m in range(Config.monsters_per_room):
            var monster = MonsterScene.instantiate()
            var offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
            monster.position = spawn_points[i] + offset
            add_child(monster)
            # Apply horde modifier HP scaling (monster.ecs_entity is set in MonsterEntity._ready)
            if Config.monster_hp_mult != 1.0 and monster.ecs_entity:
                var health := monster.ecs_entity.get_component(C_Health) as C_Health
                if health:
                    health.max_health = int(health.max_health * Config.monster_hp_mult)
                    health.current_health = health.max_health
            monsters_remaining += 1
```

Add a new method at the end of the file:

```gdscript
func _on_actor_died(entity: Entity) -> void:
    var tag := entity.get_component(C_ActorTag) as C_ActorTag
    if not tag:
        return

    if tag.actor_type == C_ActorTag.ActorType.MONSTER:
        # Notify RunManager for currency
        var health := entity.get_component(C_Health) as C_Health
        if health and RunManager:
            RunManager.register_kill(health.max_health)

        monsters_remaining -= 1
        if monsters_remaining <= 0:
            print("[GeneratedLevel] All monsters defeated!")
            if RunManager:
                RunManager.on_level_cleared()

    elif tag.actor_type == C_ActorTag.ActorType.PLAYER:
        if not Config.god_mode and RunManager:
            RunManager.on_player_died()
```

- [ ] **Step 2: Update S_Death floating text to use dynamic currency amount**

In `s_death.gd`, replace the floating text section:

```gdscript
            # Floating kill text for monsters
            if parent is MonsterEntity and is_instance_valid(parent):
                var ft = FloatingText.new()
                parent.get_tree().current_scene.add_child(ft)
                var reward = maxi(Config.kill_reward_base, health.max_health / 10)
                ft.show_text(parent.global_position, "+%d" % reward)
```

- [ ] **Step 3: Commit**

```bash
git add src/levels/generated_level.gd src/systems/s_death.gd
git commit -m "feat: level completion tracking and dynamic kill currency"
```

---

### Task 7: Player Stats Integration

**Files:**
- Modify: `src/systems/s_damage.gd` (4-spaces)
- Modify: `src/systems/s_player_input.gd` (TABS)
- Modify: `src/entities/player.gd` (4-spaces)

- [ ] **Step 1: S_Damage — read C_PlayerStats for damage_reduction and track damage stats**

In `s_damage.gd`, replace the `apply_damage` static function body. Change `health.current_health -= damage` and the surrounding code to apply damage reduction and track stats:

Replace lines 27-29 (`# Apply raw damage` through `health.current_health = maxi(...)`) with:

```gdscript
    # Apply damage_mult for outgoing damage (attacker stats passed via damage param already scaled)
    # Apply damage reduction from C_PlayerStats on target
    var actual_damage = damage
    var player_stats := target_entity.get_component(C_PlayerStats) as C_PlayerStats
    if player_stats:
        actual_damage = int(float(damage) * (1.0 - player_stats.damage_reduction))
    actual_damage = maxi(actual_damage, 1)
    health.current_health -= actual_damage
    health.current_health = maxi(health.current_health, 0)

    # Track outgoing damage (only count damage TO monsters, not FROM them)
    var dmg_target_tag := target_entity.get_component(C_ActorTag) as C_ActorTag
    if dmg_target_tag and dmg_target_tag.actor_type == C_ActorTag.ActorType.MONSTER and RunManager:
        RunManager.stats.damage_dealt += actual_damage
    # Track player damage taken for no-damage bonus
    if not Config.god_mode:
        var dmg_tag := target_entity.get_component(C_ActorTag) as C_ActorTag
        if dmg_tag and dmg_tag.actor_type == C_ActorTag.ActorType.PLAYER and RunManager:
            RunManager.stats.took_damage_this_level = true
```

- [ ] **Step 2: S_PlayerInput — read C_PlayerStats.speed_mult**

In `s_player_input.gd` (uses TABS), replace line 28:

```gdscript
		vel.speed = Config.player_speed if vel.direction != Vector3.ZERO else 0.0
```

with:

```gdscript
		var base_speed = Config.player_speed
		var ps := entity.get_component(C_PlayerStats) as C_PlayerStats
		if ps:
			base_speed *= ps.speed_mult
		vel.speed = base_speed if vel.direction != Vector3.ZERO else 0.0
```

- [ ] **Step 3: Player.gd — add C_PlayerStats and apply upgrades (including weapon bonuses)**

In `player.gd` (4-spaces), after the line `ecs_entity.add_component(C_ActorTag.new())` (line 25), add:

```gdscript
    ecs_entity.add_component(C_PlayerStats.new())
```

Add a new method at the end of the file:

```gdscript
func apply_upgrades() -> void:
    var ps := get_component(C_PlayerStats) as C_PlayerStats
    if not ps:
        return
    ps.recalculate(RunManager.active_upgrades if RunManager else [])

    # Apply max health bonus
    var health := get_component(C_Health) as C_Health
    if health:
        health.max_health = Config.player_max_health + ps.max_health_bonus
        health.current_health = health.max_health

    # Re-equip current weapon to apply fire_rate/proj_speed/damage bonuses
    _equip_weapon(_current_weapon_index)
```

Also add a `_current_weapon_index` tracker. After `var ecs_entity: Entity`, add:

```gdscript
var _current_weapon_index: int = 0
```

And modify `_equip_weapon()` to track the index and apply C_PlayerStats bonuses:

```gdscript
func _equip_weapon(index: int) -> void:
    if index >= Config.weapon_presets.size():
        return
    _current_weapon_index = index
    var preset = Config.weapon_presets[index]
    var weapon := get_component(C_Weapon) as C_Weapon
    var ps := get_component(C_PlayerStats) as C_PlayerStats
    weapon.damage = int(preset.damage * (ps.damage_mult if ps else 1.0))
    weapon.fire_rate = preset.fire_rate * (1.0 / (1.0 + (ps.fire_rate_bonus if ps else 0.0)))
    weapon.projectile_speed = preset.speed * (1.0 + (ps.proj_speed_bonus if ps else 0.0))
    weapon.element = preset.element
    weapon.cooldown_remaining = 0.0
```

- [ ] **Step 4: S_Conditions — read condition_duration_mult**

In `src/components/c_conditions.gd` (4-spaces), modify the `add_condition()` method to accept an optional `duration_mult` parameter. Find the line where duration is assigned and multiply it:

In the entity that holds C_Conditions, the duration mult comes from C_PlayerStats. The simplest approach: modify `S_Conditions` to apply the mult when adding conditions. In `src/systems/s_conditions.gd`, in the section that adds conditions (if any tick-based addition exists), OR modify `S_Damage._apply_element_to_conditions()` to read the mult.

In `s_damage.gd`, at the top of `_apply_element_to_conditions`, add a `duration_mult` parameter. Update the static method signature and call sites:

Replace the signature:
```gdscript
static func _apply_element_to_conditions(conditions: C_Conditions, element: String, elem_data: Dictionary) -> void:
```
with:
```gdscript
static func _apply_element_to_conditions(conditions: C_Conditions, element: String, elem_data: Dictionary, duration_mult: float = 1.0) -> void:
```

In the method body, multiply durations by `duration_mult`:
- Line with `interaction.duration` → `interaction.duration * duration_mult`
- Line with `elem_data.condition_duration` → `elem_data.condition_duration * duration_mult`

And in `apply_damage()`, when calling `_apply_element_to_conditions`, pass the mult:
```gdscript
                var cond_mult = 1.0
                var target_ps := target_entity.get_component(C_PlayerStats) as C_PlayerStats
                if target_ps:
                    cond_mult = target_ps.condition_duration_mult
                _apply_element_to_conditions(conditions, element, elem, cond_mult)
```

- [ ] **Step 5: Commit**

```bash
git add src/systems/s_damage.gd src/systems/s_player_input.gd src/entities/player.gd
git commit -m "feat: C_PlayerStats integration — damage, speed, health modifiers"
```

---

### Task 8: S_HpRegen System

**Files:**
- Create: `src/systems/s_hp_regen.gd`
- Modify: `src/levels/generated_level.gd` (4-spaces)

- [ ] **Step 1: Create S_HpRegen**

```gdscript
class_name S_HpRegen
extends System

# Float accumulator to avoid integer truncation (2.0/s at 60fps = 0.033 per frame → rounds to 0)
var _regen_accum: Dictionary = {}  # entity instance_id -> float

func query() -> QueryBuilder:
    return q.with_all([C_Health, C_PlayerStats])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var ps := entity.get_component(C_PlayerStats) as C_PlayerStats
        if ps.hp_regen <= 0.0:
            continue
        var health := entity.get_component(C_Health) as C_Health
        if health.current_health >= health.max_health or health.current_health <= 0:
            continue
        var eid = entity.get_instance_id()
        var accum = _regen_accum.get(eid, 0.0) + ps.hp_regen * delta
        if accum >= 1.0:
            var heal = int(accum)
            health.current_health = mini(health.current_health + heal, health.max_health)
            accum -= heal
        _regen_accum[eid] = accum
```

- [ ] **Step 2: Register S_HpRegen in GeneratedLevel**

In `generated_level.gd`, after the `ECS.world.add_system(death_system)` block (from Task 6), add:

```gdscript
    ECS.world.add_system(S_HpRegen.new())
```

- [ ] **Step 3: Commit**

```bash
git add src/systems/s_hp_regen.gd src/levels/generated_level.gd
git commit -m "feat: add S_HpRegen system for HP regeneration upgrade"
```

---

### Task 9: Map Screen UI

**Files:**
- Create: `src/ui/map_screen.gd`

- [ ] **Step 1: Create MapScreen**

The map screen shows nodes as buttons in columns (one per depth). Uses code-only UI (no .tscn needed — instantiated by main.gd).

```gdscript
class_name MapScreen
extends Control

signal node_selected(node_index: int)

var _current_depth: int = 0

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    # Full-screen dark background
    var bg = ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.1)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var map = RunManager.map
    if not map:
        return
    _current_depth = RunManager.current_depth

    # Title
    var title = Label.new()
    title.text = "Choose Your Path — Depth %d" % _current_depth
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 20)
    title.size = Vector2(get_viewport_rect().size.x, 40)
    add_child(title)

    # Currency display
    var currency_label = Label.new()
    currency_label.text = "Currency: %d" % RunManager.currency
    currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    currency_label.position = Vector2(0, 20)
    currency_label.size = Vector2(get_viewport_rect().size.x - 20, 40)
    add_child(currency_label)

    # HBox for columns
    var hbox = HBoxContainer.new()
    hbox.set_anchors_preset(PRESET_FULL_RECT)
    hbox.set("theme_override_constants/separation", 20)
    hbox.position = Vector2(40, 80)
    hbox.size = Vector2(get_viewport_rect().size.x - 80, get_viewport_rect().size.y - 120)
    add_child(hbox)

    # Draw columns for each depth layer
    for depth in range(map.layers.size()):
        var vbox = VBoxContainer.new()
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.set("theme_override_constants/separation", 10)
        hbox.add_child(vbox)

        # Depth label
        var depth_label = Label.new()
        if depth == map.layers.size() - 1:
            depth_label.text = "BOSS"
        else:
            depth_label.text = "Depth %d" % depth
        depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(depth_label)

        var layer = map.layers[depth]
        for node_idx in range(layer.size()):
            var node = layer[node_idx]
            var btn = Button.new()
            btn.text = node.modifier.to_upper()
            btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

            if node.visited:
                btn.modulate = Color(0.5, 0.5, 0.5)
                btn.disabled = true
            elif depth == _current_depth:
                # Check if reachable
                var reachable = map.get_reachable_indices(depth, RunManager.last_selected_node_index)
                if node_idx in reachable:
                    btn.pressed.connect(_on_node_pressed.bind(node_idx))
                else:
                    btn.disabled = true
                    btn.modulate = Color(0.3, 0.3, 0.3)
            else:
                btn.disabled = true
                btn.modulate = Color(0.4, 0.4, 0.4)

            vbox.add_child(btn)

func _on_node_pressed(node_index: int) -> void:
    node_selected.emit(node_index)
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/map_screen.gd
git commit -m "feat: add MapScreen UI for branching map navigation"
```

---

### Task 10: Reward Screen UI

**Files:**
- Create: `src/ui/reward_screen.gd`

- [ ] **Step 1: Create RewardScreen**

```gdscript
class_name RewardScreen
extends Control

signal upgrade_picked(upgrade: UpgradeData)

var _upgrades: Array = []

func _ready() -> void:
    _upgrades = UpgradeData.roll_random(3, RunManager.stats.loop if RunManager else 0)
    _build_ui()

func _build_ui() -> void:
    var bg = ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.1)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var title = Label.new()
    title.text = "Level Complete! Pick an Upgrade"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 30)
    title.size = Vector2(get_viewport_rect().size.x, 40)
    add_child(title)

    # Currency display
    var currency_label = Label.new()
    currency_label.text = "Currency: %d" % (RunManager.currency if RunManager else 0)
    currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    currency_label.position = Vector2(0, 60)
    currency_label.size = Vector2(get_viewport_rect().size.x, 30)
    add_child(currency_label)

    var hbox = HBoxContainer.new()
    hbox.set("theme_override_constants/separation", 20)
    hbox.position = Vector2(60, 120)
    hbox.size = Vector2(get_viewport_rect().size.x - 120, get_viewport_rect().size.y - 200)
    add_child(hbox)

    var rarity_colors = {
        "common": Color(0.8, 0.8, 0.8),
        "rare": Color(0.3, 0.5, 1.0),
        "epic": Color(0.7, 0.2, 1.0),
    }

    for i in range(_upgrades.size()):
        var upgrade = _upgrades[i]

        var panel = PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hbox.add_child(panel)

        var vbox = VBoxContainer.new()
        vbox.set("theme_override_constants/separation", 8)
        panel.add_child(vbox)

        var name_label = Label.new()
        name_label.text = upgrade.upgrade_name
        name_label.modulate = rarity_colors.get(upgrade.rarity, Color.WHITE)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(name_label)

        var rarity_label = Label.new()
        rarity_label.text = "[%s]" % upgrade.rarity.to_upper()
        rarity_label.modulate = rarity_colors.get(upgrade.rarity, Color.WHITE)
        rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(rarity_label)

        var desc_label = Label.new()
        desc_label.text = upgrade.description
        desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        vbox.add_child(desc_label)

        var btn = Button.new()
        btn.text = "Pick"
        btn.pressed.connect(_on_pick.bind(i))
        vbox.add_child(btn)

func _on_pick(index: int) -> void:
    upgrade_picked.emit(_upgrades[index])
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/reward_screen.gd
git commit -m "feat: add RewardScreen UI for upgrade picks"
```

---

### Task 11: Game Over Screen UI

**Files:**
- Create: `src/ui/game_over_screen.gd`

- [ ] **Step 1: Create GameOverScreen**

```gdscript
class_name GameOverScreen
extends Control

signal return_pressed()

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var bg = ColorRect.new()
    bg.color = Color(0.08, 0.02, 0.02)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(PRESET_CENTER)
    vbox.set("theme_override_constants/separation", 12)
    vbox.position = Vector2(-200, -200)
    vbox.size = Vector2(400, 400)
    add_child(vbox)

    var title = Label.new()
    title.text = "GAME OVER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var stats = RunManager.stats if RunManager else RunStats.new()

    var stats_text = """Levels Cleared: %d
Monsters Killed: %d
Damage Dealt: %d
Time Survived: %ds
Loop Reached: %d
Currency Earned: %d
Upgrades: %d""" % [
        stats.levels_cleared,
        stats.kills,
        stats.damage_dealt,
        int(stats.time_elapsed),
        stats.loop,
        stats.total_currency_earned,
        RunManager.active_upgrades.size() if RunManager else 0,
    ]

    var stats_label = Label.new()
    stats_label.text = stats_text
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(stats_label)

    # Upgrade list
    if RunManager and RunManager.active_upgrades.size() > 0:
        var upgrades_label = Label.new()
        var upgrade_names: PackedStringArray = []
        for u in RunManager.active_upgrades:
            upgrade_names.append(u.upgrade_name)
        upgrades_label.text = "Upgrades: " + ", ".join(upgrade_names)
        upgrades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        vbox.add_child(upgrades_label)

    var btn = Button.new()
    btn.text = "Return to Lobby"
    btn.pressed.connect(func(): return_pressed.emit())
    vbox.add_child(btn)
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/game_over_screen.gd
git commit -m "feat: add GameOverScreen with run stats display"
```

---

### Task 12: Main.gd Refactor + Autoload Registration

**Files:**
- Modify: `src/main.gd` (TABS)
- Modify: `project.godot`

- [ ] **Step 1: Register RunManager autoload in project.godot**

In the `[autoload]` section, add after the `Elements` line:

```
RunManager="*res://src/run/run_manager.gd"
```

- [ ] **Step 2: Replace main.gd with RunManager-driven flow**

Replace entire `src/main.gd` with:

```gdscript
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
	add_child(lobby)
	current_scene = lobby

func _on_game_started(solo: bool) -> void:
	is_solo = solo
	RunManager.start_run()

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
```

- [ ] **Step 3: Commit**

```bash
git add src/main.gd project.godot
git commit -m "feat: RunManager-driven scene flow in Main.gd"
```

---

### Task 13: Final Test & Push

- [ ] **Step 1: Full playtest**

Run: `Play Solo`. Verify the full loop:
1. Lobby appears → click "Solo"
2. Map screen shows with branching nodes → click a node
3. Level loads with neon dungeon → monsters spawn
4. Kill all monsters → "Level Complete" reward screen appears
5. Pick an upgrade → returns to map
6. Repeat until depth 4 → Game Over screen shows stats
7. "Return to Lobby" → back to lobby
8. Start another run → verify upgrades apply (check health if picked +20 HP)

- [ ] **Step 2: Test player death path**

Uncheck God Mode. Let monsters kill you. Verify Game Over screen appears with stats.

- [ ] **Step 3: Push**

```bash
git push -u origin feature/game-loop-core
```
