class_name MonsterEntity
extends CharacterBody3D

var ecs_entity: Entity
var _body_material: StandardMaterial3D
var _base_emission_energy: float = 1.0
var _health_bar_node: Node3D
var _health_bar_fg: MeshInstance3D
var _health_bar_visible := false
var visual_variant: String = "basic"

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
    add_to_group("monsters")

func _setup_visuals() -> void:
    var theme := ThemeManager.active_theme
    var accent = theme.get_random_palette_color()

    # Scene override: if theme provides a monster scene, use it instead of procedural
    var scene_override := ThemeManager.get_monster_scene(visual_variant)
    if scene_override:
        # Remove ALL original meshes from the base monster.tscn immediately
        var to_remove: Array[Node] = []
        for child in get_children():
            if child is MeshInstance3D:
                to_remove.append(child)
        for child in to_remove:
            remove_child(child)
            child.free()
        var visual_root := scene_override.instantiate() as Node3D
        visual_root.name = "VisualRoot"
        add_child(visual_root)
        # Apply body material to BodyMesh child
        var body_mesh := visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
        if body_mesh:
            _body_material = StandardMaterial3D.new()
            _body_material.albedo_color = theme.body_albedo
            _body_material.emission_enabled = true
            _body_material.emission = accent
            _body_material.emission_energy_multiplier = _base_emission_energy
            body_mesh.material_override = _body_material
        # Apply eye material to optional EyeMesh child
        var eye_mesh := visual_root.get_node_or_null("EyeMesh") as MeshInstance3D
        if eye_mesh:
            var eye_mat = StandardMaterial3D.new()
            eye_mat.albedo_color = Color.BLACK
            eye_mat.emission_enabled = true
            eye_mat.emission = theme.eye_color
            eye_mat.emission_energy_multiplier = 3.0
            eye_mesh.material_override = eye_mat
    else:
        # Procedural fallback: find existing MeshInstance3D child (from the .tscn scene)
        var mesh_node: MeshInstance3D = null
        for child in get_children():
            if child is MeshInstance3D:
                mesh_node = child
                break

        # Apply dark emissive material to body
        if mesh_node:
            _body_material = StandardMaterial3D.new()
            _body_material.albedo_color = theme.body_albedo
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
    mat.emission = ThemeManager.active_theme.eye_color
    mat.emission_energy_multiplier = 3.0
    eye.material_override = mat

    add_child(eye)

func setup_as_boss(loop: int) -> void:
    var theme := ThemeManager.active_theme

    # Check for boss scene override
    var boss_scene := ThemeManager.get_monster_scene("boss")
    if boss_scene:
        # Remove ALL visual children added by _setup_visuals immediately
        var to_remove: Array[Node] = []
        for child in get_children():
            if child is Node3D and child != _health_bar_node and child != ecs_entity:
                if child is MeshInstance3D or child.name == "VisualRoot":
                    to_remove.append(child)
        for child in to_remove:
            remove_child(child)
            child.free()
        var visual_root := boss_scene.instantiate() as Node3D
        visual_root.name = "VisualRoot"
        add_child(visual_root)
        var body_mesh := visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
        if body_mesh:
            _body_material = StandardMaterial3D.new()
            _body_material.albedo_color = theme.boss_albedo
            _body_material.emission_enabled = true
            _body_material.emission = theme.boss_emission
            _body_material.emission_energy_multiplier = 2.0
            body_mesh.material_override = _body_material
        var eye_mesh := visual_root.get_node_or_null("EyeMesh") as MeshInstance3D
        if eye_mesh:
            var eye_mat = StandardMaterial3D.new()
            eye_mat.albedo_color = Color.BLACK
            eye_mat.emission_enabled = true
            eye_mat.emission = theme.eye_color
            eye_mat.emission_energy_multiplier = 3.0
            eye_mesh.material_override = eye_mat

    scale = Vector3(2.0, 2.0, 2.0)

    if _body_material:
        _body_material.albedo_color = theme.boss_albedo
        _body_material.emission = theme.boss_emission
        _body_material.emission_energy_multiplier = 2.0

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

    ecs_entity.add_component(C_BossAI.new())
    var boss_ai := ecs_entity.get_component(C_BossAI) as C_BossAI
    if boss_ai:
        boss_ai.projectile_damage = 15 + (5 * loop)
        boss_ai.is_boss = true

    if _health_bar_node:
        _health_bar_node.position = Vector3(0, 2.4, 0)

    var wv := C_WeaponVisual.new()
    wv.weapon_index = 0
    wv.element = ""
    ecs_entity.add_component(wv)

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
    var theme := ThemeManager.active_theme

    _health_bar_node = Node3D.new()
    _health_bar_node.position = Vector3(0, 1.2, 0)
    _health_bar_node.visible = false
    add_child(_health_bar_node)

    # Background bar
    var bg = MeshInstance3D.new()
    var bg_mesh = BoxMesh.new()
    bg_mesh.size = Vector3(1.0, 0.05, 0.02)
    bg.mesh = bg_mesh
    var bg_mat = StandardMaterial3D.new()
    bg_mat.albedo_color = theme.health_bar_background
    bg.material_override = bg_mat
    _health_bar_node.add_child(bg)

    # Foreground bar (scales with HP)
    _health_bar_fg = MeshInstance3D.new()
    var fg_mesh = BoxMesh.new()
    fg_mesh.size = Vector3(1.0, 0.05, 0.02)
    _health_bar_fg.mesh = fg_mesh
    _health_bar_fg.position = Vector3(0, 0, -0.01)
    var fg_mat = StandardMaterial3D.new()
    fg_mat.albedo_color = theme.health_bar_foreground
    fg_mat.emission_enabled = true
    fg_mat.emission = theme.health_bar_foreground
    fg_mat.emission_energy_multiplier = 1.5
    _health_bar_fg.material_override = fg_mat
    _health_bar_node.add_child(_health_bar_fg)

var _last_health: int = -1

func _process(_delta: float) -> void:
    if not _health_bar_node:
        return
    var health := ecs_entity.get_component(C_Health) as C_Health
    if not health:
        return

    # Only update bar when health actually changes
    if health.current_health == _last_health:
        # Still need to billboard if visible
        if _health_bar_visible:
            var camera = get_viewport().get_camera_3d()
            if camera:
                _health_bar_node.look_at(camera.global_position)
        return
    _last_health = health.current_health

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
    _health_bar_fg.position.x = (1.0 - ratio) * 0.5

    var theme := ThemeManager.active_theme
    var bar_color = theme.health_bar_foreground.lerp(theme.health_bar_low_color, 1.0 - ratio)
    var fg_mat = _health_bar_fg.material_override as StandardMaterial3D
    fg_mat.albedo_color = bar_color
    fg_mat.emission = bar_color

    # Billboard: face camera
    var camera = get_viewport().get_camera_3d()
    if camera:
        _health_bar_node.look_at(camera.global_position)
