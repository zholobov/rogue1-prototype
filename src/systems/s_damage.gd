class_name S_Damage
extends System

## Processes damage when a projectile hits an actor.
## Called from projectile collision, not from ECS query.
## This system provides static helper methods for applying damage.

func query() -> QueryBuilder:
    # This system doesn't iterate — it's called on-demand from collision handlers
    return q.with_all([C_Health, C_Conditions])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    # No-op: damage is applied via apply_damage() called from collision
    pass

static func apply_damage(target_entity: Entity, damage: int, element: String) -> void:
    var health := target_entity.get_component(C_Health) as C_Health
    if not health:
        return

    # Apply raw damage
    health.current_health -= damage
    health.current_health = maxi(health.current_health, 0)

    # Apply elemental condition
    if element != "" and Elements:
        var elem = Elements.get_element(element)
        if elem and elem.applies_condition != "":
            var conditions := target_entity.get_component(C_Conditions) as C_Conditions
            if conditions:
                _apply_element_to_conditions(conditions, element, elem)

static func _apply_element_to_conditions(conditions: C_Conditions, element: String, elem_data: Dictionary) -> void:
    # Check for interactions with existing conditions
    for cond in conditions.active.duplicate():
        var interaction = Elements.get_interaction(cond.name, element)
        if interaction:
            conditions.remove_condition(cond.name)
            if interaction.result_condition != "":
                conditions.add_condition(
                    interaction.result_condition,
                    interaction.duration,
                    Elements.stacking_mode,
                    interaction.damage_per_tick
                )
            return  # interaction consumed the element

    # No interaction — apply base condition
    conditions.add_condition(
        elem_data.applies_condition,
        elem_data.condition_duration,
        Elements.stacking_mode
    )
