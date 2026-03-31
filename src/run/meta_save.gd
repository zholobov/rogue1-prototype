extends Node

const SAVE_PATH = "user://meta_save.json"

var meta_currency: int = 0
var best_loop: int = 0
var best_depth: int = 0
var total_kills: int = 0

# Permanent upgrade tiers: 0 = not purchased, 1-3 = tier level
var upgrades: Dictionary = {
	"tough": 0,		  # +10 max HP per tier
	"strong": 0,	  # +5% damage per tier
	"head_start": 0,  # start with N random upgrades
}

const UPGRADE_DEFS: Array = [
	{
		"id": "tough",
		"name": "Tough",
		"description": "+10 starting max HP per tier",
		"max_tier": 3,
		"costs": [100, 200, 400],
	},
	{
		"id": "strong",
		"name": "Strong",
		"description": "+5% starting damage per tier",
		"max_tier": 3,
		"costs": [100, 200, 400],
	},
	{
		"id": "head_start",
		"name": "Head Start",
		"description": "Start run with random upgrades",
		"max_tier": 3,
		"costs": [150, 300, 600],
	},
]

func _ready() -> void:
	load_data()

func save_data() -> void:
	var data = {
		"meta_currency": meta_currency,
		"best_loop": best_loop,
		"best_depth": best_depth,
		"total_kills": total_kills,
		"upgrades": upgrades,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is Dictionary:
		meta_currency = data.get("meta_currency", 0)
		best_loop = data.get("best_loop", 0)
		best_depth = data.get("best_depth", 0)
		total_kills = data.get("total_kills", 0)
		var saved_upgrades = data.get("upgrades", {})
		for key in saved_upgrades:
			if upgrades.has(key):
				upgrades[key] = saved_upgrades[key]

func on_run_ended(stats: RunStats) -> void:
	var earned = int(stats.total_currency_earned * Config.meta_currency_rate)
	meta_currency += earned
	total_kills += stats.kills
	if stats.loop > best_loop:
		best_loop = stats.loop
	if stats.levels_cleared > best_depth:
		best_depth = stats.levels_cleared
	save_data()

func purchase_upgrade(upgrade_id: String) -> bool:
	var current_tier = upgrades.get(upgrade_id, 0)
	var def = _get_def(upgrade_id)
	if not def or current_tier >= def.max_tier:
		return false
	var cost = def.costs[current_tier]
	if meta_currency < cost:
		return false
	meta_currency -= cost
	upgrades[upgrade_id] = current_tier + 1
	save_data()
	return true

func get_starting_upgrades() -> Array:
	var result: Array = []
	# Tough: +10 max HP per tier
	var tough_tier = upgrades.get("tough", 0)
	if tough_tier > 0:
		for i in range(tough_tier):
			result.append(UpgradeData._make(
				"Meta: Tough %d" % (i + 1), "+10 max HP (permanent)",
				"stat", "common", "max_health_bonus", 10.0, 0))
	# Strong: +5% damage per tier
	var strong_tier = upgrades.get("strong", 0)
	if strong_tier > 0:
		for i in range(strong_tier):
			result.append(UpgradeData._make(
				"Meta: Strong %d" % (i + 1), "+5% damage (permanent)",
				"stat", "common", "damage_mult", 0.05, 0))
	# Head Start: random upgrades
	var hs_tier = upgrades.get("head_start", 0)
	if hs_tier > 0:
		var randoms = UpgradeData.roll_random(hs_tier, 0)
		result.append_array(randoms)
	return result

func _get_def(upgrade_id: String) -> Variant:
	for def in UPGRADE_DEFS:
		if def.id == upgrade_id:
			return def
	return null
