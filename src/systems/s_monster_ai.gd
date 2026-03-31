class_name S_MonsterAI
extends System

# Cached once per frame to avoid repeated tree scans
var _cached_player_nodes: Array[Node] = []
var _cached_player_positions: Array[Vector3] = []

func query() -> QueryBuilder:
	return q.with_all([C_MonsterAI, C_Velocity, C_Health])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if Net.is_active and not Net.is_host:
		return
	# Cache player positions ONCE per frame
	_cached_player_nodes.clear()
	_cached_player_positions.clear()
	var tree = ECS.world.get_tree()
	if tree:
		for node in tree.get_nodes_in_group("players"):
			_cached_player_nodes.append(node)
			_cached_player_positions.append(node.global_position)

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

		# Find nearest player from cache
		var nearest_dist := INF
		var nearest_pos := Vector3.ZERO
		for pos in _cached_player_positions:
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
			if dir.length() > 0.1:
				body.look_at(body.global_position + dir, Vector3.UP)
		else:
			ai.state = C_MonsterAI.AIState.ATTACK
			vel.direction = Vector3.ZERO
			vel.speed = 0.0
			var face_dir = (nearest_pos - body.global_position).normalized()
			face_dir.y = 0
			if face_dir.length() > 0.1:
				body.look_at(body.global_position + face_dir, Vector3.UP)
			if ai.cooldown_remaining <= 0:
				ai.cooldown_remaining = ai.attack_cooldown
				_attack_nearest(entity, nearest_pos, ai)

func _attack_nearest(monster_entity: Entity, _target_pos: Vector3, ai: C_MonsterAI) -> void:
	var body = monster_entity.get_parent() as CharacterBody3D
	if not body:
		return
	# Use cached player nodes instead of another tree scan
	for player in _cached_player_nodes:
		if player.global_position.distance_to(body.global_position) <= ai.attack_range + 0.5:
			if player is PlayerEntity:
				S_Damage.apply_damage(player.ecs_entity, ai.attack_damage, ai.attack_element)
				break
