class_name ElementRegistry
extends Node

# Element definition: { name, color, applies_condition, condition_duration }
var elements: Dictionary = {}

# Interaction rules: { "condition_name+element_name": { result_condition, duration, damage_per_tick } }
var interactions: Dictionary = {}

# Stacking mode: "reset", "extend", "intensify"
@export var stacking_mode: String = "reset"

func _ready() -> void:
    if elements.is_empty():
        _setup_defaults()

func _setup_defaults() -> void:
    # Default elements
    add_element("fire", Color.ORANGE_RED, "burning", 3.0)
    add_element("ice", Color.LIGHT_BLUE, "chilled", 3.0)
    add_element("water", Color.DODGER_BLUE, "wet", 5.0)
    add_element("oil", Color.DARK_OLIVE_GREEN, "oily", 5.0)

    # Default interactions: existing_condition + incoming_element = result
    add_interaction("wet", "ice", "frozen", 4.0, 0.0)
    add_interaction("wet", "fire", "", 0.0, 0.0)  # fire cancels wet
    add_interaction("oily", "fire", "burning", 5.0, 10.0)
    add_interaction("chilled", "fire", "", 0.0, 0.0)  # fire cancels chill
    add_interaction("burning", "water", "", 0.0, 0.0)  # water cancels burning

func add_element(name: String, color: Color, applies_condition: String, condition_duration: float) -> void:
    elements[name] = {
        "name": name,
        "color": color,
        "applies_condition": applies_condition,
        "condition_duration": condition_duration,
    }

func get_element(name: String) -> Variant:
    if elements.has(name):
        return elements[name]
    return null

func has_element(name: String) -> bool:
    return elements.has(name)

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
