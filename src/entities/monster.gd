class_name MonsterEntity
extends CharacterBody3D

var ecs_entity: Entity
var _body_material: StandardMaterial3D
var _base_emission_energy: float = 1.0

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    ecs_entity.add_component(C_Health.new())
    ecs_entity.add_component(C_Velocity.new())
    ecs_entity.add_component(C_Conditions.new())
    ecs_entity.add_component(C_MonsterAI.new())
    ecs_entity.add_component(C_ActorTag.new())

    var tag := ecs_entity.get_component(C_ActorTag) as C_ActorTag
    tag.actor_type = C_ActorTag.ActorType.MONSTER
    tag.team = 1

    _setup_visuals()

func _setup_visuals() -> void:
    var accent = NeonPalette.random_color()

    # Find existing MeshInstance3D child (from the .tscn scene)
    var mesh_node: MeshInstance3D = null
    for child in get_children():
        if child is MeshInstance3D:
            mesh_node = child
            break

    # Apply dark emissive material to body
    if mesh_node:
        _body_material = StandardMaterial3D.new()
        _body_material.albedo_color = Color(0.08, 0.08, 0.1)
        _body_material.emission_enabled = true
        _body_material.emission = accent
        _body_material.emission_energy_multiplier = _base_emission_energy
        mesh_node.material_override = _body_material

    # Add glowing eyes
    _add_eye(Vector3(-0.12, 1.3, -0.41), accent)
    _add_eye(Vector3(0.12, 1.3, -0.41), accent)

    # Random size variation (visual only)
    var scale_factor = randf_range(0.8, 1.2)
    scale = Vector3(scale_factor, scale_factor, scale_factor)

func _add_eye(offset: Vector3, _accent: Color) -> void:
    var eye = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.08, 0.08, 0.02)
    eye.mesh = mesh
    eye.position = offset

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color.BLACK
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.1, 0.1)
    mat.emission_energy_multiplier = 3.0
    eye.material_override = mat

    add_child(eye)

func flash_hit() -> void:
    if _body_material:
        _body_material.emission_energy_multiplier = 5.0
        var tween = create_tween()
        tween.tween_property(_body_material, "emission_energy_multiplier", _base_emission_energy, 0.1)

func get_component(component_class) -> Component:
    return ecs_entity.get_component(component_class)

func _physics_process(delta: float) -> void:
    var vel_comp := ecs_entity.get_component(C_Velocity) as C_Velocity

    if not is_on_floor():
        velocity.y -= Config.gravity * delta

    velocity.x = vel_comp.direction.x * vel_comp.speed
    velocity.z = vel_comp.direction.z * vel_comp.speed

    move_and_slide()
