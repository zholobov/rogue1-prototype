class_name S_Lifetime
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Lifetime])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    if Net.is_active and not Net.is_host:
        return
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var lt := entity.get_component(C_Lifetime) as C_Lifetime
        lt.remaining -= delta
        if lt.remaining <= 0:
            var parent = entity.get_parent()
            if ECS.world:
                ECS.world.remove_entity(entity)
            if is_instance_valid(parent):
                parent.queue_free()
