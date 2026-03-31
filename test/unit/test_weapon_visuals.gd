extends GutTest

# --- C_WeaponVisual defaults ---

func test_weapon_visual_defaults():
	var wv = C_WeaponVisual.new()
	assert_eq(wv.weapon_index, -1)
	assert_eq(wv.element, "")
	assert_eq(wv.show_viewmodel, false)
	assert_eq(wv.just_fired, false)

# --- WeaponRegistry build callables ---

func test_registry_build_viewmodel_pistol():
	var model = WeaponRegistry.get_weapon(0).build_viewmodel.call()
	assert_not_null(model)
	assert_true(model is Node3D)
	assert_eq(model.name, "WeaponViewmodel")
	# Should have MuzzlePoint
	var muzzle = model.get_node_or_null("MuzzlePoint")
	assert_not_null(muzzle, "Viewmodel should have MuzzlePoint")
	# Should have multiple mesh children
	assert_true(model.get_child_count() >= 10, "Pistol should have 10+ primitives")
	model.queue_free()

func test_registry_build_viewmodel_all_weapons():
	for i in range(WeaponRegistry.weapon_count()):
		var model = WeaponRegistry.get_weapon(i).build_viewmodel.call()
		assert_not_null(model, "Weapon %d viewmodel should exist" % i)
		var muzzle = model.get_node_or_null("MuzzlePoint")
		assert_not_null(muzzle, "Weapon %d should have MuzzlePoint" % i)
		model.queue_free()

func test_registry_build_world_model():
	var model = WeaponRegistry.get_weapon(0).build_world_model.call()
	assert_not_null(model)
	assert_eq(model.name, "WeaponWorldModel")
	assert_true(model.get_child_count() >= 4, "World model should have 4+ primitives")
	model.queue_free()

func test_registry_build_hud_icon():
	var icon = WeaponRegistry.get_weapon(0).build_hud_icon.call()
	assert_not_null(icon)
	assert_true(icon is Control)
	assert_true(icon.get_child_count() >= 3, "HUD icon should have 3+ ColorRects")
	icon.queue_free()

func test_registry_element_glow():
	var model = WeaponRegistry.get_weapon(1).build_viewmodel.call()
	assert_not_null(model)
	# Check that at least one child has emission enabled
	var has_emission = false
	for child in model.get_children():
		if child is MeshInstance3D and child.material_override:
			var mat = child.material_override as StandardMaterial3D
			if mat and mat.emission_enabled:
				has_emission = true
				break
	assert_true(has_emission, "Fire weapon should have emissive accent")
	model.queue_free()

func test_registry_invalid_index_returns_null():
	assert_null(WeaponRegistry.get_weapon(99))

# --- S_WeaponVisual smoke ---

func test_weapon_visual_system_instantiates():
	var sys = S_WeaponVisual.new()
	assert_not_null(sys)

# --- Monster weapon config ---

func test_monster_weapon_config_defaults():
	assert_almost_eq(Config.monster_weapon_chance, 0.0, 0.001)
	assert_almost_eq(Config.monster_ranged_cooldown, 3.0, 0.001)
	assert_eq(Config.monster_ranged_damage, 8)
