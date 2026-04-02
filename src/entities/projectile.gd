class_name ProjectileEntity
extends Area3D

var ecs_entity: Entity
var _dying := false
var _owner_body: Node3D  # For collision exception

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    ecs_entity.add_component(C_Projectile.new())
    ecs_entity.add_component(C_DamageDealer.new())

    body_entered.connect(_on_body_entered)

    # Hide until setup/setup_client is called
    if Net.is_active:
        visible = false

    # Self-destruct timer (works on both host and client)
    get_tree().create_timer(5.0).timeout.connect(_expire)

func setup(dir: Vector3, spd: float, dmg: int, elem: String, owner_peer_id: int) -> void:
    visible = true
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    proj.direction = dir
    proj.speed = spd
    proj.element = elem
    proj.damage = dmg
    proj.owner_id = owner_peer_id

    var dd := ecs_entity.get_component(C_DamageDealer) as C_DamageDealer
    dd.damage = dmg
    dd.element = elem
    dd.owner_entity_id = owner_peer_id

    # Collision exception: ignore owner for 0.2s so projectile clears the body
    _add_owner_exception(owner_peer_id)

    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func setup_client(dir: Vector3, spd: float, elem: String) -> void:
    visible = true
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    if not proj:
        return
    proj.direction = dir
    proj.speed = spd
    proj.element = elem

    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func _add_owner_exception(peer_id: int) -> void:
    var player_container = get_tree().current_scene.get_node_or_null("Players")
    if not player_container:
        return
    var owner_node = player_container.get_node_or_null("Player_%d" % peer_id)
    if owner_node and owner_node is CollisionObject3D:
        _owner_body = owner_node
        add_collision_exception_with(_owner_body)
        # Remove exception after grace period — self-harm now possible
        get_tree().create_timer(0.2).timeout.connect(_remove_owner_exception)

func _remove_owner_exception() -> void:
    if is_instance_valid(_owner_body) and not _dying:
        remove_collision_exception_with(_owner_body)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(ecs_entity):
        return
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    if not proj or proj.speed == 0:
        return
    position += proj.direction * proj.speed * delta

func _expire() -> void:
    if _dying:
        return
    _dying = true
    if ECS.world and is_instance_valid(ecs_entity):
        ECS.world.remove_entity(ecs_entity)
    queue_free()

func _on_body_entered(body: Node) -> void:
    # Only host processes collisions
    if Net.is_active and not Net.is_host:
        return
    if _dying:
        return
    _dying = true

    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    var impact = VfxFactory.create_impact(global_position, proj.direction, proj.element)
    get_tree().current_scene.add_child(impact)

    if body is CharacterBody3D and body.has_method("get_component"):
        S_Damage.apply_damage(body.ecs_entity, proj.damage, proj.element)

    if ECS.world and is_instance_valid(ecs_entity):
        ECS.world.remove_entity(ecs_entity)
    queue_free()
