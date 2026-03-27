class_name ElementDefinition
extends RefCounted

var element_name: StringName = ElementNames.NONE
var display_name: String = ""
var condition_name: StringName = ConditionNames.NONE
var condition_duration: float = 3.0
var default_color: Color = Color.WHITE
var damage_per_tick: float = 0.0
var interactions: Array = []  # [{combine_with: StringName, produces: StringName}]
