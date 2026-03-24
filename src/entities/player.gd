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
    ecs_entity.add_component(C_Conditions.new())
    ecs_entity.add_component(C_Weapon.new())
    ecs_entity.add_component(C_ActorTag.new())

    var tag := ecs_entity.get_component(C_ActorTag) as C_ActorTag
    tag.actor_type = C_ActorTag.ActorType.PLAYER
    tag.team = 0

    add_to_group("players")

    # Register with ECS world
    ECS.world.add_entity(ecs_entity)

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
