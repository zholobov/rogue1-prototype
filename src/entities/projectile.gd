class_name ProjectileEntity
extends Area3D

var ecs_entity: Entity

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    ecs_entity.add_component(C_Projectile.new())
    ecs_entity.add_component(C_DamageDealer.new())
    ecs_entity.add_component(C_Lifetime.new())

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    body_entered.connect(_on_body_entered)

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

func _physics_process(delta: float) -> void:
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    position += proj.direction * proj.speed * delta

func _on_body_entered(body: Node) -> void:
    if body is CharacterBody3D:
        # Damage handled by collision detection
        pass
    # Destroy on any collision
    queue_free()
