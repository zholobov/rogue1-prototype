class_name ProjectileEntity
extends Area3D

var ecs_entity: Entity
var _dying := false
var _logged_physics := false
var _physics_frame := 0

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    ecs_entity.add_component(C_Projectile.new())
    ecs_entity.add_component(C_DamageDealer.new())

    body_entered.connect(_on_body_entered)

    # Self-destruct timer (works on both host and client)
    get_tree().create_timer(5.0).timeout.connect(_expire)

func setup(dir: Vector3, spd: float, dmg: int, elem: String, owner_id: int) -> void:
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    proj.direction = dir
    proj.speed = spd
    proj.element = elem
    proj.damage = dmg
    proj.owner_id = owner_id

    var dd := ecs_entity.get_component(C_DamageDealer) as C_DamageDealer
    dd.damage = dmg
    dd.element = elem
    dd.owner_entity_id = owner_id

    # Attach trail particles
    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func setup_client(dir: Vector3, spd: float, elem: String) -> void:
    GameLog.info("[Projectile] setup_client called: dir=%s speed=%s" % [str(dir), str(spd)])
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    if not proj:
        GameLog.info("[Projectile] setup_client: get_component returned null!")
        return
    proj.direction = dir
    proj.speed = spd
    proj.element = elem

    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func _physics_process(delta: float) -> void:
    if not _logged_physics:
        _logged_physics = true
        var valid = is_instance_valid(ecs_entity)
        var proj_check = ecs_entity.get_component(C_Projectile) if valid else null
        GameLog.info("[Projectile] _physics_process first call: entity_valid=%s, component=%s, speed=%s, dir=%s" % [
            str(valid),
            str(proj_check != null),
            str(proj_check.speed) if proj_check else "N/A",
            str(proj_check.direction) if proj_check else "N/A"
        ])
    if not is_instance_valid(ecs_entity):
        return
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    if not proj:
        return
    if proj.speed == 0:
        return
    var old_pos = position
    position += proj.direction * proj.speed * delta
    _physics_frame += 1
    if _physics_frame <= 3 or _physics_frame % 60 == 0:
        GameLog.info("[Projectile] frame=%d pos=%s->%s delta=%s" % [_physics_frame, str(old_pos), str(position), str(delta)])

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
    # Spawn impact particles at collision point
    var impact = VfxFactory.create_impact(global_position, proj.direction, proj.element)
    get_tree().current_scene.add_child(impact)

    if body is CharacterBody3D and body.has_method("get_component"):
        if body.get_instance_id() != proj.owner_id:
            S_Damage.apply_damage(body.ecs_entity, proj.damage, proj.element)

    if ECS.world and is_instance_valid(ecs_entity):
        ECS.world.remove_entity(ecs_entity)
    queue_free()
