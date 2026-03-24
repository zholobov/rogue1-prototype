class_name S_Death
extends System

signal actor_died(entity: Entity)

func query() -> QueryBuilder:
    return q.with_all([C_Health])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var health := entity.get_component(C_Health) as C_Health
        if health.current_health <= 0:
            var parent = entity.get_parent()
            print("[S_Death] Entity died: %s (parent: %s)" % [entity.name, parent.name if parent else "none"])
            actor_died.emit(entity)
            # Remove from ECS world (cleans up archetypes, prevents stale refs)
            if ECS.world:
                ECS.world.remove_entity(entity)
            # Free the parent body (player/monster CharacterBody3D)
            if is_instance_valid(parent):
                parent.queue_free()
