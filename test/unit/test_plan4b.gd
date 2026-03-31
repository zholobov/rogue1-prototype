extends GutTest

# --- C_BossAI defaults ---
func test_boss_ai_defaults():
	var b = C_BossAI.new()
	assert_eq(b.ranged_cooldown, 2.0)
	assert_eq(b.ranged_cooldown_remaining, 0.0)
	assert_eq(b.projectile_damage, 15)
	assert_eq(b.projectile_speed, 20.0)

# --- C_Dash defaults ---
func test_dash_defaults():
	var d = C_Dash.new()
	assert_eq(d.cooldown, 3.0)
	assert_eq(d.dash_speed, 20.0)
	assert_eq(d.dash_duration, 0.15)

# --- C_AoEBlast defaults ---
func test_aoe_blast_defaults():
	var a = C_AoEBlast.new()
	assert_eq(a.cooldown, 8.0)
	assert_eq(a.damage, 30)
	assert_eq(a.radius, 5.0)

# --- C_Lifesteal defaults ---
func test_lifesteal_defaults():
	var l = C_Lifesteal.new()
	assert_almost_eq(l.percent, 0.1, 0.001)

# --- UpgradeData pool has special abilities ---
func test_upgrade_pool_has_specials():
	UpgradeData._pool.clear()  # Force fresh pool
	var pool = UpgradeData.get_pool()
	var names: PackedStringArray = []
	for u in pool:
		names.append(u.upgrade_name)
	assert_has(names, "Dash")
	assert_has(names, "AoE Blast")
	assert_has(names, "Lifesteal")

func test_upgrade_pool_specials_are_epic():
	UpgradeData._pool.clear()
	var pool = UpgradeData.get_pool()
	for u in pool:
		if u.upgrade_name in ["Dash", "AoE Blast", "Lifesteal"]:
			assert_eq(u.rarity, "epic", "%s should be epic" % u.upgrade_name)

# --- RunStats loop tracking ---
func test_run_stats_loop_default():
	var s = RunStats.new()
	assert_eq(s.loop, 0)

func test_run_stats_reset_clears_loop():
	var s = RunStats.new()
	s.loop = 3
	s.reset()
	assert_eq(s.loop, 0)

# --- C_PlayerStats recalculate with meta upgrades ---
func test_player_stats_stacks_meta_upgrades():
	var ps = C_PlayerStats.new()
	var upgrades = [
		UpgradeData._make("Meta: Tough 1", "", "stat", "common", "max_health_bonus", 10.0, 0),
		UpgradeData._make("Meta: Strong 1", "", "stat", "common", "damage_mult", 0.05, 0),
		UpgradeData._make("Damage +10%", "", "stat", "common", "damage_mult", 0.10, 0),
	]
	ps.recalculate(upgrades)
	assert_eq(ps.max_health_bonus, 10)
	assert_almost_eq(ps.damage_mult, 1.15, 0.001)  # 1.0 + 0.05 + 0.10

# --- MetaSave round-trip ---
func test_meta_save_starting_upgrades_tough():
	# Test that Tough tier generates correct starting upgrades
	# (Can't test actual save/load without autoload, but can test get_starting_upgrades logic)
	var ms = preload("res://src/run/meta_save.gd").new()
	ms.upgrades["tough"] = 2
	var starting = ms.get_starting_upgrades()
	var hp_bonus = 0
	for u in starting:
		if u.property == "max_health_bonus":
			hp_bonus += int(u.value)
	assert_eq(hp_bonus, 20, "Tough tier 2 should give +20 max HP (10 per tier)")
