class_name PlayerEntity
extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var ecs_entity: Entity
var _current_weapon_index: int = 0
var _visual_root: Node3D
var _body_material: StandardMaterial3D

const PLAYER_COLORS := [
    Color(0.0, 0.83, 1.0),   # cyan
    Color(1.0, 0.4, 0.2),    # orange
    Color(0.4, 1.0, 0.3),    # green
    Color(1.0, 0.2, 0.8),    # pink
]
var synced_conditions: Array = []
var synced_health: int = 100:
    set(val):
        synced_health = val
        if ecs_entity and Net.is_active and not Net.is_host:
            var health := ecs_entity.get_component(C_Health) as C_Health
            if health:
                health.current_health = val

func _ready():
    # Create an Entity child for ECS component management
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    # Register with ECS world first (empty entity), then add components
    # This avoids GECS _initialize() clearing and re-adding pre-existing components
    ECS.world.add_entity(ecs_entity)

    ecs_entity.add_component(C_Health.new())
    ecs_entity.add_component(C_Velocity.new())
    ecs_entity.add_component(C_PlayerInput.new())
    ecs_entity.add_component(C_NetworkIdentity.new())
    ecs_entity.add_component(C_Conditions.new())
    ecs_entity.add_component(C_Weapon.new())
    ecs_entity.add_component(C_ActorTag.new())
    ecs_entity.add_component(C_PlayerStats.new())
    ecs_entity.add_component(C_WeaponVisual.new())

    var tag := ecs_entity.get_component(C_ActorTag) as C_ActorTag
    tag.actor_type = C_ActorTag.ActorType.PLAYER
    tag.team = 0

    add_to_group("players")

    # Multiplayer sync: position, rotation, health
    var sync = MultiplayerSynchronizer.new()
    sync.name = "PlayerSync"
    var config = SceneReplicationConfig.new()
    config.add_property(NodePath(".:position"))
    config.add_property(NodePath(".:rotation"))
    config.add_property(NodePath(".:synced_health"))
    config.add_property(NodePath(".:synced_conditions"))
    sync.replication_config = config
    sync.replication_interval = 1.0 / 20.0
    add_child(sync)

func _process(_delta: float) -> void:
    # Host pushes health and conditions to synced properties for replication
    if not Net.is_active or Net.is_host:
        var health := get_component(C_Health) as C_Health
        if health:
            synced_health = health.current_health
        var conds := get_component(C_Conditions) as C_Conditions
        if conds:
            var names: Array = []
            for c in conds.active:
                names.append(c.name)
            synced_conditions = names

func get_component(component_class) -> Component:
    return ecs_entity.get_component(component_class)

func setup(peer_id: int, is_local: bool) -> void:
    var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
    net_id.peer_id = peer_id
    net_id.is_local = is_local

    # Set multiplayer authority so MultiplayerSynchronizer works
    set_multiplayer_authority(peer_id)

    if is_local:
        camera.make_current()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    # Instantiate player model from theme
    _setup_player_model(peer_id, is_local)

    var wv := get_component(C_WeaponVisual) as C_WeaponVisual
    if wv:
        wv.show_viewmodel = is_local
        wv.weapon_index = _current_weapon_index
        wv.element = get_component(C_Weapon).element if get_component(C_Weapon) else ""

func _setup_player_model(peer_id: int, is_local: bool) -> void:
    var group = ThemeManager.active_group
    if not group or not group.player_scene:
        return

    _visual_root = group.player_scene.instantiate()
    add_child(_visual_root)

    # Apply player-specific color
    var player_index = 0
    if Net.is_active:
        var all_peers = [Net.my_peer_id]
        all_peers.append_array(Net.peers.keys())
        all_peers.sort()
        player_index = all_peers.find(peer_id) % PLAYER_COLORS.size()

    var color = PLAYER_COLORS[player_index]
    var body_mesh = _visual_root.get_node_or_null("BodyMesh")
    if body_mesh and body_mesh is MeshInstance3D:
        _body_material = StandardMaterial3D.new()
        _body_material.albedo_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3)
        _body_material.emission_enabled = true
        _body_material.emission = color
        _body_material.emission_energy_multiplier = 1.5
        body_mesh.material_override = _body_material

    # Name label
    var name_anchor = _visual_root.get_node_or_null("NameAnchor")
    var label = Label3D.new()
    label.text = "Player %d" % peer_id
    label.font_size = 32
    label.pixel_size = 0.01
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.modulate = Color(color, 0.9)
    if is_local:
        label.visible = false
    if name_anchor:
        name_anchor.add_child(label)
    else:
        label.position = Vector3(0, 1.0, 0)
        _visual_root.add_child(label)

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

    for i in range(WeaponRegistry.weapon_count()):
        if event.is_action_pressed("weapon_%d" % (i + 1)):
            _equip_weapon(i)

func _unhandled_input(event: InputEvent) -> void:
    var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
    if not net_id or not net_id.is_local:
        return
    # Recapture mouse only when clicking on the game world (no UI consumed the click)
    if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _equip_weapon(index: int) -> void:
    if index >= WeaponRegistry.weapon_count():
        return
    _current_weapon_index = index
    if RunManager:
        RunManager.selected_weapon_index = index
    var weapon_def = WeaponRegistry.get_weapon(index)
    var weapon := get_component(C_Weapon) as C_Weapon
    var ps := get_component(C_PlayerStats) as C_PlayerStats
    weapon.damage = int(weapon_def.damage * (ps.damage_mult if ps else 1.0))
    weapon.fire_rate = weapon_def.fire_rate * (1.0 / (1.0 + (ps.fire_rate_bonus if ps else 0.0)))
    weapon.projectile_speed = weapon_def.speed * (1.0 + (ps.proj_speed_bonus if ps else 0.0))
    weapon.element = weapon_def.element
    weapon.cooldown_remaining = 0.0

    var wv := get_component(C_WeaponVisual) as C_WeaponVisual
    if wv:
        wv.weapon_index = index
        wv.element = weapon.element

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

    # Restore weapon selection from run state
    if RunManager:
        _current_weapon_index = RunManager.selected_weapon_index
    _equip_weapon(_current_weapon_index)

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
