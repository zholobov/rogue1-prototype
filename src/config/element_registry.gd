class_name ElementRegistry
extends Node

# Internal storage: StringName -> ElementDefinition
var _elements: Dictionary = {}

# Interaction rules: StringName key -> Dictionary { result_condition, duration, damage_per_tick }
var interactions: Dictionary = {}

# Stacking mode: "reset", "extend", "intensify"
@export var stacking_mode: String = "reset"

func _ready() -> void:
	if _elements.is_empty():
		_setup_defaults()

func _setup_defaults() -> void:
	# Fire
	var fire = ElementDefinition.new()
	fire.element_name = ElementNames.FIRE
	fire.display_name = "Fire"
	fire.condition_name = ConditionNames.BURNING
	fire.condition_duration = 3.0
	fire.default_color = ThemeManager.active_theme.get_element_color(ElementNames.FIRE)
	_elements[fire.element_name] = fire

	# Ice
	var ice = ElementDefinition.new()
	ice.element_name = ElementNames.ICE
	ice.display_name = "Ice"
	ice.condition_name = ConditionNames.CHILLED
	ice.condition_duration = 3.0
	ice.default_color = ThemeManager.active_theme.get_element_color(ElementNames.ICE)
	_elements[ice.element_name] = ice

	# Water
	var water = ElementDefinition.new()
	water.element_name = ElementNames.WATER
	water.display_name = "Water"
	water.condition_name = ConditionNames.WET
	water.condition_duration = 5.0
	water.default_color = ThemeManager.active_theme.get_element_color(ElementNames.WATER)
	_elements[water.element_name] = water

	# Oil
	var oil = ElementDefinition.new()
	oil.element_name = ElementNames.OIL
	oil.display_name = "Oil"
	oil.condition_name = ConditionNames.OILY
	oil.condition_duration = 5.0
	oil.default_color = ThemeManager.active_theme.get_element_color(ElementNames.OIL)
	_elements[oil.element_name] = oil

	# Default interactions: existing_condition + incoming_element = result
	add_interaction(ConditionNames.WET, ElementNames.ICE, ConditionNames.FROZEN, 4.0, 0.0)
	add_interaction(ConditionNames.WET, ElementNames.FIRE, ElementNames.NONE, 0.0, 0.0)		 # fire cancels wet
	add_interaction(ConditionNames.OILY, ElementNames.FIRE, ConditionNames.BURNING, 5.0, 10.0)
	add_interaction(ConditionNames.CHILLED, ElementNames.FIRE, ElementNames.NONE, 0.0, 0.0)	 # fire cancels chill
	add_interaction(ConditionNames.BURNING, ElementNames.WATER, ElementNames.NONE, 0.0, 0.0) # water cancels burning

func add_element(element_name: StringName, color: Color, condition: StringName, condition_duration: float) -> void:
	var def = ElementDefinition.new()
	def.element_name = element_name
	def.condition_name = condition
	def.condition_duration = condition_duration
	def.default_color = color
	_elements[element_name] = def

func get_element(element_name: StringName) -> ElementDefinition:
	if _elements.has(element_name):
		return _elements[element_name]
	return null

func has_element(element_name: StringName) -> bool:
	return _elements.has(element_name)

func add_interaction(existing_condition: String, incoming_element: String, result_condition: String, duration: float, damage_per_tick: float) -> void:
	var key = "%s+%s" % [existing_condition, incoming_element]
	interactions[key] = {
		"result_condition": result_condition,
		"duration": duration,
		"damage_per_tick": damage_per_tick,
	}

func get_interaction(existing_condition: String, incoming_element: String) -> Variant:
	var key = "%s+%s" % [existing_condition, incoming_element]
	if interactions.has(key):
		return interactions[key]
	return null
