extends GutTest

func test_velocity_component_stores_direction():
	var vel = C_Velocity.new()
	vel.direction = Vector3(1, 0, 0)
	vel.speed = 10.0
	assert_eq(vel.direction, Vector3(1, 0, 0))
	assert_eq(vel.speed, 10.0)

func test_velocity_defaults_to_zero():
	var vel = C_Velocity.new()
	assert_eq(vel.direction, Vector3.ZERO)
	assert_eq(vel.speed, 0.0)
