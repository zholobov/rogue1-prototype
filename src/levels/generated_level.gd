extends Node3D

const HUDScene = preload("res://src/ui/hud.tscn")
const ProjectileScene = preload("res://src/entities/projectile.tscn")
const MonsterScene = preload("res://src/entities/monster.tscn")

var weapon_system: S_Weapon
var level_data: Dictionary = {}

func _ready():
    print("[GeneratedLevel] _ready() started")

    # Environment (so background isn't default grey)
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.05, 0.05, 0.1)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.3, 0.3, 0.35)
    env.ambient_light_energy = 0.5
    var world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    # Create and register the ECS world
    var world = World.new()
    world.name = "World"
    add_child(world)
    ECS.world = world
    print("[GeneratedLevel] ECS world created")

    # Register all systems
    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())
    ECS.world.add_system(S_Conditions.new())
    ECS.world.add_system(S_Lifetime.new())
    ECS.world.add_system(S_Death.new())
    ECS.world.add_system(S_MonsterAI.new())

    weapon_system = S_Weapon.new()
    weapon_system.projectile_requested.connect(_on_projectile_requested)
    ECS.world.add_system(weapon_system)
    print("[GeneratedLevel] Systems registered")

    # Generate level
    var gen = LevelGenerator.new()
    var seed_val = Config.level_seed if Config.level_seed != 0 else randi()
    level_data = gen.generate(Config.level_grid_width, Config.level_grid_height, seed_val, Config.level_tile_size)
    add_child(level_data.geometry)

    print("[GeneratedLevel] Level generated with seed: %d, spawn_points: %d" % [level_data.seed, level_data.spawn_points.size()])
    for i in range(level_data.spawn_points.size()):
        print("[GeneratedLevel]   spawn[%d] = %s" % [i, str(level_data.spawn_points[i])])

    # HUD
    var hud = HUDScene.instantiate()
    add_child(hud)

    # Spawn monsters at spawn points
    _spawn_monsters()
    print("[GeneratedLevel] _ready() completed")

func get_spawn_points() -> Array[Vector3]:
    var points: Array[Vector3] = []
    for child in _find_in_group(level_data.geometry, "spawn_point"):
        points.append(child.global_position)
    return points

func get_player_spawn() -> Vector3:
    var points = get_spawn_points()
    if points.size() > 0:
        return points[0]
    # Fallback to center of grid (avoids border walls)
    var cx = level_data.width * Config.level_tile_size / 2.0
    var cz = level_data.height * Config.level_tile_size / 2.0
    return Vector3(cx, 1.0, cz)

func _spawn_monsters() -> void:
    var spawn_points = get_spawn_points()
    # Skip the first spawn point (used for player)
    for i in range(1, spawn_points.size()):
        for _m in range(Config.monsters_per_room):
            var monster = MonsterScene.instantiate()
            var offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
            monster.position = spawn_points[i] + offset
            add_child(monster)

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

func _find_in_group(node: Node, group: String) -> Array[Node]:
    var found: Array[Node] = []
    for child in node.get_children():
        if child.is_in_group(group):
            found.append(child)
        found.append_array(_find_in_group(child, group))
    return found
