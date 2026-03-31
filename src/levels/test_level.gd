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
