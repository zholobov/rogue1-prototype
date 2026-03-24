class_name S_PlayerInput
extends System

func query() -> QueryBuilder:
	return q.with_all([C_PlayerInput, C_Velocity, C_NetworkIdentity, C_Weapon])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		if not is_instance_valid(entity):
			print("[S_PlayerInput] Skipping freed entity")
			continue
		var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity
		if not net_id.is_local:
			continue

		var pi := entity.get_component(C_PlayerInput) as C_PlayerInput
		var vel := entity.get_component(C_Velocity) as C_Velocity

		# Capture input
		pi.move_direction = Input.get_vector("left", "right", "forward", "back")
		pi.jumping = Input.is_action_just_pressed("jump")

		# Convert to velocity (entity's parent is the CharacterBody3D)
		var body = entity.get_parent() as Node3D
		var basis = body.global_transform.basis
		var move_dir = basis * Vector3(pi.move_direction.x, 0, pi.move_direction.y)
		vel.direction = move_dir.normalized() if move_dir.length() > 0 else Vector3.ZERO
		var base_speed = Config.player_speed
		var ps := entity.get_component(C_PlayerStats) as C_PlayerStats
		if ps:
			base_speed *= ps.speed_mult
		vel.speed = base_speed if vel.direction != Vector3.ZERO else 0.0

		# Fire weapon
		var weapon := entity.get_component(C_Weapon) as C_Weapon
		weapon.is_firing = Input.is_action_pressed("fire")
