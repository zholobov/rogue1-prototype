class_name ConfigSectionBuilder
extends RefCounted

## Builds ConfigEditor section arrays automatically from objects using Godot reflection.
## Reads @export properties with @export_group and @export_range annotations.
## Usage: ConfigSectionBuilder.from_object(Config) -> Array of section Dictionaries

static func from_object(obj: Object) -> Array:
	var sections: Array = []
	var current_group := ""
	var current_props: Array = []

	for prop in obj.get_property_list():
		# Only process script @export properties
		if not (prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		# Skip built-in Node/Resource properties
		if prop.usage & PROPERTY_USAGE_CATEGORY or prop.usage & PROPERTY_USAGE_SUBGROUP:
			continue

		# Detect @export_group
		if prop.usage & PROPERTY_USAGE_GROUP:
			# Flush previous group
			if current_group != "" and current_props.size() > 0:
				sections.append({"title": current_group, "properties": current_props})
			current_group = prop.name
			current_props = []
			continue

		# Skip properties from parent classes (Node, etc.)
		if prop.get("class_name", "") != "" and prop.class_name != obj.get_script().get_global_name():
			continue

		var entry = _prop_to_entry(obj, prop)
		if entry:
			current_props.append(entry)

	# Flush last group
	if current_group != "" and current_props.size() > 0:
		sections.append({"title": current_group, "properties": current_props})
	elif current_props.size() > 0:
		sections.append({"title": "General", "properties": current_props})

	return sections

static func _prop_to_entry(obj: Object, prop: Dictionary) -> Variant:
	var key = prop.name
	var value = obj.get(key)
	var type_str := ""
	var min_val := 0.0
	var max_val := 100.0
	var step := 1.0
	var options: PackedStringArray = []

	match prop.type:
		TYPE_INT:
			type_str = "int"
			step = 1.0
		TYPE_FLOAT:
			type_str = "float"
			step = 0.01
		TYPE_BOOL:
			type_str = "bool"
		TYPE_STRING:
			# Check for @export_enum
			if prop.hint == PROPERTY_HINT_ENUM:
				type_str = "string_enum"
				options = PackedStringArray(prop.hint_string.split(","))
			else:
				type_str = "string_enum"
				options = PackedStringArray([str(value)])
		TYPE_COLOR:
			type_str = "color"
		_:
			return null	 # Skip unsupported types (Array, Dictionary, etc.)

	# Parse range from hint_string: "min,max,step" or "min,max"
	if prop.hint == PROPERTY_HINT_RANGE and prop.hint_string != "":
		var parts = prop.hint_string.split(",")
		if parts.size() >= 2:
			min_val = float(parts[0])
			max_val = float(parts[1])
		if parts.size() >= 3:
			step = float(parts[2])
	elif type_str == "int":
		min_val = 0
		max_val = 1000
	elif type_str == "float":
		min_val = 0.0
		max_val = 100.0

	# Generate label from key: "monster_hp_mult" -> "Monster Hp Mult"
	var label = key.replace("_", " ").capitalize()

	return {
		"label": label,
		"key": key,
		"type": type_str,
		"value": value,
		"min_value": min_val,
		"max_value": max_val,
		"step": step,
		"options": options,
	}
