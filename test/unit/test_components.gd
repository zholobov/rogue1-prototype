extends GutTest

func test_health_defaults():
	var h = C_Health.new()
	assert_eq(h.max_health, 100)
	assert_eq(h.current_health, 100)

func test_health_custom_values():
	var h = C_Health.new()
	h.max_health = 200
	h.current_health = 150
	assert_eq(h.max_health, 200)
	assert_eq(h.current_health, 150)

func test_velocity_defaults():
	var v = C_Velocity.new()
	assert_eq(v.direction, Vector3.ZERO)
	assert_eq(v.speed, 0.0)

func test_player_input_defaults():
	var pi = C_PlayerInput.new()
	assert_eq(pi.move_direction, Vector2.ZERO)
	assert_eq(pi.look_rotation, Vector2.ZERO)
	assert_eq(pi.jumping, false)

func test_network_identity_defaults():
	var ni = C_NetworkIdentity.new()
	assert_eq(ni.peer_id, 0)
	assert_eq(ni.is_local, false)
