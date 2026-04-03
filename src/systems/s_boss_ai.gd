class_name S_BossAI
extends System

signal boss_projectile_requested(pos: Vector3, direction: Vector3, damage: int, speed: float, owner_id: int)

func query() -> QueryBuilder:
    return q.with_all([C_BossAI, C_MonsterAI, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    if Net.is_active and not Net.is_host:
        return
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var boss_ai := entity.get_component(C_BossAI) as C_BossAI
        var monster_ai := entity.get_component(C_MonsterAI) as C_MonsterAI
        var health := entity.get_component(C_Health) as C_Health

        if health.current_health <= 0:
            continue

        boss_ai.ranged_cooldown_remaining = maxf(boss_ai.ranged_cooldown_remaining - delta, 0)

        if monster_ai.state != C_MonsterAI.AIState.IDLE and boss_ai.ranged_cooldown_remaining <= 0:
            var body = entity.get_parent() as CharacterBody3D
            if not body:
                continue
            var target = _find_nearest_cached(body.global_position)
            if target != Vector3.ZERO:
                boss_ai.ranged_cooldown_remaining = boss_ai.ranged_cooldown
                var dir = (target - body.global_position).normalized()
                var spawn_pos = body.global_position + Vector3(0, 1.0, 0) + dir * 1.5
                boss_projectile_requested.emit(spawn_pos, dir, boss_ai.projectile_damage, boss_ai.projectile_speed, body.get_instance_id())

func _find_nearest_cached(from: Vector3) -> Vector3:
    var nearest_dist := INF
    var nearest_pos := Vector3.ZERO
    for pos in S_MonsterAI.player_positions:
        var dist = from.distance_to(pos)
        if dist < nearest_dist:
            nearest_dist = dist
            nearest_pos = pos
    return nearest_pos
