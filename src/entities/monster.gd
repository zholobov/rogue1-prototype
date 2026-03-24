class_name MonsterEntity
extends CharacterBody3D

var ecs_entity: Entity

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    ecs_entity.add_component(C_Health.new())
    ecs_entity.add_component(C_Velocity.new())
    ecs_entity.add_component(C_Conditions.new())
    ecs_entity.add_component(C_MonsterAI.new())
    ecs_entity.add_component(C_ActorTag.new())

    var tag := ecs_entity.get_component(C_ActorTag) as C_ActorTag
    tag.actor_type = C_ActorTag.ActorType.MONSTER
    tag.team = 1

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

func get_component(component_class) -> Component:
    return ecs_entity.get_component(component_class)

func _physics_process(delta: float) -> void:
    var vel_comp := ecs_entity.get_component(C_Velocity) as C_Velocity

    # Apply gravity
    if not is_on_floor():
        velocity.y -= Config.gravity * delta

    # Apply horizontal movement from AI velocity
    velocity.x = vel_comp.direction.x * vel_comp.speed
    velocity.z = vel_comp.direction.z * vel_comp.speed

    move_and_slide()
