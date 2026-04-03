class_name S_Damage
extends RefCounted

## Static utility for applying damage. Not an ECS system — called directly
## from collision handlers (projectile._on_body_entered, S_MonsterAI, etc.)

static func apply_damage(target_entity: Entity, damage: int, element: String) -> void:
    if not is_instance_valid(target_entity):
        return
    # In multiplayer, only host applies damage
    if Net.is_active and not Net.is_host:
        return

    var health := target_entity.get_component(C_Health) as C_Health
    if not health:
        return

    # God mode: skip damage for players
    if Config.god_mode:
        var tag := target_entity.get_component(C_ActorTag) as C_ActorTag
        if tag and tag.actor_type == C_ActorTag.ActorType.PLAYER:
            return

    # Apply damage reduction from C_PlayerStats on target
    var actual_damage = damage
    var player_stats := target_entity.get_component(C_PlayerStats) as C_PlayerStats
    if player_stats:
        actual_damage = int(float(damage) * (1.0 - player_stats.damage_reduction))
    actual_damage = maxi(actual_damage, 1)
    health.current_health -= actual_damage
    health.current_health = maxi(health.current_health, 0)

    # Track outgoing damage (only count damage TO monsters, not FROM them)
    var dmg_target_tag := target_entity.get_component(C_ActorTag) as C_ActorTag
    if dmg_target_tag and dmg_target_tag.actor_type == C_ActorTag.ActorType.MONSTER and RunManager:
        RunManager.stats.damage_dealt += actual_damage
    # Track player damage taken for no-damage bonus
    if not Config.god_mode:
        var dmg_tag := target_entity.get_component(C_ActorTag) as C_ActorTag
        if dmg_tag and dmg_tag.actor_type == C_ActorTag.ActorType.PLAYER and RunManager:
            RunManager.stats.took_damage_this_level = true

    # Visual hit flash on monsters
    var parent = target_entity.get_parent()
    if parent is MonsterEntity:
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
        DamageEvents.emit_damage(parent.global_position, actual_damage, element)

static func _apply_element_to_conditions(conditions: C_Conditions, element: String, elem_data: ElementDefinition, duration_mult: float = 1.0) -> void:
    # Check for interactions with existing conditions
    for cond in conditions.active.duplicate():
        var interaction = Elements.get_interaction(cond.name, element)
        if interaction:
            conditions.remove_condition(cond.name)
            if interaction.result_condition != "":
                conditions.add_condition(
                    interaction.result_condition,
                    interaction.duration * duration_mult,
                    Elements.stacking_mode,
                    interaction.damage_per_tick
                )
            return  # interaction consumed the element

    # No interaction — apply base condition
    conditions.add_condition(
        elem_data.condition_name,
        elem_data.condition_duration * duration_mult,
        Elements.stacking_mode
    )
