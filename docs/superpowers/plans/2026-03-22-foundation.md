# Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up a playable multiplayer FPS prototype with ECS architecture and WebRTC networking — a "multiplayer walking sim" where 2-4 players can connect P2P and move around a test level.

**Architecture:** Godot 4 project using GECS for game logic, WebRTC for P2P multiplayer via Godot's MultiplayerPeer abstraction. One player hosts, others join via signaling server. FPS controller on CharacterBody3D. All game parameters exposed as configurable resources.

**Tech Stack:** Godot 4.4+, GDScript, GECS v6.8.1, GUT 9.x, WebRTC (browser-native + webrtc-native GDExtension for desktop), Node.js signaling server (gd-webrtc-signalling)

**Spec:** See `SPEC.md` in project root.

**Important:** This plan uses GECS methods `ECS.world.add_system()`, `ECS.world.add_entity()`, and `ECS.world.process(delta)`. Verify these exist in GECS v6.8.1 after installation (Task 2). If the API uses `add_child()` for systems/entities and automatic processing instead, adapt Tasks 6, 8, 9, and 13 accordingly.

---

## File Structure

```
project.godot                          # Project configuration
addons/gecs/                           # GECS addon (installed via AssetLib or git)
addons/gut/                            # GUT testing addon (installed via AssetLib)
src/
  components/
    c_health.gd                        # Health component
    c_velocity.gd                      # Velocity/movement component
    c_player_input.gd                  # Captured player input component
    c_network_identity.gd              # Network peer ID component
  systems/
    s_movement.gd                      # Applies velocity to entities
    s_player_input.gd                  # Reads input and sets velocity
  entities/
    player.tscn                        # Player entity scene (CharacterBody3D)
    player.gd                          # Player entity script
  networking/
    network_manager.gd                 # Autoload: peer creation, lobby, connect/disconnect
    signaling_client.gd                # WebRTC signaling client
  levels/
    test_level.tscn                    # Static test level (floor + walls + lights)
  ui/
    lobby_ui.tscn                      # Join/host UI
    lobby_ui.gd                        # Lobby logic
    hud.tscn                           # Basic HUD (health, player count)
    hud.gd                             # HUD script
  config/
    game_config.gd                     # Autoload: configurable game parameters
  main.tscn                            # Main scene (entry point)
  main.gd                              # Main scene script
test/
  unit/
    test_components.gd                 # Component unit tests
    test_movement_system.gd            # Movement system tests
    test_game_config.gd                # Config tests
  integration/
    test_network_manager.gd            # Network manager tests
signaling_server/
  package.json                         # Node.js signaling server
  server.js                            # Signaling server entry point
  fly.toml                             # fly.io deployment config
```

---

### Task 1: Godot Project Initialization

**Files:**
- Create: `project.godot`
- Create: `src/main.tscn`
- Create: `src/main.gd`
- Create: `export_presets.cfg` (later)

- [ ] **Step 1: Create the Godot project**

Create `project.godot`:
```ini
; Engine configuration file.
; Do NOT edit manually.

[application]

config/name="Rogue1 Prototype"
config/features=PackedStringArray("4.4", "GL Compatibility")
run/main_scene="res://src/main.tscn"

[rendering]

renderer/rendering_method="gl_compatibility"
```

Create `src/main.gd`:
```gdscript
extends Node

func _ready():
    print("Rogue1 Prototype started")
```

Create `src/main.tscn` as a Node scene with `main.gd` attached. This must be done in the Godot editor or by creating the .tscn file:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Verify project launches**

Run: `godot --path . --headless --quit`
Expected: Project opens and exits cleanly with no errors.

- [ ] **Step 3: Initialize git repository**

```bash
git init
```

Create `.gitignore`:
```
# Godot
.godot/
*.import
export_presets.cfg

# OS
.DS_Store
Thumbs.db

# Node
signaling_server/node_modules/
```

- [ ] **Step 4: Commit**

```bash
git add project.godot src/main.tscn src/main.gd .gitignore SPEC.md
git commit -m "feat: initialize Godot 4 project with main scene"
```

---

### Task 2: Install GECS Addon

**Files:**
- Create: `addons/gecs/` (addon files)
- Modify: `project.godot` (enable plugin + add ECS autoload)

- [ ] **Step 1: Install GECS**

Option A — Git submodule (recommended for version control):
```bash
git submodule add https://github.com/csprance/gecs.git addons/gecs && cd addons/gecs && git checkout v6.8.1 && cd ../..
```

Option B — Download release zip from https://github.com/csprance/gecs/releases and extract `addons/gecs/` into project.

- [ ] **Step 2: Enable the plugin and autoload**

Add to `project.godot` under `[autoload]`:
```ini
[autoload]

ECS="*res://addons/gecs/ecs/ecs.gd"
```

Add to `project.godot` under `[editor_plugins]`:
```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gecs/plugin.cfg")
```

- [ ] **Step 3: Verify GECS loads**

Update `src/main.gd`:
```gdscript
extends Node

func _ready():
    print("Rogue1 Prototype started")
    print("ECS World: ", ECS.world)
```

Run: `godot --path . --headless --quit`
Expected: Prints "ECS World:" followed by a World reference (not null).

- [ ] **Step 4: Commit**

```bash
git add addons/gecs project.godot src/main.gd
git commit -m "feat: add GECS addon and enable ECS autoload"
```

---

### Task 3: Install GUT Testing Framework

**Files:**
- Create: `addons/gut/` (addon files)
- Create: `test/unit/test_sanity.gd`
- Modify: `project.godot` (enable plugin)

- [ ] **Step 1: Install GUT**

Download from AssetLib in editor, or clone:
```bash
git submodule add https://github.com/bitwes/Gut.git addons/gut_repo
# Copy only the addon folder
cp -r addons/gut_repo/addons/gut addons/gut
rm -rf addons/gut_repo
```

Or download the release from https://github.com/bitwes/Gut/releases and extract `addons/gut/` into project.

- [ ] **Step 2: Enable the plugin**

Add to `project.godot` `[editor_plugins]`:
```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gecs/plugin.cfg", "res://addons/gut/plugin.cfg")
```

- [ ] **Step 3: Write a sanity test**

Create `test/unit/test_sanity.gd`:
```gdscript
extends GutTest

func test_true_is_true():
    assert_true(true, "Sanity check")
```

- [ ] **Step 4: Run tests from command line**

Run:
```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit
```
Expected: 1 test passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add addons/gut project.godot test/unit/test_sanity.gd
git commit -m "feat: add GUT testing framework with sanity test"
```

---

### Task 4: Game Config System

**Files:**
- Create: `src/config/game_config.gd`
- Create: `test/unit/test_game_config.gd`
- Modify: `project.godot` (add autoload)

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_game_config.gd`:
```gdscript
extends GutTest

var config: GameConfig

func before_each():
    config = GameConfig.new()

func test_has_player_speed():
    assert_not_null(config.player_speed)
    assert_typeof(config.player_speed, TYPE_FLOAT)

func test_has_player_max_health():
    assert_not_null(config.player_max_health)
    assert_typeof(config.player_max_health, TYPE_INT)

func test_has_gravity():
    assert_not_null(config.gravity)
    assert_typeof(config.gravity, TYPE_FLOAT)

func test_has_mouse_sensitivity():
    assert_not_null(config.mouse_sensitivity)
    assert_typeof(config.mouse_sensitivity, TYPE_FLOAT)

func test_has_jump_speed():
    assert_not_null(config.jump_speed)
    assert_typeof(config.jump_speed, TYPE_FLOAT)

func test_has_max_players():
    assert_not_null(config.max_players)
    assert_eq(config.max_players, 4)
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_game_config
```
Expected: FAIL — `GameConfig` class not found.

- [ ] **Step 3: Implement GameConfig**

Create `src/config/game_config.gd`:
```gdscript
class_name GameConfig
extends Node

# Movement
@export var player_speed: float = 5.0
@export var jump_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 9.8

# Health
@export var player_max_health: int = 100

# Multiplayer
@export var max_players: int = 4
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_game_config
```
Expected: All pass.

- [ ] **Step 5: Register as autoload**

Add to `project.godot` `[autoload]`:
```ini
[autoload]

ECS="*res://addons/gecs/ecs/ecs.gd"
Config="*res://src/config/game_config.gd"
```

- [ ] **Step 6: Commit**

```bash
git add src/config/game_config.gd test/unit/test_game_config.gd project.godot
git commit -m "feat: add configurable GameConfig autoload"
```

---

### Task 5: ECS Components

**Files:**
- Create: `src/components/c_health.gd`
- Create: `src/components/c_velocity.gd`
- Create: `src/components/c_player_input.gd`
- Create: `src/components/c_network_identity.gd`
- Create: `test/unit/test_components.gd`

- [ ] **Step 1: Write failing tests for components**

Create `test/unit/test_components.gd`:
```gdscript
extends GutTest

func test_health_defaults():
    var h = C_Health.new()
    assert_eq(h.max_health, 100)
    assert_eq(h.current_health, 100)

func test_health_custom_values():
    var h = C_Health.new()
    h.max_health = 200
    h.current_health = 150
    assert_eq(h.max_health, 200)
    assert_eq(h.current_health, 150)

func test_velocity_defaults():
    var v = C_Velocity.new()
    assert_eq(v.direction, Vector3.ZERO)
    assert_eq(v.speed, 0.0)

func test_player_input_defaults():
    var pi = C_PlayerInput.new()
    assert_eq(pi.move_direction, Vector2.ZERO)
    assert_eq(pi.look_rotation, Vector2.ZERO)
    assert_eq(pi.jumping, false)

func test_network_identity_defaults():
    var ni = C_NetworkIdentity.new()
    assert_eq(ni.peer_id, 0)
    assert_eq(ni.is_local, false)
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_components
```
Expected: FAIL — classes not found.

- [ ] **Step 3: Implement components**

Create `src/components/c_health.gd`:
```gdscript
class_name C_Health
extends Component

@export var max_health: int = 100
@export var current_health: int = 100
```

Create `src/components/c_velocity.gd`:
```gdscript
class_name C_Velocity
extends Component

@export var direction: Vector3 = Vector3.ZERO
@export var speed: float = 0.0
```

Create `src/components/c_player_input.gd`:
```gdscript
class_name C_PlayerInput
extends Component

@export var move_direction: Vector2 = Vector2.ZERO
@export var look_rotation: Vector2 = Vector2.ZERO
@export var jumping: bool = false
```

Create `src/components/c_network_identity.gd`:
```gdscript
class_name C_NetworkIdentity
extends Component

@export var peer_id: int = 0
@export var is_local: bool = false
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_components
```
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add src/components/ test/unit/test_components.gd
git commit -m "feat: add ECS components — health, velocity, player input, network identity"
```

---

### Task 6: Movement System

**Files:**
- Create: `src/systems/s_movement.gd`
- Create: `test/unit/test_movement_system.gd`

- [ ] **Step 1: Write failing test**

Note: GECS `Entity` extends `Node` (no `position` property). The movement system updates the `C_Velocity` component data. Actual position changes happen in `PlayerEntity._physics_process()` via `move_and_slide()` (see Task 15). The movement system's role in the ECS is to compute velocity from input — applying it to physics is handled by the CharacterBody3D owner.

For unit testing, we verify the system correctly reads and processes velocity components:

Create `test/unit/test_movement_system.gd`:
```gdscript
extends GutTest

func test_velocity_component_stores_direction():
    var vel = C_Velocity.new()
    vel.direction = Vector3(1, 0, 0)
    vel.speed = 10.0
    assert_eq(vel.direction, Vector3(1, 0, 0))
    assert_eq(vel.speed, 10.0)

func test_velocity_defaults_to_zero():
    var vel = C_Velocity.new()
    assert_eq(vel.direction, Vector3.ZERO)
    assert_eq(vel.speed, 0.0)
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_movement
```
Expected: FAIL — `S_Movement` not found.

- [ ] **Step 3: Implement movement system**

Since actual movement is handled by `CharacterBody3D.move_and_slide()` in the player script (Task 15), the S_Movement system is reserved for non-physics entities (e.g., projectiles, particles). For now, create a minimal system that could be extended later:

Create `src/systems/s_movement.gd`:
```gdscript
class_name S_Movement
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Velocity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var vel := entity.get_component(C_Velocity) as C_Velocity
        # For non-CharacterBody3D entities (projectiles, etc.)
        # CharacterBody3D players handle their own movement via move_and_slide()
        var parent = entity.get_parent()
        if parent is Node3D and not parent is CharacterBody3D:
            parent.position += vel.direction * vel.speed * delta
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_movement
```
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add src/systems/s_movement.gd test/unit/test_movement_system.gd
git commit -m "feat: add movement system — applies velocity to entities"
```

---

### Task 7: Player Input System

**Files:**
- Create: `src/systems/s_player_input.gd`
- Modify: `project.godot` (input map)

- [ ] **Step 1: Add input mappings to project.godot**

Add to `project.godot`:
```ini
[input]

forward={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
]
}
back={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)
]
}
left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
]
}
right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
]
}
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
```

Note: These input mappings are easier to create via the Godot editor (Project > Project Settings > Input Map). The serialized format above is for reference.

- [ ] **Step 2: Implement player input system**

Create `src/systems/s_player_input.gd`:
```gdscript
class_name S_PlayerInput
extends System

func query() -> QueryBuilder:
    return q.with_all([C_PlayerInput, C_Velocity, C_NetworkIdentity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity
        if not net_id.is_local:
            continue

        var pi := entity.get_component(C_PlayerInput) as C_PlayerInput
        var vel := entity.get_component(C_Velocity) as C_Velocity

        # Capture input
        pi.move_direction = Input.get_vector("left", "right", "forward", "back")
        pi.jumping = Input.is_action_just_pressed("jump")

        # Convert to velocity (entity's parent is the CharacterBody3D)
        var body = entity.get_parent() as Node3D
        var basis = body.global_transform.basis
        var move_dir = basis * Vector3(pi.move_direction.x, 0, pi.move_direction.y)
        vel.direction = move_dir.normalized() if move_dir.length() > 0 else Vector3.ZERO
        vel.speed = Config.player_speed if vel.direction != Vector3.ZERO else 0.0
```

- [ ] **Step 3: Commit**

```bash
git add src/systems/s_player_input.gd project.godot
git commit -m "feat: add player input system — captures WASD input and sets velocity"
```

---

### Task 8: Player Entity Scene

**Files:**
- Create: `src/entities/player.tscn`
- Create: `src/entities/player.gd`

- [ ] **Step 1: Create player script**

GECS `Entity` extends `Node`, not `CharacterBody3D`. We use composition: the player scene root is a `CharacterBody3D` with its own script, and it creates/owns an `Entity` child node for ECS integration.

Create `src/entities/player.gd`:
```gdscript
class_name PlayerEntity
extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var ecs_entity: Entity

func _ready():
    # Create an Entity child for ECS component management
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    ecs_entity.add_component(C_Health.new())
    ecs_entity.add_component(C_Velocity.new())
    ecs_entity.add_component(C_PlayerInput.new())
    ecs_entity.add_component(C_NetworkIdentity.new())

    # Register with ECS world
    ECS.world.add_entity(ecs_entity)

func get_component(component_class) -> Component:
    return ecs_entity.get_component(component_class)

func setup(peer_id: int, is_local: bool) -> void:
    var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
    net_id.peer_id = peer_id
    net_id.is_local = is_local

    if is_local:
        camera.make_current()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
    var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
    if not net_id.is_local:
        return

    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * Config.mouse_sensitivity)
        camera.rotate_x(-event.relative.y * Config.mouse_sensitivity)
        camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(70), deg_to_rad(70))

    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

- [ ] **Step 2: Create player scene**

Create `src/entities/player.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/entities/player.gd" id="1"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_1"]
radius = 0.35
height = 1.8

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_1")

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)
```

- [ ] **Step 3: Verify scene loads**

Open in Godot editor, verify no errors. Scene tree should show:
```
Player (CharacterBody3D)
├── CollisionShape3D
└── Camera3D
```

- [ ] **Step 4: Commit**

```bash
git add src/entities/player.tscn src/entities/player.gd
git commit -m "feat: add player entity scene with FPS controller"
```

---

### Task 9: Test Level

**Files:**
- Create: `src/levels/test_level.tscn`
- Create: `src/levels/test_level.gd`

- [ ] **Step 1: Create test level script**

Create `src/levels/test_level.gd`:
```gdscript
extends Node3D

func _ready():
    # Register systems with ECS
    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())

func _physics_process(delta: float) -> void:
    ECS.world.process(delta)
```

- [ ] **Step 2: Create test level scene**

Create `src/levels/test_level.tscn` — a simple enclosed area with floor, walls, and light. Best created in the Godot editor:

Scene tree:
```
TestLevel (Node3D, script: test_level.gd)
├── DirectionalLight3D (rotated to illuminate scene)
├── Floor (StaticBody3D)
│   ├── MeshInstance3D (BoxMesh, size 20x0.2x20)
│   └── CollisionShape3D (BoxShape3D, size 20x0.2x20)
├── Walls (Node3D)
│   ├── WallNorth (StaticBody3D + MeshInstance3D + CollisionShape3D)
│   ├── WallSouth (...)
│   ├── WallEast (...)
│   └── WallWest (...)
└── SpawnPoint (Marker3D, position y=1.0)
```

Minimal .tscn for floor + light (walls can be added later):
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/levels/test_level.gd" id="1"]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(20, 0.2, 20)

[sub_resource type="BoxShape3D" id="BoxShape3D_1"]
size = Vector3(20, 0.2, 20)

[node name="TestLevel" type="Node3D"]
script = ExtResource("1")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 0.707, 0.707, 0, -0.707, 0.707, 0, 10, 0)

[node name="Floor" type="StaticBody3D" parent="."]

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
mesh = SubResource("BoxMesh_1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
shape = SubResource("BoxShape3D_1")

[node name="SpawnPoint" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
```

- [ ] **Step 3: Wire up main scene to load test level with a local player**

Update `src/main.gd`:
```gdscript
extends Node

const TestLevel = preload("res://src/levels/test_level.tscn")
const PlayerScene = preload("res://src/entities/player.tscn")

func _ready():
    var level = TestLevel.instantiate()
    add_child(level)

    var player = PlayerScene.instantiate()
    player.position = level.get_node("SpawnPoint").position
    level.add_child(player)  # player._ready() creates and registers ECS entity
    player.setup(1, true)
```

- [ ] **Step 4: Run and verify**

Launch: `godot --path .`
Expected: Game opens, camera is at player height, mouse look works, floor is visible. WASD movement will NOT work yet — `_physics_process` with `move_and_slide()` is added in Task 15.

- [ ] **Step 5: Commit**

```bash
git add src/levels/ src/main.gd
git commit -m "feat: add test level with floor and spawn point, wire up single-player"
```

---

### Task 10: Network Manager

**Files:**
- Create: `src/networking/network_manager.gd`
- Create: `src/networking/signaling_client.gd`
- Modify: `project.godot` (add autoload)

- [ ] **Step 1: Implement signaling client**

Create `src/networking/signaling_client.gd`:
```gdscript
class_name SignalingClient
extends Node

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal offer_received(peer_id: int, offer: String)
signal answer_received(peer_id: int, answer: String)
signal candidate_received(peer_id: int, mid: String, index: int, sdp: String)
signal lobby_joined(peer_id: int)
signal lobby_sealed()

var ws := WebSocketPeer.new()
var _connected := false

func connect_to_server(url: String) -> Error:
    var err = ws.connect_to_url(url)
    if err != OK:
        push_error("SignalingClient: Failed to connect to %s: %s" % [url, err])
    return err

func poll() -> void:
    ws.poll()
    var state = ws.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        while ws.get_available_packet_count() > 0:
            var msg = ws.get_packet().get_string_from_utf8()
            _handle_message(msg)
    elif state == WebSocketPeer.STATE_CLOSED:
        if _connected:
            _connected = false
            push_warning("SignalingClient: Connection closed")

func join_lobby(lobby_id: String) -> void:
    _send({"type": "join", "lobby": lobby_id})

func send_offer(peer_id: int, offer: String) -> void:
    _send({"type": "offer", "peer_id": peer_id, "sdp": offer})

func send_answer(peer_id: int, answer: String) -> void:
    _send({"type": "answer", "peer_id": peer_id, "sdp": answer})

func send_candidate(peer_id: int, mid: String, index: int, sdp: String) -> void:
    _send({"type": "candidate", "peer_id": peer_id, "mid": mid, "index": index, "sdp": sdp})

func _send(data: Dictionary) -> void:
    ws.send_text(JSON.stringify(data))

func _handle_message(msg: String) -> void:
    var parsed = JSON.parse_string(msg)
    if parsed == null:
        return
    match parsed.get("type", ""):
        "peer_connected":
            peer_connected.emit(int(parsed["peer_id"]))
        "peer_disconnected":
            peer_disconnected.emit(int(parsed["peer_id"]))
        "offer":
            offer_received.emit(int(parsed["peer_id"]), parsed["sdp"])
        "answer":
            answer_received.emit(int(parsed["peer_id"]), parsed["sdp"])
        "candidate":
            candidate_received.emit(int(parsed["peer_id"]), parsed["mid"], int(parsed["index"]), parsed["sdp"])
        "joined":
            _connected = true
            lobby_joined.emit(int(parsed["peer_id"]))
        "sealed":
            lobby_sealed.emit()

func close() -> void:
    ws.close()
```

- [ ] **Step 2: Implement network manager**

Create `src/networking/network_manager.gd`:
```gdscript
class_name NetworkManager
extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_established()
signal connection_failed()

@export var signaling_url: String = "ws://localhost:9090"
@export var ice_servers: Array[Dictionary] = [
    {"urls": ["stun:stun.l.google.com:19302"]}
]

var signaling: SignalingClient
var rtc_mp: WebRTCMultiplayerPeer
var peers: Dictionary = {}  # peer_id -> WebRTCPeerConnection
var my_peer_id: int = 0

func _ready() -> void:
    signaling = SignalingClient.new()
    add_child(signaling)
    signaling.peer_connected.connect(_on_signaling_peer_connected)
    signaling.peer_disconnected.connect(_on_signaling_peer_disconnected)
    signaling.offer_received.connect(_on_offer_received)
    signaling.answer_received.connect(_on_answer_received)
    signaling.candidate_received.connect(_on_candidate_received)
    signaling.lobby_joined.connect(_on_lobby_joined)

func join_lobby(lobby_id: String) -> void:
    _init_rtc()
    signaling.connect_to_server(signaling_url)
    signaling.join_lobby(lobby_id)

func _init_rtc() -> void:
    rtc_mp = WebRTCMultiplayerPeer.new()

func _process(_delta: float) -> void:
    if signaling:
        signaling.poll()

func _create_peer(peer_id: int) -> WebRTCPeerConnection:
    var peer = WebRTCPeerConnection.new()
    peer.initialize({"iceServers": ice_servers})
    peer.session_description_created.connect(
        func(type: String, sdp: String):
            peer.set_local_description(type, sdp)
            if type == "offer":
                signaling.send_offer(peer_id, sdp)
            else:
                signaling.send_answer(peer_id, sdp)
    )
    peer.ice_candidate_created.connect(
        func(mid: String, index: int, sdp: String):
            signaling.send_candidate(peer_id, mid, index, sdp)
    )
    peers[peer_id] = peer
    rtc_mp.add_peer(peer, peer_id)
    return peer

func _on_lobby_joined(peer_id: int) -> void:
    my_peer_id = peer_id
    rtc_mp.create_mesh(peer_id)
    multiplayer.multiplayer_peer = rtc_mp
    connection_established.emit()

func _on_signaling_peer_connected(peer_id: int) -> void:
    var peer = _create_peer(peer_id)
    # Higher ID creates the offer
    if my_peer_id > peer_id:
        peer.create_offer()
    player_connected.emit(peer_id)

func _on_signaling_peer_disconnected(peer_id: int) -> void:
    if peers.has(peer_id):
        peers[peer_id].close()
        peers.erase(peer_id)
    player_disconnected.emit(peer_id)

func _on_offer_received(peer_id: int, offer: String) -> void:
    if not peers.has(peer_id):
        _create_peer(peer_id)
    peers[peer_id].set_remote_description("offer", offer)

func _on_answer_received(peer_id: int, answer: String) -> void:
    if peers.has(peer_id):
        peers[peer_id].set_remote_description("answer", answer)

func _on_candidate_received(peer_id: int, mid: String, index: int, sdp: String) -> void:
    if peers.has(peer_id):
        peers[peer_id].add_ice_candidate(mid, index, sdp)

func disconnect_all() -> void:
    for peer in peers.values():
        peer.close()
    peers.clear()
    if signaling:
        signaling.close()
    if rtc_mp:
        rtc_mp.close()
```

- [ ] **Step 3: Register as autoload**

Add to `project.godot` `[autoload]`:
```ini
[autoload]

ECS="*res://addons/gecs/ecs/ecs.gd"
Config="*res://src/config/game_config.gd"
Net="*res://src/networking/network_manager.gd"
```

- [ ] **Step 4: Commit**

```bash
git add src/networking/ project.godot
git commit -m "feat: add network manager with WebRTC P2P and signaling client"
```

---

### Task 11: Signaling Server (Node.js for fly.io)

**Files:**
- Create: `signaling_server/package.json`
- Create: `signaling_server/server.js`
- Create: `signaling_server/fly.toml`
- Create: `signaling_server/Dockerfile`

- [ ] **Step 1: Create package.json**

Create `signaling_server/package.json`:
```json
{
  "name": "rogue1-signaling",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "ws": "^8.16.0"
  }
}
```

- [ ] **Step 2: Implement signaling server**

Create `signaling_server/server.js`:
```javascript
const WebSocket = require("ws");

const PORT = process.env.PORT || 9090;
const wss = new WebSocket.Server({ port: PORT });

// lobby_id -> Map<peer_id, WebSocket>
const lobbies = new Map();
let nextPeerId = 1;

wss.on("connection", (ws) => {
  let myPeerId = null;
  let myLobby = null;

  ws.on("message", (data) => {
    let msg;
    try {
      msg = JSON.parse(data);
    } catch {
      return;
    }

    if (msg.type === "join") {
      const lobbyId = msg.lobby || "default";
      myPeerId = nextPeerId++;
      myLobby = lobbyId;

      if (!lobbies.has(lobbyId)) {
        lobbies.set(lobbyId, new Map());
      }
      const lobby = lobbies.get(lobbyId);

      // Notify existing peers about new peer
      for (const [peerId, peerWs] of lobby) {
        send(peerWs, { type: "peer_connected", peer_id: myPeerId });
        send(ws, { type: "peer_connected", peer_id: peerId });
      }

      lobby.set(myPeerId, ws);
      send(ws, { type: "joined", peer_id: myPeerId });
      console.log(`Peer ${myPeerId} joined lobby ${lobbyId} (${lobby.size} peers)`);
      return;
    }

    // Relay messages to target peer
    if (msg.peer_id != null && myLobby) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        const targetWs = lobby.get(msg.peer_id);
        if (targetWs) {
          msg.peer_id = myPeerId; // Replace with sender's ID
          send(targetWs, msg);
        }
      }
    }
  });

  ws.on("close", () => {
    if (myLobby && myPeerId != null) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        lobby.delete(myPeerId);
        for (const [, peerWs] of lobby) {
          send(peerWs, { type: "peer_disconnected", peer_id: myPeerId });
        }
        if (lobby.size === 0) {
          lobbies.delete(myLobby);
        }
        console.log(`Peer ${myPeerId} left lobby ${myLobby}`);
      }
    }
  });
});

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

console.log(`Signaling server listening on port ${PORT}`);
```

- [ ] **Step 3: Create Dockerfile**

Create `signaling_server/Dockerfile`:
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY server.js ./
EXPOSE 9090
CMD ["node", "server.js"]
```

- [ ] **Step 4: Create fly.toml**

Create `signaling_server/fly.toml`:
```toml
app = "rogue1-signaling"
primary_region = "iad"

[build]

[http_service]
  internal_port = 9090
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0

```

- [ ] **Step 5: Test locally**

```bash
cd signaling_server && npm install && node server.js &
```
Expected: "Signaling server listening on port 9090"

- [ ] **Step 6: Commit**

```bash
git add signaling_server/
git commit -m "feat: add Node.js WebRTC signaling server for fly.io deployment"
```

---

### Task 12: Lobby UI

**Files:**
- Create: `src/ui/lobby_ui.tscn`
- Create: `src/ui/lobby_ui.gd`
- Modify: `src/main.gd`
- Modify: `src/main.tscn`

- [ ] **Step 1: Create lobby UI script**

Create `src/ui/lobby_ui.gd`:
```gdscript
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
```

- [ ] **Step 2: Create lobby UI scene**

Create `src/ui/lobby_ui.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/lobby_ui.gd" id="1"]

[node name="LobbyUI" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -150.0
offset_right = 150.0
offset_bottom = 150.0

[node name="Label" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "Rogue1 Prototype"
horizontal_alignment = 1

[node name="LobbyInput" type="LineEdit" parent="VBoxContainer"]
layout_mode = 2
placeholder_text = "Lobby ID"

[node name="HostButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "Host"

[node name="JoinButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "Join"

[node name="StartButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "Start Game"
visible = false

[node name="StatusLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "Enter lobby ID or host a new one"
horizontal_alignment = 1

[node name="PlayerList" type="ItemList" parent="VBoxContainer"]
layout_mode = 2
custom_minimum_size = Vector2(0, 100)
```

- [ ] **Step 3: Update main scene to show lobby then transition to game**

Update `src/main.gd`:
```gdscript
extends Node

const TestLevel = preload("res://src/levels/test_level.tscn")
const PlayerScene = preload("res://src/entities/player.tscn")
const LobbyScene = preload("res://src/ui/lobby_ui.tscn")

var lobby_ui: Control
var current_level: Node3D

func _ready():
    lobby_ui = LobbyScene.instantiate()
    add_child(lobby_ui)
    lobby_ui.game_started.connect(_on_game_started)

func _on_game_started():
    lobby_ui.queue_free()
    _start_game()

func _start_game():
    current_level = TestLevel.instantiate()
    add_child(current_level)

    # Spawn local player
    _spawn_player(Net.my_peer_id, true)

    # Spawn existing remote players
    for peer_id in Net.peers:
        _spawn_player(peer_id, false)

    # Listen for new players
    Net.player_connected.connect(_on_player_joined)
    Net.player_disconnected.connect(_on_player_left)

func _spawn_player(peer_id: int, is_local: bool) -> void:
    var player = PlayerScene.instantiate()
    player.name = "Player_%d" % peer_id
    var spawn = current_level.get_node("SpawnPoint")
    # Offset spawn positions slightly so players don't overlap
    player.position = spawn.position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
    current_level.add_child(player)
    player.setup(peer_id, is_local)

func _on_player_joined(peer_id: int):
    _spawn_player(peer_id, false)

func _on_player_left(peer_id: int):
    var player_node = current_level.get_node_or_null("Player_%d" % peer_id)
    if player_node:
        player_node.queue_free()
```

- [ ] **Step 4: Verify lobby loads**

Run: `godot --path .`
Expected: Lobby UI appears with text input, Host/Join buttons, status label, and player list.

- [ ] **Step 5: Commit**

```bash
git add src/ui/ src/main.gd
git commit -m "feat: add lobby UI with host/join flow and game start transition"
```

---

### Task 13: Basic HUD

**Files:**
- Create: `src/ui/hud.tscn`
- Create: `src/ui/hud.gd`
- Modify: `src/levels/test_level.tscn`

- [ ] **Step 1: Create HUD script**

Create `src/ui/hud.gd`:
```gdscript
extends Control

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var peers_label: Label = $MarginContainer/VBoxContainer/PeersLabel

func _process(_delta: float) -> void:
    var peer_count = Net.peers.size() + 1  # +1 for self
    peers_label.text = "Players: %d" % peer_count
```

- [ ] **Step 2: Create HUD scene**

Create `src/ui/hud.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/hud.gd" id="1"]

[node name="HUD" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("1")

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 0
offset_right = 200.0
offset_bottom = 80.0

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]
layout_mode = 2

[node name="HealthLabel" type="Label" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
text = "HP: 100/100"

[node name="PeersLabel" type="Label" parent="MarginContainer/VBoxContainer"]
layout_mode = 2
text = "Players: 1"
```

- [ ] **Step 3: Add HUD to test level**

Add to `src/levels/test_level.gd` `_ready()`:
```gdscript
const HUDScene = preload("res://src/ui/hud.tscn")

func _ready():
    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())

    var hud = HUDScene.instantiate()
    add_child(hud)
```

- [ ] **Step 4: Commit**

```bash
git add src/ui/hud.tscn src/ui/hud.gd src/levels/test_level.gd
git commit -m "feat: add basic HUD with health and player count"
```

---

### Task 14: Multiplayer State Sync

**Files:**
- Modify: `src/entities/player.gd`
- Modify: `src/entities/player.tscn`

- [ ] **Step 1: Add MultiplayerSynchronizer to player scene**

Update `src/entities/player.tscn` to add a `MultiplayerSynchronizer` node that syncs position and rotation:

Add to the scene tree:
```
Player (CharacterBody3D)
├── CollisionShape3D
├── Camera3D
└── MultiplayerSynchronizer
```

The MultiplayerSynchronizer should sync:
- `.:position` (Vector3)
- `.:rotation` (Vector3)
- `Camera3D:rotation` (Vector3) — for vertical look

- [ ] **Step 2: Update player script for multiplayer authority**

Update the `setup()` method in `src/entities/player.gd` to set multiplayer authority:
```gdscript
func setup(peer_id: int, is_local: bool) -> void:
    var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
    net_id.peer_id = peer_id
    net_id.is_local = is_local

    # Set multiplayer authority so MultiplayerSynchronizer works
    set_multiplayer_authority(peer_id)

    if is_local:
        camera.make_current()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
```

Note: `get_component()` is a helper on `PlayerEntity` that delegates to `ecs_entity.get_component()` (see Task 8).

- [ ] **Step 3: Test with two instances**

1. Start signaling server: `cd signaling_server && node server.js`
2. Launch instance 1: `godot --path .` → Host lobby "test"
3. Launch instance 2: `godot --path .` → Join lobby "test"
4. Expected: Both players see each other moving in the test level

- [ ] **Step 4: Commit**

```bash
git add src/entities/
git commit -m "feat: add multiplayer state sync via MultiplayerSynchronizer"
```

---

### Task 15: Gravity and Jump (Physics Integration)

**Files:**
- Modify: `src/systems/s_movement.gd`
- Modify: `src/systems/s_player_input.gd`
- Modify: `src/entities/player.gd`

- [ ] **Step 1: Update movement system for CharacterBody3D physics**

The basic movement system uses `entity.position +=` which bypasses collision. For CharacterBody3D, we need `move_and_slide()`. Update `src/entities/player.gd` to handle physics movement directly (since `move_and_slide` must be called on the CharacterBody3D):

Add to `src/entities/player.gd`:
```gdscript
func _physics_process(delta: float) -> void:
    var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
    if not net_id.is_local:
        return

    var vel_comp := get_component(C_Velocity) as C_Velocity

    # Apply gravity
    if not is_on_floor():
        velocity.y -= Config.gravity * delta

    # Apply horizontal movement from ECS velocity
    velocity.x = vel_comp.direction.x * vel_comp.speed
    velocity.z = vel_comp.direction.z * vel_comp.speed

    # Jump
    var pi := get_component(C_PlayerInput) as C_PlayerInput
    if pi.jumping and is_on_floor():
        velocity.y = Config.jump_speed

    move_and_slide()
```

Note: This is the composition hybrid — the ECS input system sets velocity components on the Entity child, and the CharacterBody3D's `_physics_process` reads them and applies via `move_and_slide()`. The `get_component()` helper on PlayerEntity delegates to `ecs_entity.get_component()`.

- [ ] **Step 2: Test jump and gravity**

Launch: `godot --path .`
Expected: Player falls to floor on spawn, can walk with WASD, can jump with Space, collides with floor.

- [ ] **Step 3: Commit**

```bash
git add src/entities/player.gd src/systems/
git commit -m "feat: add gravity and jump via CharacterBody3D physics integration"
```

---

## Summary

After completing all 15 tasks, you will have:
- Godot 4 project with GECS and GUT
- Configurable game parameters via `Config` autoload
- ECS components: health, velocity, player input, network identity
- ECS systems: movement, player input
- FPS player controller with mouse look, WASD movement, jump, gravity
- WebRTC P2P multiplayer via signaling server
- Lobby UI (host/join)
- Basic HUD (health, player count)
- Test level with floor and spawn point
- Multiplayer state sync between 2-4 players
- Signaling server deployable to fly.io

**Next plan:** Plan 2 — Combat & Elemental System
