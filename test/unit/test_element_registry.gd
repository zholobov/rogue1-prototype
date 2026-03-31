extends GutTest

var registry: ElementRegistry

func before_each():
	registry = ElementRegistry.new()
	registry._setup_defaults()

func test_has_default_elements():
	assert_true(registry.has_element("fire"))
	assert_true(registry.has_element("ice"))
	assert_true(registry.has_element("water"))
	assert_true(registry.has_element("oil"))

func test_element_has_properties():
	var fire = registry.get_element("fire")
	assert_not_null(fire)
	assert_has(fire, "name")
	assert_has(fire, "color")

func test_interaction_wet_plus_ice_equals_frozen():
	var result = registry.get_interaction("wet", "ice")
	assert_not_null(result)
	assert_eq(result.result_condition, "frozen")

func test_interaction_oily_plus_fire_equals_burning():
	var result = registry.get_interaction("oily", "fire")
	assert_not_null(result)
	assert_eq(result.result_condition, "burning")

func test_element_applies_condition():
	var fire = registry.get_element("fire")
	assert_has(fire, "applies_condition")

func test_unknown_element_returns_null():
	assert_null(registry.get_element("nonexistent"))

func test_unknown_interaction_returns_null():
	assert_null(registry.get_interaction("fire", "fire"))
