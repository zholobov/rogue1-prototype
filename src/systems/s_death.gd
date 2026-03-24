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

            # Floating kill text for monsters
            if parent is MonsterEntity and is_instance_valid(parent):
                var ft = FloatingText.new()
                parent.get_tree().current_scene.add_child(ft)
                ft.show_text(parent.global_position, "+10")

            actor_died.emit(entity)
            if ECS.world:
                ECS.world.remove_entity(entity)
            if is_instance_valid(parent):
                parent.queue_free()
