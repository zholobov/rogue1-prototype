class_name PlayerEntity
extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var ecs_entity: Entity
var _current_weapon_index: int = 0

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

    # Multiplayer sync: position and rotation
    var sync = MultiplayerSynchronizer.new()
    sync.name = "PlayerSync"
    var config = SceneReplicationConfig.new()
    config.add_property(NodePath(".:position"))
    config.add_property(NodePath(".:rotation"))
    sync.replication_config = config
    sync.replication_interval = 1.0 / 20.0
    add_child(sync)

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

    var wv := get_component(C_WeaponVisual) as C_WeaponVisual
    if wv:
        wv.show_viewmodel = is_local
        wv.weapon_index = _current_weapon_index
        wv.element = get_component(C_Weapon).element if get_component(C_Weapon) else ""

func _input(event: InputEvent) -> void:
    var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
    if not net_id.is_local:
        return

    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * Config.mouse_sensitivity)
        camera.rotate_x(-event.relative.y * Config.mouse_sensitivity)
        camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(70), deg_to_rad(70))

    if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

    if event.is_action_pressed("ui_cancel"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    for i in range(WeaponRegistry.weapon_count()):
        if event.is_action_pressed("weapon_%d" % (i + 1)):
            _equip_weapon(i)

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
