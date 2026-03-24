# Combat & Elemental System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add combat with weapons, projectiles, damage, health, death, basic monsters with AI, and the elemental condition system with combinatorial interactions — all configurable at runtime.

**Architecture:** Data-driven ECS approach. Elements, conditions, and their interactions are defined as configurable resources, not hardcoded. Systems process damage, conditions, and elemental combinations. Monsters use the same actor/entity composition pattern as players (CharacterBody3D + Entity child).

**Tech Stack:** Godot 4.4+, GDScript, GECS v6.8.1, GUT

**Spec:** See `SPEC.md` — sections: Actors, Elemental System, Configurability

**Important:** GECS requires a World node created and assigned to `ECS.world` before use (done in `test_level.gd`). Entity extends Node, so actors use composition: CharacterBody3D owns an Entity child. Use `ECS.process(delta)` for the game loop. Register entities via `ECS.world.add_entity()`.

---

## File Structure

```
src/
  config/
    game_config.gd                     # Modify: add combat/elemental config
    element_registry.gd                # NEW: autoload — defines elements and interaction rules
  components/
    c_health.gd                        # Existing (no change needed)
    c_conditions.gd                    # NEW: active conditions on an actor
    c_damage_dealer.gd                 # NEW: marks entity as dealing damage on contact
    c_projectile.gd                    # NEW: projectile data (speed, element, owner)
    c_weapon.gd                        # NEW: weapon stats (fire rate, damage, element)
    c_monster_ai.gd                    # NEW: AI state and behavior params
    c_actor_tag.gd                     # NEW: identifies actor type (player/monster)
    c_lifetime.gd                      # NEW: auto-destroy after duration
  systems/
    s_damage.gd                        # NEW: applies damage from damage dealers to health
    s_conditions.gd                    # NEW: ticks condition timers, applies effects
    s_projectile.gd                    # NEW: moves projectiles, checks collisions
    s_weapon.gd                        # NEW: handles weapon firing (cooldown, spawn projectile)
    s_monster_ai.gd                    # NEW: basic monster behavior (chase, attack)
    s_lifetime.gd                      # NEW: destroys entities when lifetime expires
    s_death.gd                         # NEW: handles health <= 0
  entities/
    projectile.tscn                    # NEW: projectile scene
    projectile.gd                      # NEW: projectile script
    monster.tscn                       # NEW: basic monster scene
    monster.gd                         # NEW: monster script (same pattern as player)
test/
  unit/
    test_element_registry.gd           # NEW: element interaction tests
    test_conditions.gd                 # NEW: condition application/combination tests
    test_damage.gd                     # NEW: damage calculation tests
```

---

### Task 1: Element Registry

**Files:**
- Create: `src/config/element_registry.gd`
- Create: `test/unit/test_element_registry.gd`
- Modify: `project.godot` (add autoload)

- [ ] **Step 1: Write failing tests**

Create `test/unit/test_element_registry.gd`:
```gdscript
extends GutTest

var registry: ElementRegistry

func before_each():
    registry = ElementRegistry.new()
    registry._setup_defaults()

func test_has_default_elements():
    assert_true(registry.has_element("fire"))
    assert_true(registry.has_element("ice"))
    assert_true(registry.has_element("water"))
    assert_true(registry.has_element("oil"))

func test_element_has_properties():
    var fire = registry.get_element("fire")
    assert_not_null(fire)
    assert_has(fire, "name")
    assert_has(fire, "color")

func test_interaction_wet_plus_ice_equals_frozen():
    var result = registry.get_interaction("wet", "ice")
    assert_not_null(result)
    assert_eq(result.result_condition, "frozen")

func test_interaction_oily_plus_fire_equals_burning():
    var result = registry.get_interaction("oily", "fire")
    assert_not_null(result)
    assert_eq(result.result_condition, "burning")

func test_element_applies_condition():
    var fire = registry.get_element("fire")
    assert_has(fire, "applies_condition")

func test_unknown_element_returns_null():
    assert_null(registry.get_element("nonexistent"))

func test_unknown_interaction_returns_null():
    assert_null(registry.get_interaction("fire", "fire"))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
godot --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_element_registry
```
Expected: FAIL — `ElementRegistry` not found.

- [ ] **Step 3: Implement ElementRegistry**

Create `src/config/element_registry.gd`:
```gdscript
class_name ElementRegistry
extends Node

# Element definition: { name, color, applies_condition, condition_duration }
var elements: Dictionary = {}

# Interaction rules: { "condition_name+element_name": { result_condition, duration, damage_per_tick } }
var interactions: Dictionary = {}

# Stacking mode: "reset", "extend", "intensify"
@export var stacking_mode: String = "reset"

func _ready() -> void:
    _setup_defaults()

func _setup_defaults() -> void:
    # Default elements
    add_element("fire", Color.ORANGE_RED, "burning", 3.0)
    add_element("ice", Color.LIGHT_BLUE, "chilled", 3.0)
    add_element("water", Color.DODGER_BLUE, "wet", 5.0)
    add_element("oil", Color.DARK_OLIVE_GREEN, "oily", 5.0)

    # Default interactions: existing_condition + incoming_element = result
    add_interaction("wet", "ice", "frozen", 4.0, 0.0)
    add_interaction("wet", "fire", "", 0.0, 0.0)  # fire cancels wet
    add_interaction("oily", "fire", "burning", 5.0, 10.0)
    add_interaction("chilled", "fire", "", 0.0, 0.0)  # fire cancels chill
    add_interaction("burning", "water", "", 0.0, 0.0)  # water cancels burning

func add_element(name: String, color: Color, applies_condition: String, condition_duration: float) -> void:
    elements[name] = {
        "name": name,
        "color": color,
        "applies_condition": applies_condition,
        "condition_duration": condition_duration,
    }

func get_element(name: String) -> Dictionary:
    return elements.get(name, {}) if elements.has(name) else {}

func has_element(name: String) -> bool:
    return elements.has(name)

func add_interaction(existing_condition: String, incoming_element: String, result_condition: String, duration: float, damage_per_tick: float) -> void:
    var key = "%s+%s" % [existing_condition, incoming_element]
    interactions[key] = {
        "result_condition": result_condition,
        "duration": duration,
        "damage_per_tick": damage_per_tick,
    }

func get_interaction(existing_condition: String, incoming_element: String) -> Dictionary:
    var key = "%s+%s" % [existing_condition, incoming_element]
    return interactions.get(key, {}) if interactions.has(key) else {}

func get_element_null(name: String):
    if elements.has(name):
        return elements[name]
    return null

func get_interaction_null(existing_condition: String, incoming_element: String):
    var key = "%s+%s" % [existing_condition, incoming_element]
    if interactions.has(key):
        return interactions[key]
    return null
```

Note: The test uses `assert_not_null` and expects null returns. Since GDScript Dictionaries are truthy even when empty, the registry uses separate `get_element_null`/`get_interaction_null` methods returning actual null. Update tests to match:

Actually, simpler approach — make `get_element` and `get_interaction` return `Variant` (nullable):
Replace the get methods:
```gdscript
func get_element(name: String):
    if elements.has(name):
        return elements[name]
    return null

func get_interaction(existing_condition: String, incoming_element: String):
    var key = "%s+%s" % [existing_condition, incoming_element]
    if interactions.has(key):
        return interactions[key]
    return null
```

Remove the `get_element_null` and `get_interaction_null` duplicates.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
godot --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_element_registry
```
Expected: All pass.

- [ ] **Step 5: Register as autoload**

Add to `project.godot` `[autoload]`:
```ini
Elements="*res://src/config/element_registry.gd"
```

- [ ] **Step 6: Commit**

```bash
git add src/config/element_registry.gd test/unit/test_element_registry.gd project.godot
git commit -m "feat: add ElementRegistry with configurable elements and interactions"
```

---

### Task 2: Conditions Component and System

**Files:**
- Create: `src/components/c_conditions.gd`
- Create: `src/systems/s_conditions.gd`
- Create: `test/unit/test_conditions.gd`

- [ ] **Step 1: Write failing tests**

Create `test/unit/test_conditions.gd`:
```gdscript
extends GutTest

func test_conditions_component_starts_empty():
    var c = C_Conditions.new()
    assert_eq(c.active.size(), 0)

func test_add_condition():
    var c = C_Conditions.new()
    c.add_condition("wet", 5.0)
    assert_eq(c.active.size(), 1)
    assert_true(c.has_condition("wet"))

func test_condition_has_duration():
    var c = C_Conditions.new()
    c.add_condition("burning", 3.0)
    var cond = c.get_condition("burning")
    assert_almost_eq(cond.remaining, 3.0, 0.01)

func test_remove_condition():
    var c = C_Conditions.new()
    c.add_condition("wet", 5.0)
    c.remove_condition("wet")
    assert_false(c.has_condition("wet"))

func test_tick_reduces_duration():
    var c = C_Conditions.new()
    c.add_condition("wet", 5.0)
    c.tick(1.0)
    var cond = c.get_condition("wet")
    assert_almost_eq(cond.remaining, 4.0, 0.01)

func test_expired_condition_removed_on_tick():
    var c = C_Conditions.new()
    c.add_condition("wet", 1.0)
    c.tick(2.0)
    assert_false(c.has_condition("wet"))

func test_stacking_reset():
    var c = C_Conditions.new()
    c.add_condition("burning", 3.0)
    c.add_condition("burning", 3.0, "reset")
    assert_almost_eq(c.get_condition("burning").remaining, 3.0, 0.01)

func test_stacking_extend():
    var c = C_Conditions.new()
    c.add_condition("burning", 3.0)
    c.add_condition("burning", 3.0, "extend")
    assert_almost_eq(c.get_condition("burning").remaining, 6.0, 0.01)
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement C_Conditions**

Create `src/components/c_conditions.gd`:
```gdscript
class_name C_Conditions
extends Component

# Array of { name: String, remaining: float, damage_per_tick: float }
@export var active: Array[Dictionary] = []

func add_condition(name: String, duration: float, stacking: String = "reset", damage_per_tick: float = 0.0) -> void:
    for i in range(active.size()):
        if active[i].name == name:
            match stacking:
                "reset":
                    active[i].remaining = duration
                "extend":
                    active[i].remaining += duration
                "intensify":
                    active[i].remaining = duration
                    active[i].damage_per_tick += damage_per_tick
            return
    active.append({
        "name": name,
        "remaining": duration,
        "damage_per_tick": damage_per_tick,
    })

func has_condition(name: String) -> bool:
    for cond in active:
        if cond.name == name:
            return true
    return false

func get_condition(name: String) -> Dictionary:
    for cond in active:
        if cond.name == name:
            return cond
    return {}

func remove_condition(name: String) -> void:
    for i in range(active.size() - 1, -1, -1):
        if active[i].name == name:
            active.remove_at(i)
            return

func tick(delta: float) -> Array[String]:
    var expired: Array[String] = []
    for i in range(active.size() - 1, -1, -1):
        active[i].remaining -= delta
        if active[i].remaining <= 0:
            expired.append(active[i].name)
            active.remove_at(i)
    return expired
```

- [ ] **Step 4: Implement S_Conditions**

Create `src/systems/s_conditions.gd`:
```gdscript
class_name S_Conditions
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Conditions, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var conditions := entity.get_component(C_Conditions) as C_Conditions
        var health := entity.get_component(C_Health) as C_Health

        # Apply damage-over-time from conditions
        for cond in conditions.active:
            if cond.damage_per_tick > 0:
                health.current_health -= int(cond.damage_per_tick * delta)

        # Tick durations and remove expired
        conditions.tick(delta)

        # Clamp health
        health.current_health = maxi(health.current_health, 0)
```

- [ ] **Step 5: Run tests to verify they pass**

- [ ] **Step 6: Commit**

```bash
git add src/components/c_conditions.gd src/systems/s_conditions.gd test/unit/test_conditions.gd
git commit -m "feat: add conditions component and system with stacking/duration"
```

---

### Task 3: Actor Tag and Damage Components

**Files:**
- Create: `src/components/c_actor_tag.gd`
- Create: `src/components/c_damage_dealer.gd`
- Create: `src/components/c_lifetime.gd`

- [ ] **Step 1: Create components**

Create `src/components/c_actor_tag.gd`:
```gdscript
class_name C_ActorTag
extends Component

enum ActorType { PLAYER, MONSTER, NEUTRAL }

@export var actor_type: ActorType = ActorType.NEUTRAL
@export var team: int = 0  # 0 = players, 1 = monsters
```

Create `src/components/c_damage_dealer.gd`:
```gdscript
class_name C_DamageDealer
extends Component

@export var damage: int = 10
@export var element: String = ""  # empty = non-elemental
@export var owner_entity_id: int = -1  # prevent self-damage
@export var hit_actors: Array[int] = []  # track already-hit actors to prevent multi-hit
```

Create `src/components/c_lifetime.gd`:
```gdscript
class_name C_Lifetime
extends Component

@export var remaining: float = 5.0
```

- [ ] **Step 2: Commit**

```bash
git add src/components/c_actor_tag.gd src/components/c_damage_dealer.gd src/components/c_lifetime.gd
git commit -m "feat: add actor tag, damage dealer, and lifetime components"
```

---

### Task 4: Weapon Component and System

**Files:**
- Create: `src/components/c_weapon.gd`
- Create: `src/systems/s_weapon.gd`

- [ ] **Step 1: Create weapon component**

Create `src/components/c_weapon.gd`:
```gdscript
class_name C_Weapon
extends Component

@export var damage: int = 10
@export var fire_rate: float = 0.3  # seconds between shots
@export var projectile_speed: float = 30.0
@export var element: String = ""  # element applied by this weapon
@export var range: float = 50.0
@export var cooldown_remaining: float = 0.0
@export var is_firing: bool = false
```

- [ ] **Step 2: Create weapon system**

Create `src/systems/s_weapon.gd`:
```gdscript
class_name S_Weapon
extends System

signal projectile_requested(owner_body: Node3D, weapon: C_Weapon)

func query() -> QueryBuilder:
    return q.with_all([C_Weapon, C_NetworkIdentity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var weapon := entity.get_component(C_Weapon) as C_Weapon
        var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity

        # Tick cooldown
        if weapon.cooldown_remaining > 0:
            weapon.cooldown_remaining -= delta

        # Fire if requested and ready
        if weapon.is_firing and weapon.cooldown_remaining <= 0 and net_id.is_local:
            weapon.cooldown_remaining = weapon.fire_rate
            var body = entity.get_parent()
            if body:
                projectile_requested.emit(body, weapon)
```

- [ ] **Step 3: Commit**

```bash
git add src/components/c_weapon.gd src/systems/s_weapon.gd
git commit -m "feat: add weapon component and firing system"
```

---

### Task 5: Projectile Entity and System

**Files:**
- Create: `src/components/c_projectile.gd`
- Create: `src/entities/projectile.gd`
- Create: `src/entities/projectile.tscn`
- Create: `src/systems/s_projectile.gd`
- Create: `src/systems/s_lifetime.gd`

- [ ] **Step 1: Create projectile component**

Create `src/components/c_projectile.gd`:
```gdscript
class_name C_Projectile
extends Component

@export var speed: float = 30.0
@export var direction: Vector3 = Vector3.FORWARD
@export var element: String = ""
@export var damage: int = 10
@export var owner_id: int = -1
```

- [ ] **Step 2: Create projectile script**

Create `src/entities/projectile.gd`:
```gdscript
class_name ProjectileEntity
extends Area3D

var ecs_entity: Entity

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    ecs_entity.add_component(C_Projectile.new())
    ecs_entity.add_component(C_DamageDealer.new())
    ecs_entity.add_component(C_Lifetime.new())

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    body_entered.connect(_on_body_entered)

func setup(dir: Vector3, spd: float, dmg: int, elem: String, owner_id: int) -> void:
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    proj.direction = dir
    proj.speed = spd
    proj.element = elem
    proj.damage = dmg
    proj.owner_id = owner_id

    var dd := ecs_entity.get_component(C_DamageDealer) as C_DamageDealer
    dd.damage = dmg
    dd.element = elem
    dd.owner_entity_id = owner_id

func _physics_process(delta: float) -> void:
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    position += proj.direction * proj.speed * delta

func _on_body_entered(body: Node) -> void:
    if body is CharacterBody3D:
        # Damage is handled by the damage system via area overlap detection
        pass
    # Destroy on any collision (wall or actor)
    queue_free()
```

- [ ] **Step 3: Create projectile scene**

Create `src/entities/projectile.tscn`:
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/entities/projectile.gd" id="1"]

[sub_resource type="SphereMesh" id="SphereMesh_1"]
radius = 0.1
height = 0.2

[sub_resource type="SphereShape3D" id="SphereShape3D_1"]
radius = 0.1

[node name="Projectile" type="Area3D"]
script = ExtResource("1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
mesh = SubResource("SphereMesh_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("SphereShape3D_1")
```

- [ ] **Step 4: Create lifetime system**

Create `src/systems/s_lifetime.gd`:
```gdscript
class_name S_Lifetime
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Lifetime])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var lt := entity.get_component(C_Lifetime) as C_Lifetime
        lt.remaining -= delta
        if lt.remaining <= 0:
            var parent = entity.get_parent()
            if parent:
                parent.queue_free()
            else:
                entity.queue_free()
```

- [ ] **Step 5: Create projectile movement system**

Create `src/systems/s_projectile.gd`:
```gdscript
class_name S_Projectile
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Projectile])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var proj := entity.get_component(C_Projectile) as C_Projectile
        var parent = entity.get_parent()
        if parent is Node3D:
            parent.position += proj.direction * proj.speed * delta
```

Note: Projectile movement is handled both by `ProjectileEntity._physics_process` and potentially by S_Projectile. For now, let the entity script handle it directly since it has the Area3D collision detection. The S_Projectile system is reserved for future ECS-only projectiles. The entity's `_physics_process` can be removed later if we move to pure ECS projectiles.

- [ ] **Step 6: Commit**

```bash
git add src/components/c_projectile.gd src/entities/projectile.gd src/entities/projectile.tscn src/systems/s_projectile.gd src/systems/s_lifetime.gd
git commit -m "feat: add projectile entity, lifetime system, and projectile system"
```

---

### Task 6: Damage System

**Files:**
- Create: `src/systems/s_damage.gd`
- Create: `test/unit/test_damage.gd`

- [ ] **Step 1: Write failing tests**

Create `test/unit/test_damage.gd`:
```gdscript
extends GutTest

func test_damage_reduces_health():
    var health = C_Health.new()
    health.current_health = 100
    health.current_health -= 25
    assert_eq(health.current_health, 75)

func test_health_does_not_go_below_zero():
    var health = C_Health.new()
    health.current_health = 10
    health.current_health -= 25
    health.current_health = maxi(health.current_health, 0)
    assert_eq(health.current_health, 0)

func test_element_applies_condition():
    var conditions = C_Conditions.new()
    var registry = ElementRegistry.new()
    registry._setup_defaults()
    var elem = registry.get_element("fire")
    if elem and elem.applies_condition != "":
        conditions.add_condition(elem.applies_condition, elem.condition_duration)
    assert_true(conditions.has_condition("burning"))

func test_element_interaction_creates_new_condition():
    var conditions = C_Conditions.new()
    var registry = ElementRegistry.new()
    registry._setup_defaults()
    # Actor is wet, gets hit by ice
    conditions.add_condition("wet", 5.0)
    var interaction = registry.get_interaction("wet", "ice")
    if interaction and interaction.result_condition != "":
        conditions.remove_condition("wet")
        conditions.add_condition(interaction.result_condition, interaction.duration)
    assert_true(conditions.has_condition("frozen"))
    assert_false(conditions.has_condition("wet"))
```

- [ ] **Step 2: Implement damage system**

Create `src/systems/s_damage.gd`:
```gdscript
class_name S_Damage
extends System

## Processes damage when a projectile hits an actor.
## Called from projectile collision, not from ECS query.
## This system provides static helper methods for applying damage.

func query() -> QueryBuilder:
    # This system doesn't iterate — it's called on-demand from collision handlers
    return q.with_all([C_Health, C_Conditions])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    # No-op: damage is applied via apply_damage() called from collision
    pass

static func apply_damage(target_entity: Entity, damage: int, element: String) -> void:
    var health := target_entity.get_component(C_Health) as C_Health
    if not health:
        return

    # Apply raw damage
    health.current_health -= damage
    health.current_health = maxi(health.current_health, 0)

    # Apply elemental condition
    if element != "" and Elements:
        var elem = Elements.get_element(element)
        if elem and elem.applies_condition != "":
            var conditions := target_entity.get_component(C_Conditions) as C_Conditions
            if conditions:
                _apply_element_to_conditions(conditions, element, elem)

static func _apply_element_to_conditions(conditions: C_Conditions, element: String, elem_data: Dictionary) -> void:
    # Check for interactions with existing conditions
    for cond in conditions.active.duplicate():
        var interaction = Elements.get_interaction(cond.name, element)
        if interaction:
            conditions.remove_condition(cond.name)
            if interaction.result_condition != "":
                conditions.add_condition(
                    interaction.result_condition,
                    interaction.duration,
                    Elements.stacking_mode,
                    interaction.damage_per_tick
                )
            return  # interaction consumed the element

    # No interaction — apply base condition
    conditions.add_condition(
        elem_data.applies_condition,
        elem_data.condition_duration,
        Elements.stacking_mode
    )
```

- [ ] **Step 3: Run tests**

- [ ] **Step 4: Commit**

```bash
git add src/systems/s_damage.gd test/unit/test_damage.gd
git commit -m "feat: add damage system with elemental condition application"
```

---

### Task 7: Death System

**Files:**
- Create: `src/systems/s_death.gd`

- [ ] **Step 1: Create death system**

Create `src/systems/s_death.gd`:
```gdscript
class_name S_Death
extends System

signal actor_died(entity: Entity)

func query() -> QueryBuilder:
    return q.with_all([C_Health])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    for entity in entities:
        var health := entity.get_component(C_Health) as C_Health
        if health.current_health <= 0:
            actor_died.emit(entity)
            var parent = entity.get_parent()
            if parent:
                parent.queue_free()
```

- [ ] **Step 2: Commit**

```bash
git add src/systems/s_death.gd
git commit -m "feat: add death system — removes actors at zero health"
```

---

### Task 8: Monster Entity

**Files:**
- Create: `src/components/c_monster_ai.gd`
- Create: `src/entities/monster.gd`
- Create: `src/entities/monster.tscn`

- [ ] **Step 1: Create monster AI component**

Create `src/components/c_monster_ai.gd`:
```gdscript
class_name C_MonsterAI
extends Component

enum AIState { IDLE, CHASE, ATTACK }

@export var state: AIState = AIState.IDLE
@export var detection_range: float = 15.0
@export var attack_range: float = 2.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var attack_element: String = ""
@export var move_speed: float = 3.0
@export var cooldown_remaining: float = 0.0
```

- [ ] **Step 2: Create monster script**

Create `src/entities/monster.gd`:
```gdscript
class_name MonsterEntity
extends CharacterBody3D

var ecs_entity: Entity

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    ecs_entity.add_component(C_Health.new())
    ecs_entity.add_component(C_Velocity.new())
    ecs_entity.add_component(C_Conditions.new())
    ecs_entity.add_component(C_MonsterAI.new())
    ecs_entity.add_component(C_ActorTag.new())

    var tag := ecs_entity.get_component(C_ActorTag) as C_ActorTag
    tag.actor_type = C_ActorTag.ActorType.MONSTER
    tag.team = 1

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

func get_component(component_class) -> Component:
    return ecs_entity.get_component(component_class)

func _physics_process(delta: float) -> void:
    var vel_comp := ecs_entity.get_component(C_Velocity) as C_Velocity

    # Apply gravity
    if not is_on_floor():
        velocity.y -= Config.gravity * delta

    # Apply horizontal movement from AI velocity
    velocity.x = vel_comp.direction.x * vel_comp.speed
    velocity.z = vel_comp.direction.z * vel_comp.speed

    move_and_slide()
```

- [ ] **Step 3: Create monster scene**

Create `src/entities/monster.tscn`:
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/entities/monster.gd" id="1"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_1"]
radius = 0.4
height = 1.6

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(0.8, 1.6, 0.8)

[node name="Monster" type="CharacterBody3D"]
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)
shape = SubResource("CapsuleShape3D_1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 0)
mesh = SubResource("BoxMesh_1")
```

- [ ] **Step 4: Commit**

```bash
git add src/components/c_monster_ai.gd src/entities/monster.gd src/entities/monster.tscn
git commit -m "feat: add monster entity with AI component and box mesh"
```

---

### Task 9: Monster AI System

**Files:**
- Create: `src/systems/s_monster_ai.gd`

- [ ] **Step 1: Create monster AI system**

Create `src/systems/s_monster_ai.gd`:
```gdscript
class_name S_MonsterAI
extends System

func query() -> QueryBuilder:
    return q.with_all([C_MonsterAI, C_Velocity, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    # Find all player positions
    var player_positions: Array[Vector3] = []
    for node in _get_players():
        player_positions.append(node.global_position)

    for entity in entities:
        var ai := entity.get_component(C_MonsterAI) as C_MonsterAI
        var vel := entity.get_component(C_Velocity) as C_Velocity
        var health := entity.get_component(C_Health) as C_Health

        if health.current_health <= 0:
            continue

        var body = entity.get_parent() as CharacterBody3D
        if not body:
            continue

        # Tick attack cooldown
        ai.cooldown_remaining = maxf(ai.cooldown_remaining - delta, 0)

        # Find nearest player
        var nearest_dist := INF
        var nearest_pos := Vector3.ZERO
        for pos in player_positions:
            var dist = body.global_position.distance_to(pos)
            if dist < nearest_dist:
                nearest_dist = dist
                nearest_pos = pos

        # State machine
        if nearest_dist > ai.detection_range:
            ai.state = C_MonsterAI.AIState.IDLE
            vel.direction = Vector3.ZERO
            vel.speed = 0.0
        elif nearest_dist > ai.attack_range:
            ai.state = C_MonsterAI.AIState.CHASE
            var dir = (nearest_pos - body.global_position).normalized()
            dir.y = 0
            vel.direction = dir
            vel.speed = ai.move_speed
            # Face movement direction
            if dir.length() > 0.1:
                body.look_at(body.global_position + dir, Vector3.UP)
        else:
            ai.state = C_MonsterAI.AIState.ATTACK
            vel.direction = Vector3.ZERO
            vel.speed = 0.0
            if ai.cooldown_remaining <= 0:
                ai.cooldown_remaining = ai.attack_cooldown
                _attack_nearest(entity, nearest_pos, ai)

func _get_players() -> Array[Node]:
    var players: Array[Node] = []
    for node in ECS.world.get_tree().get_nodes_in_group("") if false else []:
        pass
    # Simpler: find all PlayerEntity nodes in the scene
    var tree = ECS.world.get_tree()
    if tree:
        for node in tree.get_nodes_in_group("players"):
            players.append(node)
    return players

func _attack_nearest(monster_entity: Entity, target_pos: Vector3, ai: C_MonsterAI) -> void:
    # Find the nearest player entity and apply damage
    var body = monster_entity.get_parent() as CharacterBody3D
    if not body:
        return
    for player in _get_players():
        if player.global_position.distance_to(body.global_position) <= ai.attack_range + 0.5:
            if player is PlayerEntity:
                S_Damage.apply_damage(player.ecs_entity, ai.attack_damage, ai.attack_element)
                break
```

- [ ] **Step 2: Add player to "players" group**

Update `src/entities/player.gd` — in `_ready()`, after creating the ECS entity, add:
```gdscript
add_to_group("players")
```

- [ ] **Step 3: Commit**

```bash
git add src/systems/s_monster_ai.gd src/entities/player.gd
git commit -m "feat: add monster AI system with chase/attack state machine"
```

---

### Task 10: Wire Up Combat — Player Shooting and Weapon Input

**Files:**
- Modify: `src/entities/player.gd` (add weapon, conditions, actor tag, fire input)
- Modify: `src/systems/s_player_input.gd` (capture fire input)
- Modify: `src/levels/test_level.gd` (register new systems, spawn test monsters)
- Modify: `project.godot` (add "fire" input action)
- Modify: `src/ui/hud.gd` (show health from ECS)

- [ ] **Step 1: Add fire input to project.godot**

Add to `[input]` section — mouse left click (button_index 1):
```ini
fire={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":1,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
```

- [ ] **Step 2: Update player entity to include combat components**

In `src/entities/player.gd` `_ready()`, after existing component adds:
```gdscript
    ecs_entity.add_component(C_Conditions.new())
    ecs_entity.add_component(C_Weapon.new())
    ecs_entity.add_component(C_ActorTag.new())

    var tag := ecs_entity.get_component(C_ActorTag) as C_ActorTag
    tag.actor_type = C_ActorTag.ActorType.PLAYER
    tag.team = 0

    add_to_group("players")
```

- [ ] **Step 3: Update player input system to capture fire**

In `src/systems/s_player_input.gd`, add weapon query and fire handling. Update the query to include C_Weapon:
```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput, C_Velocity, C_NetworkIdentity, C_Weapon])
```

Add at end of the entity loop:
```gdscript
        # Fire weapon
        var weapon := entity.get_component(C_Weapon) as C_Weapon
        weapon.is_firing = Input.is_action_pressed("fire")
```

- [ ] **Step 4: Create projectile spawner in test_level.gd**

Update `src/levels/test_level.gd` to register all combat systems and handle projectile spawning:

```gdscript
extends Node3D

const HUDScene = preload("res://src/ui/hud.tscn")
const ProjectileScene = preload("res://src/entities/projectile.tscn")
const MonsterScene = preload("res://src/entities/monster.tscn")

var weapon_system: S_Weapon

func _ready():
    var world = World.new()
    world.name = "World"
    add_child(world)
    ECS.world = world

    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())
    ECS.world.add_system(S_Conditions.new())
    ECS.world.add_system(S_Lifetime.new())
    ECS.world.add_system(S_Death.new())
    ECS.world.add_system(S_MonsterAI.new())

    weapon_system = S_Weapon.new()
    weapon_system.projectile_requested.connect(_on_projectile_requested)
    ECS.world.add_system(weapon_system)

    var hud = HUDScene.instantiate()
    add_child(hud)

    # Spawn test monsters
    _spawn_test_monsters()

func _physics_process(delta: float) -> void:
    ECS.process(delta)

func _on_projectile_requested(owner_body: Node3D, weapon: C_Weapon) -> void:
    var projectile = ProjectileScene.instantiate()
    var camera = owner_body.get_node("Camera3D") as Camera3D
    var spawn_pos = camera.global_position + (-camera.global_transform.basis.z * 1.0)
    projectile.global_position = spawn_pos
    add_child(projectile)
    projectile.setup(
        -camera.global_transform.basis.z,
        weapon.projectile_speed,
        weapon.damage,
        weapon.element,
        owner_body.get_instance_id()
    )

func _spawn_test_monsters() -> void:
    for i in range(3):
        var monster = MonsterScene.instantiate()
        monster.position = Vector3(randf_range(-8, 8), 1, randf_range(-8, -3))
        add_child(monster)
```

- [ ] **Step 5: Update HUD to show health from ECS**

Update `src/ui/hud.gd`:
```gdscript
extends Control

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var peers_label: Label = $MarginContainer/VBoxContainer/PeersLabel

func _process(_delta: float) -> void:
    var peer_count = Net.peers.size() + 1
    peers_label.text = "Players: %d" % peer_count

    # Find local player health
    var players = get_tree().get_nodes_in_group("players")
    for player in players:
        if player is PlayerEntity:
            var health = player.get_component(C_Health)
            if health:
                health_label.text = "HP: %d/%d" % [health.current_health, health.max_health]
                break
```

- [ ] **Step 6: Update projectile collision to apply damage**

Update `src/entities/projectile.gd` `_on_body_entered`:
```gdscript
func _on_body_entered(body: Node) -> void:
    if body is CharacterBody3D and body.has_method("get_component"):
        var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
        if body.get_instance_id() != proj.owner_id:
            S_Damage.apply_damage(body.ecs_entity, proj.damage, proj.element)
    queue_free()
```

- [ ] **Step 7: Commit**

```bash
git add src/ project.godot
git commit -m "feat: wire up combat — player shooting, monster spawning, damage, HUD health"
```

---

### Task 11: Add Elemental Weapon Variety

**Files:**
- Modify: `src/config/game_config.gd` (add weapon presets)
- Modify: `src/entities/player.gd` (weapon switching)
- Modify: `project.godot` (number key inputs for weapon swap)

- [ ] **Step 1: Add weapon switch inputs**

Add to `project.godot` `[input]` — keys 1-4 for weapon selection:
```ini
weapon_1={...keycode:49...}
weapon_2={...keycode:50...}
weapon_3={...keycode:51...}
weapon_4={...keycode:52...}
```

- [ ] **Step 2: Add weapon presets to GameConfig**

Add to `src/config/game_config.gd`:
```gdscript
# Weapon presets
var weapon_presets: Array[Dictionary] = [
    {"name": "Pistol", "damage": 10, "fire_rate": 0.3, "speed": 40.0, "element": ""},
    {"name": "Flamethrower", "damage": 5, "fire_rate": 0.1, "speed": 25.0, "element": "fire"},
    {"name": "Ice Rifle", "damage": 15, "fire_rate": 0.8, "speed": 35.0, "element": "ice"},
    {"name": "Water Gun", "damage": 3, "fire_rate": 0.05, "speed": 30.0, "element": "water"},
]
```

- [ ] **Step 3: Add weapon switching to player**

In `src/entities/player.gd`, add to `_input`:
```gdscript
    for i in range(Config.weapon_presets.size()):
        if event.is_action_pressed("weapon_%d" % (i + 1)):
            _equip_weapon(i)

func _equip_weapon(index: int) -> void:
    if index >= Config.weapon_presets.size():
        return
    var preset = Config.weapon_presets[index]
    var weapon := get_component(C_Weapon) as C_Weapon
    weapon.damage = preset.damage
    weapon.fire_rate = preset.fire_rate
    weapon.projectile_speed = preset.speed
    weapon.element = preset.element
    weapon.cooldown_remaining = 0.0
```

- [ ] **Step 4: Update HUD to show current weapon**

Add a weapon label to HUD showing current weapon name/element.

- [ ] **Step 5: Commit**

```bash
git add src/ project.godot
git commit -m "feat: add weapon presets with elemental variety and weapon switching"
```

---

## Summary

After completing all 11 tasks, you will have:
- **Element Registry** — configurable elements (fire, ice, water, oil) with interaction rules
- **Condition System** — status effects with duration, stacking modes, damage-over-time
- **Elemental Interactions** — wet+ice=frozen, oily+fire=burning, etc.
- **Weapons** — 4 weapon presets with different elements, switchable with number keys
- **Projectiles** — physics-based projectiles that deal damage and apply elements
- **Damage System** — applies damage, elemental conditions, and handles interactions
- **Death System** — removes actors at zero health
- **Monsters** — basic enemy with chase/attack AI, takes damage, dies
- **HUD** — shows health and weapon info
- Everything runtime-configurable via `Config`, `Elements` autoloads

**Next plan:** Plan 3 — Procedural Level Generation (WFC)
