class_name S_Conditions
extends System

func query() -> QueryBuilder:
    return q.with_all([C_Conditions, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    if Net.is_active and not Net.is_host:
        return
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var conditions := entity.get_component(C_Conditions) as C_Conditions
        var health := entity.get_component(C_Health) as C_Health

        # Apply damage-over-time from conditions (skip for god mode players)
        var is_god := false
        if Config.god_mode:
            var tag := entity.get_component(C_ActorTag) as C_ActorTag
            if tag and tag.actor_type == C_ActorTag.ActorType.PLAYER:
                is_god = true
        if not is_god:
            for cond in conditions.active:
                if cond.damage_per_tick > 0:
                    health.current_health -= int(cond.damage_per_tick * delta)

        # Tick durations and remove expired
        conditions.tick(delta)

        # Clamp health
        health.current_health = maxi(health.current_health, 0)
