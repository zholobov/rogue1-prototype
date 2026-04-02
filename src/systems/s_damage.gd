class_name S_Damage
extends RefCounted

## Static utility for applying damage. Not an ECS system — called directly
## from collision handlers (projectile._on_body_entered, S_MonsterAI, etc.)

static func apply_damage(target_entity: Entity, amount: int, element: String) -> void:
    if not is_instance_valid(target_entity):
        return
    # Only host processes damage
    if Net.is_active and not Net.is_host:
        return

    var health := target_entity.get_component(C_Health) as C_Health
    if not health:
        return

    var actual_damage = amount

    # Elemental resistance/weakness
    if element != "" and Elements:
        var elem = Elements.get_element(element)
        if elem:
            var conditions := target_entity.get_component(C_Conditions) as C_Conditions
            if conditions:
                for cond in conditions.active:
                    if cond.name == elem.strong_against:
                        actual_damage = int(actual_damage * 1.5)
                    elif cond.name == elem.weak_against:
                        actual_damage = int(actual_damage * 0.5)

    health.current_health -= actual_damage
    health.current_health = maxi(health.current_health, 0)

    # Track damage for stats
    var tag := target_entity.get_component(C_ActorTag) as C_ActorTag
    if tag and tag.actor_type == C_ActorTag.ActorType.PLAYER and RunManager:
        RunManager.stats.took_damage_this_level = true

    # Flash hit effect
    var parent = target_entity.get_parent()
    if parent and parent.has_method("flash_hit"):
        parent.flash_hit()

    # Apply elemental condition
    if element != "" and Elements:
        var elem = Elements.get_element(element)
        if elem and elem.condition_name != ConditionNames.NONE:
            var conditions := target_entity.get_component(C_Conditions) as C_Conditions
            if conditions:
                var cond_mult = 1.0
                var target_ps := target_entity.get_component(C_PlayerStats) as C_PlayerStats
                if target_ps:
                    cond_mult = target_ps.condition_duration_mult
                _apply_element_to_conditions(conditions, element, elem, cond_mult)

    # Emit damage event for floating numbers
    if parent and DamageEvents:
        DamageEvents.damage_dealt.emit(parent.global_position, actual_damage, element)

static func _apply_element_to_conditions(conditions: C_Conditions, element: String, elem_data: ElementDefinition, duration_mult: float = 1.0) -> void:
    # Check for interactions with existing conditions
    for cond in conditions.active.duplicate():
        if cond.name in elem_data.removes_conditions:
            conditions.active.erase(cond)
        elif cond.name in elem_data.amplifies_conditions:
            cond.duration *= 1.5

    # Apply new condition
    if elem_data.condition_name != ConditionNames.NONE:
        var new_cond = ConditionInstance.new()
        new_cond.name = elem_data.condition_name
        new_cond.element = element
        new_cond.duration = elem_data.condition_duration * duration_mult
        new_cond.damage_per_tick = elem_data.condition_damage
        new_cond.tick_interval = elem_data.condition_tick_interval
        new_cond.tick_timer = 0.0
        conditions.active.append(new_cond)
