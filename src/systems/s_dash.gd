class_name S_Dash
extends System

func query() -> QueryBuilder:
	return q.with_all([C_Dash, C_Velocity, C_NetworkIdentity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity
		if not net_id.is_local:
			continue

		var dash := entity.get_component(C_Dash) as C_Dash
		var vel := entity.get_component(C_Velocity) as C_Velocity

		dash.cooldown_remaining = maxf(dash.cooldown_remaining - delta, 0)

		# Active dash in progress
		if dash.dash_remaining > 0:
			dash.dash_remaining -= delta
			vel.direction = dash.dash_direction
			vel.speed = dash.dash_speed
			continue

		# Trigger new dash
		if Input.is_action_just_pressed("dash") and dash.cooldown_remaining <= 0:
			if vel.direction.length() > 0.1:
				dash.dash_direction = vel.direction.normalized()
			else:
				# Dash forward if standing still
				var body = entity.get_parent() as Node3D
				if body:
					dash.dash_direction = -body.global_transform.basis.z.normalized()
				else:
					dash.dash_direction = Vector3.FORWARD
			dash.dash_remaining = dash.dash_duration
			dash.cooldown_remaining = dash.cooldown
