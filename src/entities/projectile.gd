class_name ProjectileEntity
extends Area3D

var ecs_entity: Entity
var _dying := false
# Movement vars (used directly, not via ECS, so client movement works reliably)
var move_direction: Vector3 = Vector3.ZERO
var move_speed: float = 0.0

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
    move_direction = dir
    move_speed = spd

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

    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func setup_client(dir: Vector3, spd: float, elem: String) -> void:
    move_direction = dir
    move_speed = spd

    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func _physics_process(delta: float) -> void:
    if move_speed > 0:
        position += move_direction * move_speed * delta

func _expire() -> void:
    if _dying:
        return
    _dying = true
    if ECS.world and is_instance_valid(ecs_entity):
        ECS.world.remove_entity(ecs_entity)
    queue_free()

func _on_body_entered(body: Node) -> void:
    if Net.is_active and not Net.is_host:
        return
    if _dying:
        return
    _dying = true

    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    var impact = VfxFactory.create_impact(global_position, proj.direction, proj.element)
    get_tree().current_scene.add_child(impact)

    if body is CharacterBody3D and body.has_method("get_component"):
        if body.get_instance_id() != proj.owner_id:
            S_Damage.apply_damage(body.ecs_entity, proj.damage, proj.element)

    if ECS.world and is_instance_valid(ecs_entity):
        ECS.world.remove_entity(ecs_entity)
    queue_free()
