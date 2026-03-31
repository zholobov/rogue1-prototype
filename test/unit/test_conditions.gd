extends GutTest

func test_conditions_component_starts_empty():
	var c = C_Conditions.new()
	assert_eq(c.active.size(), 0)

func test_add_condition():
	var c = C_Conditions.new()
	c.add_condition("wet", 5.0)
	assert_eq(c.active.size(), 1)
	assert_true(c.has_condition("wet"))

func test_condition_has_duration():
	var c = C_Conditions.new()
	c.add_condition("burning", 3.0)
	var cond = c.get_condition("burning")
	assert_almost_eq(cond.remaining, 3.0, 0.01)

func test_remove_condition():
	var c = C_Conditions.new()
	c.add_condition("wet", 5.0)
	c.remove_condition("wet")
	assert_false(c.has_condition("wet"))

func test_tick_reduces_duration():
	var c = C_Conditions.new()
	c.add_condition("wet", 5.0)
	c.tick(1.0)
	var cond = c.get_condition("wet")
	assert_almost_eq(cond.remaining, 4.0, 0.01)

func test_expired_condition_removed_on_tick():
	var c = C_Conditions.new()
	c.add_condition("wet", 1.0)
	c.tick(2.0)
	assert_false(c.has_condition("wet"))

func test_stacking_reset():
	var c = C_Conditions.new()
	c.add_condition("burning", 3.0)
	c.add_condition("burning", 3.0, "reset")
	assert_almost_eq(c.get_condition("burning").remaining, 3.0, 0.01)

func test_stacking_extend():
	var c = C_Conditions.new()
	c.add_condition("burning", 3.0)
	c.add_condition("burning", 3.0, "extend")
	assert_almost_eq(c.get_condition("burning").remaining, 6.0, 0.01)
