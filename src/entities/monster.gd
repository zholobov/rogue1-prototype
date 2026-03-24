class_name MonsterEntity
extends CharacterBody3D

var ecs_entity: Entity
var _body_material: StandardMaterial3D
var _base_emission_energy: float = 1.0
var _health_bar_node: Node3D
var _health_bar_fg: MeshInstance3D
var _health_bar_visible := false

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
    _setup_health_bar()

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

func _setup_health_bar() -> void:
    _health_bar_node = Node3D.new()
    _health_bar_node.position = Vector3(0, 1.2, 0)
    _health_bar_node.visible = false
    add_child(_health_bar_node)

    # Background bar (dark gray)
    var bg = MeshInstance3D.new()
    var bg_mesh = BoxMesh.new()
    bg_mesh.size = Vector3(1.0, 0.05, 0.02)
    bg.mesh = bg_mesh
    var bg_mat = StandardMaterial3D.new()
    bg_mat.albedo_color = Color(0.15, 0.15, 0.15)
    bg.material_override = bg_mat
    _health_bar_node.add_child(bg)

    # Foreground bar (green, scales with HP)
    _health_bar_fg = MeshInstance3D.new()
    var fg_mesh = BoxMesh.new()
    fg_mesh.size = Vector3(1.0, 0.05, 0.02)
    _health_bar_fg.mesh = fg_mesh
    _health_bar_fg.position = Vector3(0, 0, 0.01)
    var fg_mat = StandardMaterial3D.new()
    fg_mat.albedo_color = Color(0.0, 1.0, 0.3)
    fg_mat.emission_enabled = true
    fg_mat.emission = Color(0.0, 1.0, 0.3)
    fg_mat.emission_energy_multiplier = 1.5
    _health_bar_fg.material_override = fg_mat
    _health_bar_node.add_child(_health_bar_fg)

func _process(_delta: float) -> void:
    if not _health_bar_node:
        return
    var health := ecs_entity.get_component(C_Health) as C_Health
    if not health:
        return

    # Show only when damaged
    var should_show = health.current_health < health.max_health and health.current_health > 0
    if should_show != _health_bar_visible:
        _health_bar_visible = should_show
        _health_bar_node.visible = should_show

    if not _health_bar_visible:
        return

    # Update bar width and color based on HP ratio
    var ratio = float(health.current_health) / float(health.max_health)
    _health_bar_fg.scale.x = ratio
    _health_bar_fg.position.x = -(1.0 - ratio) * 0.5

    # Color: green at full → red at low
    var bar_color = Color(1.0 - ratio, ratio, 0.1)
    var fg_mat = _health_bar_fg.material_override as StandardMaterial3D
    fg_mat.albedo_color = bar_color
    fg_mat.emission = bar_color

    # Billboard: face camera
    var camera = get_viewport().get_camera_3d()
    if camera:
        _health_bar_node.look_at(camera.global_position)
