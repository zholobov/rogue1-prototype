class_name S_Movement
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Velocity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var vel := entity.get_component(C_Velocity) as C_Velocity
        # For non-CharacterBody3D entities (projectiles, etc.)
        # CharacterBody3D players handle their own movement via move_and_slide()
        var parent = entity.get_parent()
        if parent is Node3D and not parent is CharacterBody3D:
            parent.position += vel.direction * vel.speed * delta
