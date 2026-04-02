class_name ProjectileEntity
extends Area3D

var ecs_entity: Entity
var _dying := false
var _setup_called := false
var _logged_ghost := false

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    ecs_entity.add_component(C_Projectile.new())
    ecs_entity.add_component(C_DamageDealer.new())

    body_entered.connect(_on_body_entered)
    tree_exiting.connect(func():
        if not _dying:
            GameLog.info("[Projectile] DESPAWN (spawner): name=%s" % name)
    )

    # Hide until setup/setup_client is called (prevents flash at wrong position)
    if Net.is_active:
        visible = false

    # Step 1: Log spawn state
    GameLog.info("[Projectile] _ready: name=%s is_host=%s visible=%s pos=%s" % [
        name, str(Net.is_host), str(visible), str(position)])

    # Step 3: Check if spawner overrides visible after _ready
    call_deferred("_check_visible_override")

    # Self-destruct timer (works on both host and client)
    get_tree().create_timer(5.0).timeout.connect(_expire)

func _check_visible_override() -> void:
    if not _setup_called and visible:
        GameLog.info("[Projectile] OVERRIDE DETECTED: visible=true after _ready set false! name=%s" % name)

func setup(dir: Vector3, spd: float, dmg: int, elem: String, owner_id: int) -> void:
    _setup_called = true
    visible = true
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
    _setup_called = true
    visible = true
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    if not proj:
        return
    proj.direction = dir
    proj.speed = spd
    proj.element = elem

    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(ecs_entity):
        return
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    if not proj or proj.speed == 0:
        # Step 1: Detect ghost projectiles (visible, not moving, no setup)
        if not _logged_ghost and visible and not _setup_called:
            _logged_ghost = true
            GameLog.info("[Projectile] GHOST: name=%s visible=%s speed=0 setup_called=%s pos=%s" % [
                name, str(visible), str(_setup_called), str(global_position)])
        return
    position += proj.direction * proj.speed * delta

func _expire() -> void:
    if _dying:
        return
    _dying = true
    GameLog.info("[Projectile] EXPIRE (timer): name=%s" % name)
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
    GameLog.info("[Projectile] HIT (collision): name=%s" % name)

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
