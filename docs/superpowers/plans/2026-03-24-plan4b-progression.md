# Plan 4B: Progression, Boss, Shop, Abilities, Meta-Progression

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the roguelite game loop with victory/loop scaling, boss entity, shop, special abilities, and meta-progression.

**Architecture:** Extends existing RunManager state machine with VICTORY and SHOP states. New ECS components/systems for boss AI and special abilities. MetaSave singleton for persistent progression. All new files use 4-space indentation.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS framework, GUT for unit tests

**Spec:** `docs/superpowers/specs/2026-03-24-game-loop-progression-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `src/ui/victory_screen.gd` | Victory UI — stats + Continue/End Run buttons |
| `src/ui/shop_screen.gd` | Shop UI — buy upgrades, heal, reroll |
| `src/components/c_boss_ai.gd` | Boss AI component — ranged attack state |
| `src/systems/s_boss_ai.gd` | Boss AI system — ranged projectile attacks |
| `src/components/c_dash.gd` | Dash ability component |
| `src/systems/s_dash.gd` | Dash ability system |
| `src/components/c_aoe_blast.gd` | AoE blast ability component |
| `src/systems/s_aoe_blast.gd` | AoE blast ability system |
| `src/components/c_lifesteal.gd` | Lifesteal ability component |
| `src/systems/s_lifesteal.gd` | Lifesteal ability system |
| `src/run/meta_save.gd` | Meta-progression save/load singleton |
| `src/ui/meta_upgrades_screen.gd` | Lobby permanent upgrade shop UI |
| `test/unit/test_plan4b.gd` | GUT tests for new components and meta save |

### Modified Files

| File | Changes |
|------|---------|
| `src/run/run_manager.gd` | Add VICTORY handling, loop var, loop scaling, shop transitions, continue/end run |
| `src/main.gd` | Handle VICTORY, SHOP states in _on_state_changed |
| `src/config/game_config.gd` | Add monster_damage_mult, loop field |
| `src/levels/generated_level.gd` | Boss spawning, boss death handling, register ability systems |
| `src/entities/monster.gd` | Add setup_as_boss() for boss visuals/stats |
| `src/entities/player.gd` | Add ability components in apply_upgrades() |
| `src/run/upgrade_data.gd` | Add special ability upgrades to pool |
| `src/ui/hud.gd` | Add ability cooldown indicators |
| `src/ui/lobby_ui.gd` | Add meta-currency display, upgrades button |
| `project.godot` | Add MetaSave autoload, dash/aoe_blast input actions |

---

## Task 1: Victory Screen + VICTORY State

**Files:**
- Create: `src/ui/victory_screen.gd`
- Modify: `src/run/run_manager.gd:44-57,80-82`
- Modify: `src/main.gd:17-28`

- [ ] **Step 1: Create victory_screen.gd**

```gdscript
class_name VictoryScreen
extends Control

signal continue_pressed()
signal end_run_pressed()

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    _build_ui()

func _build_ui() -> void:
    var bg = ColorRect.new()
    bg.color = Color(0.02, 0.05, 0.02)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var center = CenterContainer.new()
    center.set_anchors_preset(PRESET_FULL_RECT)
    add_child(center)

    var vbox = VBoxContainer.new()
    vbox.set("theme_override_constants/separation", 12)
    center.add_child(vbox)

    var title = Label.new()
    title.text = "BOSS DEFEATED!"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var stats = RunManager.stats if RunManager else RunStats.new()

    var meta_earned = int(stats.total_currency_earned * Config.meta_currency_rate)
    var stats_text = """Levels Cleared: %d
Monsters Killed: %d
Damage Dealt: %d
Time Survived: %ds
Loop Reached: %d
Currency Earned: %d
Meta-Currency Earned: %d
Upgrades: %d""" % [
        stats.levels_cleared,
        stats.kills,
        stats.damage_dealt,
        int(stats.time_elapsed),
        stats.loop,
        stats.total_currency_earned,
        meta_earned,
        RunManager.active_upgrades.size() if RunManager else 0,
    ]

    var stats_label = Label.new()
    stats_label.text = stats_text
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(stats_label)

    if RunManager and RunManager.active_upgrades.size() > 0:
        var upgrades_label = Label.new()
        var upgrade_names: PackedStringArray = []
        for u in RunManager.active_upgrades:
            upgrade_names.append(u.upgrade_name)
        upgrades_label.text = "Upgrades: " + ", ".join(upgrade_names)
        upgrades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        vbox.add_child(upgrades_label)

    var btn_row = HBoxContainer.new()
    btn_row.set("theme_override_constants/separation", 20)
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(btn_row)

    var continue_btn = Button.new()
    continue_btn.text = "Continue (Loop +1)"
    continue_btn.pressed.connect(func(): continue_pressed.emit())
    btn_row.add_child(continue_btn)

    var end_btn = Button.new()
    end_btn.text = "End Run"
    end_btn.pressed.connect(func(): end_run_pressed.emit())
    btn_row.add_child(end_btn)
```

- [ ] **Step 2: Add VICTORY handling to RunManager**

In `src/run/run_manager.gd`, change `on_level_cleared()` to go to VICTORY instead of GAME_OVER when boss is beaten, and add `continue_run()` and `end_run()`:

Replace lines 44-57:
```gdscript
func on_level_cleared() -> void:
    stats.levels_cleared += 1
    add_currency(50)
    if not stats.took_damage_this_level:
        add_currency(30)
    stats.took_damage_this_level = false
    current_depth += 1
    level_cleared_signal.emit()
    if current_depth > Config.boss_depth:
        _change_state(State.VICTORY)
    else:
        _change_state(State.REWARD)
```

Add after `return_to_lobby()`:
```gdscript
func continue_run() -> void:
    stats.loop += 1
    current_depth = 0
    last_selected_node_index = 0
    map = RunMap.generate(Config.boss_depth)
    _change_state(State.MAP)

func end_run() -> void:
    run_ended.emit(stats)
    _change_state(State.GAME_OVER)
```

- [ ] **Step 3: Wire VICTORY state in main.gd**

In `src/main.gd`, add VICTORY case in `_on_state_changed` match block (uses TABS):

```gdscript
		RunManager.State.VICTORY:
			_show_victory()
```

Add `_show_victory()` method:
```gdscript
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
```

- [ ] **Step 4: Verify manually**

Run the game. Play through to boss level → defeat all monsters → verify Victory screen appears with "Continue" and "End Run" buttons. Click "End Run" → verify Game Over screen. Restart and click "Continue" → verify new map appears.

- [ ] **Step 5: Commit**

```bash
git add src/ui/victory_screen.gd src/run/run_manager.gd src/main.gd
git commit -m "feat: add victory screen with continue/end run options"
```

---

## Task 2: Loop Scaling

**Files:**
- Modify: `src/run/run_manager.gd:84-108`
- Modify: `src/config/game_config.gd:41`
- Modify: `src/levels/generated_level.gd:91-108`

- [ ] **Step 1: Add monster_damage_mult to GameConfig**

In `src/config/game_config.gd` (uses TABS), add after `var monster_hp_mult`:

```gdscript
var monster_damage_mult: float = 1.0
```

- [ ] **Step 2: Apply loop scaling in RunManager._apply_modifier()**

In `src/run/run_manager.gd`, update `_apply_modifier()` to apply loop multipliers AFTER the per-modifier settings. Replace the method:

```gdscript
func _apply_modifier(modifier: String) -> void:
    Config.current_modifier = modifier
    Config.level_grid_width = 12
    Config.level_grid_height = 12
    Config.monsters_per_room = 1
    Config.light_range_mult = 1.0
    Config.monster_hp_mult = 1.0
    Config.monster_damage_mult = 1.0

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
```

- [ ] **Step 3: Apply damage scaling at monster spawn**

In `src/levels/generated_level.gd`, update `_spawn_monsters()` to also scale attack damage. After the HP scaling block (line ~107), add:

```gdscript
            if Config.monster_damage_mult != 1.0 and monster.ecs_entity:
                var ai := monster.ecs_entity.get_component(C_MonsterAI) as C_MonsterAI
                if ai:
                    ai.attack_damage = int(ai.attack_damage * Config.monster_damage_mult)
```

- [ ] **Step 4: Verify manually**

Run the game → beat boss → click "Continue" → play loop 1 levels. Monsters should have ~50% more HP and ~25% more damage than loop 0.

- [ ] **Step 5: Commit**

```bash
git add src/run/run_manager.gd src/config/game_config.gd src/levels/generated_level.gd
git commit -m "feat: add loop scaling — monster HP +50%, damage +25% per loop"
```

---

## Task 3: Boss Entity

**Files:**
- Create: `src/components/c_boss_ai.gd`
- Create: `src/systems/s_boss_ai.gd`
- Modify: `src/entities/monster.gd:11-29`
- Modify: `src/levels/generated_level.gd:40-74,136-155`

- [ ] **Step 1: Create C_BossAI component**

```gdscript
class_name C_BossAI
extends Component

@export var ranged_cooldown: float = 2.0
@export var ranged_cooldown_remaining: float = 0.0
@export var projectile_damage: int = 15
@export var projectile_speed: float = 20.0
```

- [ ] **Step 2: Create S_BossAI system**

```gdscript
class_name S_BossAI
extends System

signal boss_projectile_requested(pos: Vector3, direction: Vector3, damage: int, speed: float, owner_id: int)

func query() -> QueryBuilder:
    return q.with_all([C_BossAI, C_MonsterAI, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var boss_ai := entity.get_component(C_BossAI) as C_BossAI
        var monster_ai := entity.get_component(C_MonsterAI) as C_MonsterAI
        var health := entity.get_component(C_Health) as C_Health

        if health.current_health <= 0:
            continue

        boss_ai.ranged_cooldown_remaining = maxf(boss_ai.ranged_cooldown_remaining - delta, 0)

        # Fire ranged attack when in ATTACK or CHASE state and cooldown ready
        if monster_ai.state != C_MonsterAI.AIState.IDLE and boss_ai.ranged_cooldown_remaining <= 0:
            boss_ai.ranged_cooldown_remaining = boss_ai.ranged_cooldown
            var body = entity.get_parent() as CharacterBody3D
            if not body:
                continue
            var target = _find_nearest_player(body.global_position)
            if target != Vector3.ZERO:
                var dir = (target - body.global_position).normalized()
                var spawn_pos = body.global_position + Vector3(0, 1.0, 0) + dir * 1.5
                boss_projectile_requested.emit(spawn_pos, dir, boss_ai.projectile_damage, boss_ai.projectile_speed, body.get_instance_id())

func _find_nearest_player(from: Vector3) -> Vector3:
    var tree = ECS.world.get_tree()
    if not tree:
        return Vector3.ZERO
    var nearest_dist := INF
    var nearest_pos := Vector3.ZERO
    for node in tree.get_nodes_in_group("players"):
        var dist = from.distance_to(node.global_position)
        if dist < nearest_dist:
            nearest_dist = dist
            nearest_pos = node.global_position
    return nearest_pos
```

- [ ] **Step 3: Add setup_as_boss() to MonsterEntity**

In `src/entities/monster.gd` (4-spaces), add method after `_setup_health_bar()`:

```gdscript
func setup_as_boss(loop: int) -> void:
    # Scale up
    scale = Vector3(2.0, 2.0, 2.0)

    # Red-tinted material
    if _body_material:
        _body_material.albedo_color = Color(0.2, 0.02, 0.02)
        _body_material.emission = Color(1.0, 0.15, 0.1)
        _body_material.emission_energy_multiplier = 2.0

    # Boss stats
    var health := ecs_entity.get_component(C_Health) as C_Health
    if health:
        health.max_health = 500 + (250 * loop)
        health.current_health = health.max_health

    var ai := ecs_entity.get_component(C_MonsterAI) as C_MonsterAI
    if ai:
        ai.attack_damage = 20 + (10 * loop)
        ai.move_speed = 4.0
        ai.detection_range = 30.0
        ai.attack_range = 3.0
        ai.attack_cooldown = 0.8

    # Add boss AI component
    ecs_entity.add_component(C_BossAI.new())
    var boss_ai := ecs_entity.get_component(C_BossAI) as C_BossAI
    if boss_ai:
        boss_ai.projectile_damage = 15 + (5 * loop)

    # Move health bar higher for larger model
    if _health_bar_node:
        _health_bar_node.position = Vector3(0, 2.4, 0)
```

- [ ] **Step 4: Spawn boss in generated_level.gd**

Add `var _is_boss_level: bool = false` at the top of `generated_level.gd` (after `var death_system`).

In `_ready()`, after `_spawn_monsters()` and before the auto-clear check, add boss spawning:

```gdscript
    _is_boss_level = RunManager != null and RunManager.state == RunManager.State.BOSS
    if _is_boss_level:
        _spawn_boss()
```

Add the boss spawning method:

```gdscript
func _spawn_boss() -> void:
    var boss = MonsterScene.instantiate()
    # Spawn at center of grid (inside the 5x5 pinned room block)
    var cx = level_data.width * Config.level_tile_size / 2.0
    var cz = level_data.height * Config.level_tile_size / 2.0
    boss.position = Vector3(cx, 1.0, cz)
    add_child(boss)
    boss.setup_as_boss(RunManager.stats.loop if RunManager else 0)
    monsters_remaining += 1
    print("[GeneratedLevel] Boss spawned at center (%s)" % str(boss.position))
```

Register S_BossAI in `_ready()`, after the other system registrations (after `ECS.world.add_system(S_MonsterAI.new())`):

```gdscript
    var boss_ai_system = S_BossAI.new()
    boss_ai_system.boss_projectile_requested.connect(_on_boss_projectile_requested)
    ECS.world.add_system(boss_ai_system)
```

Add the handler:

```gdscript
func _on_boss_projectile_requested(pos: Vector3, direction: Vector3, damage: int, speed: float, owner_id: int) -> void:
    var projectile = ProjectileScene.instantiate()
    add_child(projectile)
    projectile.global_position = pos
    projectile.setup(direction, speed, damage, "", owner_id)

    var flash = VfxFactory.create_muzzle_flash(pos)
    add_child(flash)
```

- [ ] **Step 5: Handle boss death separately**

In `generated_level.gd`, update `_on_actor_died()` to handle boss death:

Replace the monster death block:

```gdscript
    if tag.actor_type == C_ActorTag.ActorType.MONSTER:
        # Notify RunManager for currency
        var health := entity.get_component(C_Health) as C_Health
        if health and RunManager:
            RunManager.register_kill(health.max_health)

        # Boss death = immediate level clear
        if entity.get_component(C_BossAI):
            print("[GeneratedLevel] Boss defeated!")
            if RunManager:
                RunManager.on_level_cleared()
            return

        monsters_remaining -= 1
        if monsters_remaining <= 0 and not _is_boss_level:
            print("[GeneratedLevel] All monsters defeated!")
            if RunManager:
                RunManager.on_level_cleared()
```

- [ ] **Step 6: Verify manually**

Run game → navigate to boss level → verify: large red-tinted boss spawns at center, fires projectiles, has 500 HP, boss death triggers Victory screen.

- [ ] **Step 7: Commit**

```bash
git add src/components/c_boss_ai.gd src/systems/s_boss_ai.gd src/entities/monster.gd src/levels/generated_level.gd
git commit -m "feat: add boss entity with ranged attacks and 2x scale"
```

---

## Task 4: Shop Screen

**Files:**
- Create: `src/ui/shop_screen.gd`
- Modify: `src/run/run_manager.gd:63-65`
- Modify: `src/main.gd`

- [ ] **Step 1: Create shop_screen.gd**

```gdscript
class_name ShopScreen
extends Control

signal shop_finished()

var _items: Array = []
var _reroll_cost: int = 25
var _currency_label: Label
var _items_container: HBoxContainer

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    _items = UpgradeData.roll_random(5, RunManager.stats.loop if RunManager else 0)
    _build_ui()

func _build_ui() -> void:
    var bg = ColorRect.new()
    bg.color = Color(0.05, 0.03, 0.08)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var margin = MarginContainer.new()
    margin.set_anchors_preset(PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 40)
    margin.add_theme_constant_override("margin_right", 40)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    add_child(margin)

    var root_vbox = VBoxContainer.new()
    root_vbox.set("theme_override_constants/separation", 12)
    margin.add_child(root_vbox)

    var title = Label.new()
    title.text = "SHOP"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_vbox.add_child(title)

    _currency_label = Label.new()
    _update_currency_label()
    _currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_vbox.add_child(_currency_label)

    _items_container = HBoxContainer.new()
    _items_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _items_container.set("theme_override_constants/separation", 15)
    root_vbox.add_child(_items_container)

    _rebuild_items()

    # Bottom row: Heal + Reroll + Continue
    var bottom_row = HBoxContainer.new()
    bottom_row.set("theme_override_constants/separation", 20)
    bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
    root_vbox.add_child(bottom_row)

    var heal_cost = _get_heal_cost()
    var heal_btn = Button.new()
    heal_btn.text = "Heal to Full (%d)" % heal_cost
    heal_btn.pressed.connect(_on_heal.bind(heal_btn))
    bottom_row.add_child(heal_btn)

    var reroll_btn = Button.new()
    reroll_btn.text = "Reroll (%d)" % _reroll_cost
    reroll_btn.pressed.connect(_on_reroll.bind(reroll_btn))
    bottom_row.add_child(reroll_btn)

    var continue_btn = Button.new()
    continue_btn.text = "Continue"
    continue_btn.pressed.connect(func(): shop_finished.emit())
    bottom_row.add_child(continue_btn)

func _rebuild_items() -> void:
    for child in _items_container.get_children():
        child.queue_free()

    var rarity_colors = {
        "common": Color(0.8, 0.8, 0.8),
        "rare": Color(0.3, 0.5, 1.0),
        "epic": Color(0.7, 0.2, 1.0),
    }
    var loop = RunManager.stats.loop if RunManager else 0
    var price_mult = 1.0 + (0.5 * loop)

    for i in range(_items.size()):
        var upgrade = _items[i]
        var price = int(upgrade.cost * price_mult)

        var panel = PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _items_container.add_child(panel)

        var vbox = VBoxContainer.new()
        vbox.set("theme_override_constants/separation", 6)
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

        var buy_btn = Button.new()
        buy_btn.text = "Buy (%d)" % price
        buy_btn.pressed.connect(_on_buy.bind(i, price, buy_btn))
        if RunManager and RunManager.currency < price:
            buy_btn.disabled = true
        vbox.add_child(buy_btn)

func _on_buy(index: int, price: int, btn: Button) -> void:
    if not RunManager or not RunManager.spend_currency(price):
        return
    var upgrade = _items[index]
    RunManager.active_upgrades.append(upgrade)
    _items.remove_at(index)
    _update_currency_label()
    _rebuild_items()

func _on_heal(btn: Button) -> void:
    var cost = _get_heal_cost()
    if not RunManager or not RunManager.spend_currency(cost):
        return
    btn.disabled = true
    btn.text = "Healed!"
    _update_currency_label()
    # Healing is applied when player spawns next level (full HP reset in apply_upgrades)

func _on_reroll(btn: Button) -> void:
    if not RunManager or not RunManager.spend_currency(_reroll_cost):
        return
    _reroll_cost += 25
    btn.text = "Reroll (%d)" % _reroll_cost
    _items = UpgradeData.roll_random(5, RunManager.stats.loop if RunManager else 0)
    _update_currency_label()
    _rebuild_items()

func _update_currency_label() -> void:
    _currency_label.text = "Currency: %d" % (RunManager.currency if RunManager else 0)

func _get_heal_cost() -> int:
    var loop = RunManager.stats.loop if RunManager else 0
    return 50 + (25 * loop)
```

- [ ] **Step 2: Add shop transition in RunManager**

In `src/run/run_manager.gd`, replace `pick_upgrade()`:

```gdscript
func spend_currency(amount: int) -> bool:
    if currency < amount:
        return false
    currency -= amount
    currency_changed.emit(currency)
    return true

func pick_upgrade(upgrade: UpgradeData) -> void:
    active_upgrades.append(upgrade)
    if current_depth > 0 and current_depth % Config.shop_frequency == 0:
        _change_state(State.SHOP)
    else:
        _change_state(State.MAP)

func finish_shopping() -> void:
    _change_state(State.MAP)
```

- [ ] **Step 3: Wire SHOP state in main.gd**

In `src/main.gd` (TABS), add SHOP case in the match block:

```gdscript
		RunManager.State.SHOP:
			_show_shop()
```

Add method:

```gdscript
func _show_shop() -> void:
	var shop = ShopScreen.new()
	shop.shop_finished.connect(_on_shop_finished)
	add_child(shop)
	current_scene = shop

func _on_shop_finished() -> void:
	RunManager.finish_shopping()
```

- [ ] **Step 4: Verify manually**

Run game → clear 2 levels → after picking reward for 2nd level, shop should appear. Buy an upgrade, reroll, then continue. Verify currency deduction works.

- [ ] **Step 5: Commit**

```bash
git add src/ui/shop_screen.gd src/run/run_manager.gd src/main.gd
git commit -m "feat: add shop screen with buy, heal, and reroll"
```

---

## Task 5: Special Ability — Dash

**Files:**
- Create: `src/components/c_dash.gd`
- Create: `src/systems/s_dash.gd`
- Modify: `project.godot` (add dash input action)

- [ ] **Step 1: Create C_Dash component**

```gdscript
class_name C_Dash
extends Component

@export var cooldown: float = 3.0
@export var cooldown_remaining: float = 0.0
@export var dash_speed: float = 20.0
@export var dash_duration: float = 0.15
@export var dash_remaining: float = 0.0
@export var dash_direction: Vector3 = Vector3.ZERO
```

- [ ] **Step 2: Create S_Dash system**

```gdscript
class_name S_Dash
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Dash, C_Velocity, C_NetworkIdentity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity
        if not net_id.is_local:
            continue

        var dash := entity.get_component(C_Dash) as C_Dash
        var vel := entity.get_component(C_Velocity) as C_Velocity

        dash.cooldown_remaining = maxf(dash.cooldown_remaining - delta, 0)

        # Active dash in progress
        if dash.dash_remaining > 0:
            dash.dash_remaining -= delta
            vel.direction = dash.dash_direction
            vel.speed = dash.dash_speed
            continue

        # Trigger new dash
        if Input.is_action_just_pressed("dash") and dash.cooldown_remaining <= 0:
            if vel.direction.length() > 0.1:
                dash.dash_direction = vel.direction.normalized()
            else:
                # Dash forward if standing still
                var body = entity.get_parent() as Node3D
                if body:
                    dash.dash_direction = -body.global_transform.basis.z.normalized()
                else:
                    dash.dash_direction = Vector3.FORWARD
            dash.dash_remaining = dash.dash_duration
            dash.cooldown_remaining = dash.cooldown
```

- [ ] **Step 3: Add dash input action to project.godot**

In `project.godot`, add in the `[input]` section (before `[rendering]`):

```ini
dash={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194325,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 4: Commit**

```bash
git add src/components/c_dash.gd src/systems/s_dash.gd project.godot
git commit -m "feat: add dash ability component and system (Shift key)"
```

---

## Task 6: Special Ability — AoE Blast

**Files:**
- Create: `src/components/c_aoe_blast.gd`
- Create: `src/systems/s_aoe_blast.gd`
- Modify: `project.godot` (add aoe_blast input action)

- [ ] **Step 1: Create C_AoEBlast component**

```gdscript
class_name C_AoEBlast
extends Component

@export var cooldown: float = 8.0
@export var cooldown_remaining: float = 0.0
@export var damage: int = 30
@export var radius: float = 5.0
```

- [ ] **Step 2: Create S_AoEBlast system**

```gdscript
class_name S_AoEBlast
extends System

func query() -> QueryBuilder:
    return q.with_all([C_AoEBlast, C_NetworkIdentity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity
        if not net_id.is_local:
            continue

        var blast := entity.get_component(C_AoEBlast) as C_AoEBlast
        blast.cooldown_remaining = maxf(blast.cooldown_remaining - delta, 0)

        if Input.is_action_just_pressed("aoe_blast") and blast.cooldown_remaining <= 0:
            blast.cooldown_remaining = blast.cooldown
            var body = entity.get_parent() as Node3D
            if not body:
                continue
            _deal_aoe_damage(body.global_position, blast.damage, blast.radius)

func _deal_aoe_damage(center: Vector3, damage: int, radius: float) -> void:
    var tree = ECS.world.get_tree()
    if not tree:
        return
    for monster in tree.get_nodes_in_group("monsters"):
        if not is_instance_valid(monster):
            continue
        if monster.global_position.distance_to(center) <= radius:
            if monster is MonsterEntity and monster.ecs_entity:
                S_Damage.apply_damage(monster.ecs_entity, damage, "")

    # Visual feedback: ring of particles
    var particles = GPUParticles3D.new()
    particles.position = center
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 20
    particles.lifetime = 0.3
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)

    var mat = ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0.5, 0)
    mat.spread = 180.0
    mat.initial_velocity_min = 8.0
    mat.initial_velocity_max = 12.0
    mat.gravity = Vector3(0, -2, 0)
    mat.scale_min = 0.08
    mat.scale_max = 0.15
    particles.process_material = mat

    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = Color(1.0, 0.6, 0.1)
    draw_mat.emission_enabled = true
    draw_mat.emission = Color(1.0, 0.6, 0.1)
    draw_mat.emission_energy_multiplier = 4.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    var mesh = SphereMesh.new()
    mesh.radius = 0.04
    mesh.height = 0.08
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    tree.current_scene.add_child(particles)
```

- [ ] **Step 3: Add monsters group to MonsterEntity**

In `src/entities/monster.gd`, add at the end of `_ready()`:

```gdscript
    add_to_group("monsters")
```

- [ ] **Step 4: Add aoe_blast input action to project.godot**

In `project.godot`, add in the `[input]` section:

```ini
aoe_blast={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":81,"physical_keycode":0,"key_label":0,"unicode":113,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 5: Commit**

```bash
git add src/components/c_aoe_blast.gd src/systems/s_aoe_blast.gd src/entities/monster.gd project.godot
git commit -m "feat: add AoE blast ability component and system (Q key)"
```

---

## Task 7: Special Ability — Lifesteal

**Files:**
- Create: `src/components/c_lifesteal.gd`
- Create: `src/systems/s_lifesteal.gd`
- Modify: `src/levels/generated_level.gd` (register system, connect signal)

- [ ] **Step 1: Create C_Lifesteal component**

```gdscript
class_name C_Lifesteal
extends Component

@export var percent: float = 0.1  # Heal 10% of killed enemy's max HP
```

- [ ] **Step 2: Create S_Lifesteal system**

This system doesn't use the ECS query loop. It listens to the S_Death.actor_died signal and heals the player.

```gdscript
class_name S_Lifesteal
extends System

func query() -> QueryBuilder:
    # This system is signal-driven, not query-driven
    return q.with_all([C_Lifesteal])

func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
    pass

func on_actor_died(entity: Entity) -> void:
    var tag := entity.get_component(C_ActorTag) as C_ActorTag
    if not tag or tag.actor_type != C_ActorTag.ActorType.MONSTER:
        return

    var victim_health := entity.get_component(C_Health) as C_Health
    if not victim_health:
        return

    # Find players with lifesteal
    var tree = ECS.world.get_tree()
    if not tree:
        return
    for player_node in tree.get_nodes_in_group("players"):
        if not player_node is PlayerEntity:
            continue
        var lifesteal := player_node.ecs_entity.get_component(C_Lifesteal) as C_Lifesteal
        if not lifesteal:
            continue
        var player_health := player_node.ecs_entity.get_component(C_Health) as C_Health
        if not player_health:
            continue
        var heal_amount = int(victim_health.max_health * lifesteal.percent)
        if heal_amount > 0:
            player_health.current_health = mini(
                player_health.current_health + heal_amount,
                player_health.max_health
            )
```

- [ ] **Step 3: Register S_Lifesteal in generated_level.gd**

In `src/levels/generated_level.gd`, after `death_system` is added (around line 47), add:

```gdscript
    var lifesteal_system = S_Lifesteal.new()
    death_system.actor_died.connect(lifesteal_system.on_actor_died)
    ECS.world.add_system(lifesteal_system)
```

- [ ] **Step 4: Commit**

```bash
git add src/components/c_lifesteal.gd src/systems/s_lifesteal.gd src/levels/generated_level.gd
git commit -m "feat: add lifesteal ability — heal 10% of killed enemy's max HP"
```

---

## Task 8: Wire Abilities — Upgrade Pool, Player, HUD

**Files:**
- Modify: `src/run/upgrade_data.gd:15-28`
- Modify: `src/entities/player.gd:105-118`
- Modify: `src/levels/generated_level.gd` (register S_Dash, S_AoEBlast)
- Modify: `src/ui/hud.gd`

- [ ] **Step 1: Add special ability upgrades to pool**

In `src/run/upgrade_data.gd`, add after the existing defensive upgrades (line 27), inside `get_pool()`:

```gdscript
            # Special abilities (epic)
            _make("Dash", "Speed burst (Shift), 3s cooldown", "special", "epic", "dash", 1.0, 120),
            _make("AoE Blast", "Damage nearby enemies (Q), 8s cooldown", "special", "epic", "aoe_blast", 1.0, 120),
            _make("Lifesteal", "Heal 10% of killed enemy's max HP", "special", "epic", "lifesteal", 0.1, 120),
```

- [ ] **Step 2: Handle special abilities in player.apply_upgrades()**

In `src/entities/player.gd`, add at the end of `apply_upgrades()`:

```gdscript
    # Special abilities — add components if upgrade acquired
    var upgrades = RunManager.active_upgrades if RunManager else []
    for upgrade in upgrades:
        match upgrade.property:
            "dash":
                if not ecs_entity.get_component(C_Dash):
                    ecs_entity.add_component(C_Dash.new())
            "aoe_blast":
                if not ecs_entity.get_component(C_AoEBlast):
                    ecs_entity.add_component(C_AoEBlast.new())
            "lifesteal":
                if not ecs_entity.get_component(C_Lifesteal):
                    ecs_entity.add_component(C_Lifesteal.new())
```

- [ ] **Step 3: Register S_Dash and S_AoEBlast in generated_level.gd**

In `src/levels/generated_level.gd`, add after the other system registrations:

```gdscript
    ECS.world.add_system(S_Dash.new())
    ECS.world.add_system(S_AoEBlast.new())
```

- [ ] **Step 4: Add ability cooldown indicators to HUD**

In `src/ui/hud.gd` (TABS), add a label for abilities. Add after `@onready var damage_flash`:

```gdscript
@onready var abilities_label: Label = $MarginContainer/VBoxContainer/AbilitiesLabel
```

**Note:** The `AbilitiesLabel` node must be added to the `hud.tscn` scene file — add a Label named "AbilitiesLabel" as a child of the existing VBoxContainer.

In `_process()`, add after the weapon label update (inside the player loop, before `break`):

```gdscript
			# Ability cooldowns
			var ability_parts: PackedStringArray = []
			var dash_comp = player.get_component(C_Dash)
			if dash_comp:
				if dash_comp.cooldown_remaining > 0:
					ability_parts.append("Dash: %.1fs" % dash_comp.cooldown_remaining)
				else:
					ability_parts.append("Dash: READY")
			var blast_comp = player.get_component(C_AoEBlast)
			if blast_comp:
				if blast_comp.cooldown_remaining > 0:
					ability_parts.append("AoE: %.1fs" % blast_comp.cooldown_remaining)
				else:
					ability_parts.append("AoE: READY")
			var lifesteal_comp = player.get_component(C_Lifesteal)
			if lifesteal_comp:
				ability_parts.append("Lifesteal: ON")
			abilities_label.text = " | ".join(ability_parts) if ability_parts.size() > 0 else ""
```

- [ ] **Step 5: Verify manually**

Run game → pick Dash or AoE Blast upgrade → verify ability works in next level. Press Shift to dash, Q to blast. Check HUD shows cooldowns.

- [ ] **Step 6: Commit**

```bash
git add src/run/upgrade_data.gd src/entities/player.gd src/levels/generated_level.gd src/ui/hud.gd src/ui/hud.tscn
git commit -m "feat: wire special abilities — upgrade pool, player application, HUD cooldowns"
```

---

## Task 9: Meta-Progression — Save System + Upgrades Screen + Lobby

**Files:**
- Create: `src/run/meta_save.gd`
- Create: `src/ui/meta_upgrades_screen.gd`
- Modify: `project.godot` (add MetaSave autoload)
- Modify: `src/run/run_manager.gd` (apply meta upgrades at run start)
- Modify: `src/main.gd` (handle meta upgrades screen)
- Modify: `src/ui/game_over_screen.gd` (add meta-currency earned display)
- Modify: `src/ui/lobby_ui.gd` + `src/ui/lobby_ui.tscn`

- [ ] **Step 1: Create meta_save.gd**

```gdscript
extends Node

const SAVE_PATH = "user://meta_save.json"

var meta_currency: int = 0
var best_loop: int = 0
var best_depth: int = 0
var total_kills: int = 0

# Permanent upgrade tiers: 0 = not purchased, 1-3 = tier level
var upgrades: Dictionary = {
    "tough": 0,       # +10 max HP per tier
    "strong": 0,      # +5% damage per tier
    "head_start": 0,  # start with N random upgrades
}

const UPGRADE_DEFS: Array = [
    {
        "id": "tough",
        "name": "Tough",
        "description": "+10 starting max HP per tier",
        "max_tier": 3,
        "costs": [100, 200, 400],
    },
    {
        "id": "strong",
        "name": "Strong",
        "description": "+5% starting damage per tier",
        "max_tier": 3,
        "costs": [100, 200, 400],
    },
    {
        "id": "head_start",
        "name": "Head Start",
        "description": "Start run with random upgrades",
        "max_tier": 3,
        "costs": [150, 300, 600],
    },
]

func _ready() -> void:
    load_data()

func save_data() -> void:
    var data = {
        "meta_currency": meta_currency,
        "best_loop": best_loop,
        "best_depth": best_depth,
        "total_kills": total_kills,
        "upgrades": upgrades,
    }
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var json = JSON.new()
    if json.parse(file.get_as_text()) != OK:
        return
    var data = json.data
    if data is Dictionary:
        meta_currency = data.get("meta_currency", 0)
        best_loop = data.get("best_loop", 0)
        best_depth = data.get("best_depth", 0)
        total_kills = data.get("total_kills", 0)
        var saved_upgrades = data.get("upgrades", {})
        for key in saved_upgrades:
            if upgrades.has(key):
                upgrades[key] = saved_upgrades[key]

func on_run_ended(stats: RunStats) -> void:
    var earned = int(stats.total_currency_earned * Config.meta_currency_rate)
    meta_currency += earned
    total_kills += stats.kills
    if stats.loop > best_loop:
        best_loop = stats.loop
    if stats.levels_cleared > best_depth:
        best_depth = stats.levels_cleared
    save_data()

func purchase_upgrade(upgrade_id: String) -> bool:
    var current_tier = upgrades.get(upgrade_id, 0)
    var def = _get_def(upgrade_id)
    if not def or current_tier >= def.max_tier:
        return false
    var cost = def.costs[current_tier]
    if meta_currency < cost:
        return false
    meta_currency -= cost
    upgrades[upgrade_id] = current_tier + 1
    save_data()
    return true

func get_starting_upgrades() -> Array:
    var result: Array = []
    # Tough: +10 max HP per tier
    var tough_tier = upgrades.get("tough", 0)
    if tough_tier > 0:
        for i in range(tough_tier):
            result.append(UpgradeData._make(
                "Meta: Tough %d" % (i + 1), "+10 max HP (permanent)",
                "stat", "common", "max_health_bonus", 10.0, 0))
    # Strong: +5% damage per tier
    var strong_tier = upgrades.get("strong", 0)
    if strong_tier > 0:
        for i in range(strong_tier):
            result.append(UpgradeData._make(
                "Meta: Strong %d" % (i + 1), "+5% damage (permanent)",
                "stat", "common", "damage_mult", 0.05, 0))
    # Head Start: random upgrades
    var hs_tier = upgrades.get("head_start", 0)
    if hs_tier > 0:
        var randoms = UpgradeData.roll_random(hs_tier, 0)
        result.append_array(randoms)
    return result

func _get_def(upgrade_id: String) -> Variant:
    for def in UPGRADE_DEFS:
        if def.id == upgrade_id:
            return def
    return null
```

- [ ] **Step 2: Create meta_upgrades_screen.gd**

```gdscript
class_name MetaUpgradesScreen
extends Control

signal back_pressed()

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    _build_ui()

func _build_ui() -> void:
    var bg = ColorRect.new()
    bg.color = Color(0.04, 0.04, 0.08)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var margin = MarginContainer.new()
    margin.set_anchors_preset(PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 60)
    margin.add_theme_constant_override("margin_right", 60)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_bottom", 30)
    add_child(margin)

    var root_vbox = VBoxContainer.new()
    root_vbox.set("theme_override_constants/separation", 15)
    margin.add_child(root_vbox)

    var title = Label.new()
    title.text = "PERMANENT UPGRADES"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_vbox.add_child(title)

    var currency_label = Label.new()
    currency_label.text = "Meta-Currency: %d" % MetaSave.meta_currency
    currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    currency_label.name = "CurrencyLabel"
    root_vbox.add_child(currency_label)

    var stats_label = Label.new()
    stats_label.text = "Best Loop: %d | Best Depth: %d | Total Kills: %d" % [
        MetaSave.best_loop, MetaSave.best_depth, MetaSave.total_kills]
    stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_vbox.add_child(stats_label)

    var upgrades_vbox = VBoxContainer.new()
    upgrades_vbox.set("theme_override_constants/separation", 10)
    upgrades_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    upgrades_vbox.name = "UpgradesVBox"
    root_vbox.add_child(upgrades_vbox)

    _rebuild_upgrades(upgrades_vbox, currency_label)

    var back_btn = Button.new()
    back_btn.text = "Back to Lobby"
    back_btn.pressed.connect(func(): back_pressed.emit())
    root_vbox.add_child(back_btn)

func _rebuild_upgrades(container: VBoxContainer, currency_label: Label) -> void:
    for child in container.get_children():
        child.queue_free()

    for def in MetaSave.UPGRADE_DEFS:
        var current_tier = MetaSave.upgrades.get(def.id, 0)
        var hbox = HBoxContainer.new()
        hbox.set("theme_override_constants/separation", 15)
        container.add_child(hbox)

        var info = Label.new()
        var tier_text = "Tier %d/%d" % [current_tier, def.max_tier]
        info.text = "%s — %s (%s)" % [def.name, def.description, tier_text]
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hbox.add_child(info)

        if current_tier < def.max_tier:
            var cost = def.costs[current_tier]
            var btn = Button.new()
            btn.text = "Buy (%d)" % cost
            if MetaSave.meta_currency < cost:
                btn.disabled = true
            btn.pressed.connect(func():
                if MetaSave.purchase_upgrade(def.id):
                    _rebuild_upgrades(container, currency_label)
                    currency_label.text = "Meta-Currency: %d" % MetaSave.meta_currency
            )
            hbox.add_child(btn)
        else:
            var maxed = Label.new()
            maxed.text = "MAXED"
            maxed.modulate = Color(0.3, 1.0, 0.3)
            hbox.add_child(maxed)
```

- [ ] **Step 3: Add MetaSave autoload to project.godot**

In `project.godot`, add in the `[autoload]` section:

```ini
MetaSave="*res://src/run/meta_save.gd"
```

- [ ] **Step 4: Connect run_ended to MetaSave in RunManager**

In `src/run/run_manager.gd`, update `end_run()` and `on_player_died()` to also call MetaSave:

```gdscript
func end_run() -> void:
    run_ended.emit(stats)
    if MetaSave:
        MetaSave.on_run_ended(stats)
    _change_state(State.GAME_OVER)

func on_player_died() -> void:
    run_ended.emit(stats)
    if MetaSave:
        MetaSave.on_run_ended(stats)
    _change_state(State.GAME_OVER)
```

- [ ] **Step 5: Apply meta upgrades at run start**

In `src/run/run_manager.gd`, update `start_run()` to pre-load meta upgrades:

```gdscript
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
```

- [ ] **Step 6: Add meta-currency display and upgrades button to lobby**

In `src/ui/lobby_ui.gd` (TABS), add at end of `_ready()`:

```gdscript
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
```

Add the signal and handler:

```gdscript
signal meta_upgrades_pressed()

func _on_meta_upgrades():
	meta_upgrades_pressed.emit()
```

- [ ] **Step 7: Handle meta upgrades screen in main.gd**

In `src/main.gd` (TABS), update `_show_lobby()` to connect the new signal:

```gdscript
func _show_lobby() -> void:
	var lobby = LobbyScene.instantiate()
	lobby.game_started.connect(_on_game_started)
	lobby.meta_upgrades_pressed.connect(_on_meta_upgrades)
	add_child(lobby)
	current_scene = lobby

func _on_meta_upgrades() -> void:
	_clear_current()
	var screen = MetaUpgradesScreen.new()
	screen.back_pressed.connect(_on_meta_upgrades_back)
	add_child(screen)
	current_scene = screen

func _on_meta_upgrades_back() -> void:
	_clear_current()
	_show_lobby()
```

- [ ] **Step 8: Add meta-currency earned to Game Over screen**

In `src/ui/game_over_screen.gd`, update the stats_text to include meta-currency earned. Replace the stats_text format string:

```gdscript
    var meta_earned = int(stats.total_currency_earned * Config.meta_currency_rate)
    var stats_text = """Levels Cleared: %d
Monsters Killed: %d
Damage Dealt: %d
Time Survived: %ds
Loop Reached: %d
Currency Earned: %d
Meta-Currency Earned: %d
Upgrades: %d""" % [
        stats.levels_cleared,
        stats.kills,
        stats.damage_dealt,
        int(stats.time_elapsed),
        stats.loop,
        stats.total_currency_earned,
        meta_earned,
        RunManager.active_upgrades.size() if RunManager else 0,
    ]
```

- [ ] **Step 9: Verify manually**

Run game → verify lobby shows meta-currency and "Permanent Upgrades" button. Play a run → die or end run → verify meta-currency earned shown on Game Over/Victory screens. Return to lobby → buy permanent upgrade → start new run → verify bonus applied.

- [ ] **Step 10: Commit**

```bash
git add src/run/meta_save.gd src/ui/meta_upgrades_screen.gd project.godot src/run/run_manager.gd src/main.gd src/ui/lobby_ui.gd src/ui/game_over_screen.gd
git commit -m "feat: add meta-progression — save file, permanent upgrades, lobby integration"
```

---

## Task 10: GUT Tests

**Files:**
- Create: `test/unit/test_plan4b.gd`

- [ ] **Step 1: Write unit tests**

```gdscript
extends GutTest

# --- C_BossAI defaults ---
func test_boss_ai_defaults():
    var b = C_BossAI.new()
    assert_eq(b.ranged_cooldown, 2.0)
    assert_eq(b.ranged_cooldown_remaining, 0.0)
    assert_eq(b.projectile_damage, 15)
    assert_eq(b.projectile_speed, 20.0)

# --- C_Dash defaults ---
func test_dash_defaults():
    var d = C_Dash.new()
    assert_eq(d.cooldown, 3.0)
    assert_eq(d.dash_speed, 20.0)
    assert_eq(d.dash_duration, 0.15)

# --- C_AoEBlast defaults ---
func test_aoe_blast_defaults():
    var a = C_AoEBlast.new()
    assert_eq(a.cooldown, 8.0)
    assert_eq(a.damage, 30)
    assert_eq(a.radius, 5.0)

# --- C_Lifesteal defaults ---
func test_lifesteal_defaults():
    var l = C_Lifesteal.new()
    assert_almost_eq(l.percent, 0.1, 0.001)

# --- UpgradeData pool has special abilities ---
func test_upgrade_pool_has_specials():
    UpgradeData._pool.clear()  # Force fresh pool
    var pool = UpgradeData.get_pool()
    var names: PackedStringArray = []
    for u in pool:
        names.append(u.upgrade_name)
    assert_has(names, "Dash")
    assert_has(names, "AoE Blast")
    assert_has(names, "Lifesteal")

func test_upgrade_pool_specials_are_epic():
    UpgradeData._pool.clear()
    var pool = UpgradeData.get_pool()
    for u in pool:
        if u.upgrade_name in ["Dash", "AoE Blast", "Lifesteal"]:
            assert_eq(u.rarity, "epic", "%s should be epic" % u.upgrade_name)

# --- RunStats loop tracking ---
func test_run_stats_loop_default():
    var s = RunStats.new()
    assert_eq(s.loop, 0)

func test_run_stats_reset_clears_loop():
    var s = RunStats.new()
    s.loop = 3
    s.reset()
    assert_eq(s.loop, 0)

# --- C_PlayerStats recalculate with meta upgrades ---
func test_player_stats_stacks_meta_upgrades():
    var ps = C_PlayerStats.new()
    var upgrades = [
        UpgradeData._make("Meta: Tough 1", "", "stat", "common", "max_health_bonus", 10.0, 0),
        UpgradeData._make("Meta: Strong 1", "", "stat", "common", "damage_mult", 0.05, 0),
        UpgradeData._make("Damage +10%", "", "stat", "common", "damage_mult", 0.10, 0),
    ]
    ps.recalculate(upgrades)
    assert_eq(ps.max_health_bonus, 10)
    assert_almost_eq(ps.damage_mult, 1.15, 0.001)  # 1.0 + 0.05 + 0.10

# --- MetaSave round-trip ---
func test_meta_save_starting_upgrades_tough():
    # Test that Tough tier generates correct starting upgrades
    # (Can't test actual save/load without autoload, but can test get_starting_upgrades logic)
    var ms = preload("res://src/run/meta_save.gd").new()
    ms.upgrades["tough"] = 2
    var starting = ms.get_starting_upgrades()
    var hp_bonus = 0
    for u in starting:
        if u.property == "max_health_bonus":
            hp_bonus += int(u.value)
    assert_eq(hp_bonus, 20, "Tough tier 2 should give +20 max HP (10 per tier)")
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_plan4b.gd
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_plan4b.gd
git commit -m "test: add GUT tests for Plan 4B components and upgrade pool"
```
