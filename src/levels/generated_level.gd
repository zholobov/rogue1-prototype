extends Node3D

const HUDScene = preload("res://src/ui/hud.tscn")
const ProjectileScene = preload("res://src/entities/projectile.tscn")
const MonsterScene = preload("res://src/entities/monster.tscn")

var weapon_system: S_Weapon
var level_data: Dictionary = {}
var monsters_remaining: int = 0
var death_system: S_Death

func _ready():
    print("[GeneratedLevel] _ready() started")

    # Neon dungeon environment
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.02, 0.02, 0.04)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.15, 0.15, 0.25)
    env.ambient_light_energy = 0.8
    # Depth fog (do NOT use volumetric — Forward+ only)
    env.fog_enabled = true
    env.fog_light_color = Color(0.02, 0.02, 0.06)
    env.fog_density = 0.02
    env.fog_depth_begin = 5.0
    env.fog_depth_end = 40.0
    env.fog_sky_affect = 0.0
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
    death_system = S_Death.new()
    death_system.actor_died.connect(_on_actor_died)
    ECS.world.add_system(death_system)
    ECS.world.add_system(S_HpRegen.new())
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
    if monsters_remaining <= 0:
        call_deferred("_auto_clear")
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
    monsters_remaining = 0
    var spawn_points = get_spawn_points()
    for i in range(1, spawn_points.size()):
        for _m in range(Config.monsters_per_room):
            if Config.max_monsters_per_level > 0 and monsters_remaining >= Config.max_monsters_per_level:
                break
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

func _auto_clear() -> void:
    print("[GeneratedLevel] No monsters — auto-clearing level")
    if RunManager:
        RunManager.on_level_cleared()

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

    # Muzzle flash
    var flash = VfxFactory.create_muzzle_flash(spawn_pos)
    add_child(flash)

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

func _find_in_group(node: Node, group: String) -> Array[Node]:
    var found: Array[Node] = []
    for child in node.get_children():
        if child.is_in_group(group):
            found.append(child)
        found.append_array(_find_in_group(child, group))
    return found
