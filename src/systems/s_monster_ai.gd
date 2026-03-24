class_name S_MonsterAI
extends System

func query() -> QueryBuilder:
    return q.with_all([C_MonsterAI, C_Velocity, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    # Find all player positions
    var player_positions: Array[Vector3] = []
    var player_nodes: Array[Node] = _get_players()
    for node in player_nodes:
        player_positions.append(node.global_position)

    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var ai := entity.get_component(C_MonsterAI) as C_MonsterAI
        var vel := entity.get_component(C_Velocity) as C_Velocity
        var health := entity.get_component(C_Health) as C_Health

        if health.current_health <= 0:
            continue

        var body = entity.get_parent() as CharacterBody3D
        if not body:
            continue

        # Tick attack cooldown
        ai.cooldown_remaining = maxf(ai.cooldown_remaining - delta, 0)

        # Find nearest player
        var nearest_dist := INF
        var nearest_pos := Vector3.ZERO
        for pos in player_positions:
            var dist = body.global_position.distance_to(pos)
            if dist < nearest_dist:
                nearest_dist = dist
                nearest_pos = pos

        # State machine
        if nearest_dist > ai.detection_range:
            ai.state = C_MonsterAI.AIState.IDLE
            vel.direction = Vector3.ZERO
            vel.speed = 0.0
        elif nearest_dist > ai.attack_range:
            ai.state = C_MonsterAI.AIState.CHASE
            var dir = (nearest_pos - body.global_position).normalized()
            dir.y = 0
            vel.direction = dir
            vel.speed = ai.move_speed
            # Face movement direction
            if dir.length() > 0.1:
                body.look_at(body.global_position + dir, Vector3.UP)
        else:
            ai.state = C_MonsterAI.AIState.ATTACK
            vel.direction = Vector3.ZERO
            vel.speed = 0.0
            if ai.cooldown_remaining <= 0:
                ai.cooldown_remaining = ai.attack_cooldown
                _attack_nearest(entity, nearest_pos, ai)

func _get_players() -> Array[Node]:
    var players: Array[Node] = []
    var tree = ECS.world.get_tree()
    if tree:
        for node in tree.get_nodes_in_group("players"):
            players.append(node)
    return players

func _attack_nearest(monster_entity: Entity, target_pos: Vector3, ai: C_MonsterAI) -> void:
    var body = monster_entity.get_parent() as CharacterBody3D
    if not body:
        return
    for player in _get_players():
        if player.global_position.distance_to(body.global_position) <= ai.attack_range + 0.5:
            if player is PlayerEntity:
                var hp = player.ecs_entity.get_component(C_Health) as C_Health
                print("[S_MonsterAI] Monster attacks player for %d dmg (player HP: %d→%d)" % [ai.attack_damage, hp.current_health if hp else -1, (hp.current_health - ai.attack_damage) if hp else -1])
                S_Damage.apply_damage(player.ecs_entity, ai.attack_damage, ai.attack_element)
                break
