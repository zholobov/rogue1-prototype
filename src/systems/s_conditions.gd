class_name S_Conditions
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Conditions, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        var conditions := entity.get_component(C_Conditions) as C_Conditions
        var health := entity.get_component(C_Health) as C_Health

        # Apply damage-over-time from conditions
        for cond in conditions.active:
            if cond.damage_per_tick > 0:
                health.current_health -= int(cond.damage_per_tick * delta)

        # Tick durations and remove expired
        conditions.tick(delta)

        # Clamp health
        health.current_health = maxi(health.current_health, 0)
