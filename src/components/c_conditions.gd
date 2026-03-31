class_name C_Conditions
extends Component

# Array of { name: String, remaining: float, damage_per_tick: float }
@export var active: Array[Dictionary] = []

func add_condition(name: String, duration: float, stacking: String = "reset", damage_per_tick: float = 0.0) -> void:
	for i in range(active.size()):
		if active[i].name == name:
			match stacking:
				"reset":
					active[i].remaining = duration
				"extend":
					active[i].remaining += duration
				"intensify":
					active[i].remaining = duration
					active[i].damage_per_tick += damage_per_tick
			return
	active.append({
		"name": name,
		"remaining": duration,
		"damage_per_tick": damage_per_tick,
	})

func has_condition(name: String) -> bool:
	for cond in active:
		if cond.name == name:
			return true
	return false

func get_condition(name: String) -> Dictionary:
	for cond in active:
		if cond.name == name:
			return cond
	return {}

func remove_condition(name: String) -> void:
	for i in range(active.size() - 1, -1, -1):
		if active[i].name == name:
			active.remove_at(i)
			return

func tick(delta: float) -> Array[String]:
	var expired: Array[String] = []
	for i in range(active.size() - 1, -1, -1):
		active[i].remaining -= delta
		if active[i].remaining <= 0:
			expired.append(active[i].name)
			active.remove_at(i)
	return expired
