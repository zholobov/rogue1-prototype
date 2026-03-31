class_name S_Lifesteal
extends System

func query() -> QueryBuilder:
	# This system is signal-driven, not query-driven
	return q.with_all([C_Lifesteal])

func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	pass

func on_actor_died(entity: Entity) -> void:
	var tag := entity.get_component(C_ActorTag) as C_ActorTag
	if not tag or tag.actor_type != C_ActorTag.ActorType.MONSTER:
		return

	var victim_health := entity.get_component(C_Health) as C_Health
	if not victim_health:
		return

	# Find players with lifesteal
	var tree = ECS.world.get_tree()
	if not tree:
		return
	for player_node in tree.get_nodes_in_group("players"):
		if not player_node is PlayerEntity:
			continue
		var lifesteal := player_node.ecs_entity.get_component(C_Lifesteal) as C_Lifesteal
		if not lifesteal:
			continue
		var player_health := player_node.ecs_entity.get_component(C_Health) as C_Health
		if not player_health:
			continue
		var heal_amount = int(victim_health.max_health * lifesteal.percent)
		if heal_amount > 0:
			player_health.current_health = mini(
				player_health.current_health + heal_amount,
				player_health.max_health
			)
