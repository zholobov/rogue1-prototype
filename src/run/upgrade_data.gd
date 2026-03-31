class_name UpgradeData
extends RefCounted

var upgrade_name: String
var description: String
var category: String	# "stat", "weapon", "defensive"
var rarity: String		# "common", "rare", "epic"
var property: String	# C_PlayerStats field to modify
var value: float
var cost: int			# shop price (0 = reward-only)

static var _pool: Array = []

static func get_pool() -> Array:
	if _pool.is_empty():
		_pool = [
			# Stat boosts (common)
			_make("Max HP +20", "+20 max health", "stat", "common", "max_health_bonus", 20.0, 30),
			_make("Speed +15%", "+15% movement speed", "stat", "common", "speed_mult", 0.15, 30),
			_make("Damage +10%", "+10% damage", "stat", "common", "damage_mult", 0.10, 30),
			# Weapon (common)
			_make("Fire Rate +20%", "+20% fire rate", "weapon", "common", "fire_rate_bonus", 0.20, 30),
			_make("Proj Speed +25%", "+25% projectile speed", "weapon", "common", "proj_speed_bonus", 0.25, 30),
			# Defensive (rare)
			_make("HP Regen +2/s", "+2 HP per second", "defensive", "rare", "hp_regen", 2.0, 60),
			_make("Armor 15%", "-15% damage taken", "defensive", "rare", "damage_reduction", 0.15, 60),
			_make("Resist 30%", "-30% condition duration", "defensive", "rare", "condition_duration_reduction", 0.30, 60),
			# Special abilities (epic)
			_make("Dash", "Speed burst (Shift), 3s cooldown", "special", "epic", "dash", 1.0, 120),
			_make("AoE Blast", "Damage nearby enemies (Q), 8s cooldown", "special", "epic", "aoe_blast", 1.0, 120),
			_make("Lifesteal", "Heal 10% of killed enemy's max HP", "special", "epic", "lifesteal", 0.1, 120),
		]
	return _pool

static func _make(n: String, d: String, cat: String, r: String, prop: String, val: float, c: int) -> UpgradeData:
	var u = UpgradeData.new()
	u.upgrade_name = n
	u.description = d
	u.category = cat
	u.rarity = r
	u.property = prop
	u.value = val
	u.cost = c
	return u

static func roll_random(count: int, loop: int) -> Array:
	var pool = get_pool()
	var weighted: Array = []

	# Rarity weights by loop
	var weights: Dictionary
	if loop >= 1:
		weights = {"common": 0.50, "rare": 0.35, "epic": 0.15}
	else:
		weights = {"common": 0.70, "rare": 0.25, "epic": 0.05}

	# Build weighted list: include each upgrade proportional to its rarity weight
	for upgrade in pool:
		var w = weights.get(upgrade.rarity, 0.0)
		if randf() < w * 3.0:  # Scale up so most upgrades pass the filter
			weighted.append(upgrade)

	weighted.shuffle()

	# Take first `count` unique entries
	var result: Array = []
	for upgrade in weighted:
		if result.size() >= count:
			break
		if upgrade not in result:
			result.append(upgrade)

	# Fallback: if not enough, fill from full pool
	if result.size() < count:
		var shuffled = pool.duplicate()
		shuffled.shuffle()
		for upgrade in shuffled:
			if result.size() >= count:
				break
			if upgrade not in result:
				result.append(upgrade)

	return result
