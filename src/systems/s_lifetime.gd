class_name S_Lifetime
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Lifetime])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var lt := entity.get_component(C_Lifetime) as C_Lifetime
        lt.remaining -= delta
        if lt.remaining <= 0:
            var parent = entity.get_parent()
            if parent:
                parent.queue_free()
            else:
                entity.queue_free()
