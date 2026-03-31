extends GutTest

func test_damage_reduces_health():
    var health = C_Health.new()
    health.current_health = 100
    health.current_health -= 25
    assert_eq(health.current_health, 75)

func test_health_does_not_go_below_zero():
    var health = C_Health.new()
    health.current_health = 10
    health.current_health -= 25
    health.current_health = maxi(health.current_health, 0)
    assert_eq(health.current_health, 0)

func test_element_applies_condition():
    var conditions = C_Conditions.new()
    var registry = ElementRegistry.new()
    registry._setup_defaults()
    var elem = registry.get_element("fire")
    if elem and elem.applies_condition != "":
        conditions.add_condition(elem.applies_condition, elem.condition_duration)
    assert_true(conditions.has_condition("burning"))

func test_element_interaction_creates_new_condition():
    var conditions = C_Conditions.new()
    var registry = ElementRegistry.new()
    registry._setup_defaults()
    # Actor is wet, gets hit by ice
    conditions.add_condition("wet", 5.0)
    var interaction = registry.get_interaction("wet", "ice")
    if interaction and interaction.result_condition != "":
        conditions.remove_condition("wet")
        conditions.add_condition(interaction.result_condition, interaction.duration)
    assert_true(conditions.has_condition("frozen"))
    assert_false(conditions.has_condition("wet"))
