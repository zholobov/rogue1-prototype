class_name S_Death
extends System

signal actor_died(entity: Entity)

func query() -> QueryBuilder:
    return q.with_all([C_Health])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    for entity in entities:
        var health := entity.get_component(C_Health) as C_Health
        if health.current_health <= 0:
            actor_died.emit(entity)
            var parent = entity.get_parent()
            if parent:
                parent.queue_free()
