extends GutTest

# --- StringName Constants ---

func test_element_names():
	assert_eq(ElementNames.FIRE, &"fire")
	assert_eq(ElementNames.ICE, &"ice")
	assert_eq(ElementNames.WATER, &"water")
	assert_eq(ElementNames.OIL, &"oil")
	assert_eq(ElementNames.NONE, &"")

func test_condition_names():
	assert_eq(ConditionNames.BURNING, &"burning")
	assert_eq(ConditionNames.FROZEN, &"frozen")
	assert_eq(ConditionNames.WET, &"wet")
	assert_eq(ConditionNames.OILY, &"oily")

func test_modifiers():
	assert_eq(Modifiers.NORMAL, &"normal")
	assert_eq(Modifiers.DENSE, &"dense")
	assert_eq(Modifiers.BOSS, &"boss")

func test_wall_styles():
	assert_eq(WallStyles.DEFAULT, &"default")
	assert_eq(WallStyles.FOREST_THICKET, &"forest_thicket")
	assert_eq(WallStyles.PALACE_ORNATE, &"palace_ornate")
	assert_eq(WallStyles.ICE_CRYSTAL, &"ice_crystal")

func test_light_styles():
	assert_eq(LightStyles.FLOATING, &"floating")
	assert_eq(LightStyles.TORCH, &"torch")
	assert_eq(LightStyles.MUSHROOM, &"mushroom")
	assert_eq(LightStyles.CRYSTAL, &"crystal")

func test_floor_styles():
	assert_eq(FloorStyles.PLAIN, &"plain")
	assert_eq(FloorStyles.CRACKED_SLAB, &"cracked_slab")

func test_string_name_as_dict_key():
	var d = {ElementNames.FIRE: "hot", ElementNames.ICE: "cold"}
	assert_eq(d[ElementNames.FIRE], "hot")
	assert_eq(d[&"fire"], "hot")

# --- WeaponDefinition ---

func test_weapon_definition_defaults():
	var w = WeaponDefinition.new()
	assert_eq(w.weapon_name, "")
	assert_eq(w.damage, 10)
	assert_almost_eq(w.fire_rate, 0.3, 0.001)
	assert_eq(w.element, ElementNames.NONE)

func test_weapon_definition_with_values():
	var w = WeaponDefinition.new()
	w.weapon_name = "Pistol"
	w.damage = 15
	w.element = ElementNames.FIRE
	w.build_viewmodel = func(): return Node3D.new()
	assert_eq(w.weapon_name, "Pistol")
	assert_eq(w.element, ElementNames.FIRE)

func test_weapon_definition_callable():
	var w = WeaponDefinition.new()
	w.build_viewmodel = func(): return Node3D.new()
	var result = w.build_viewmodel.call()
	assert_true(result is Node3D)
	result.free()

# --- ModifierDefinition ---

func test_modifier_definition_defaults():
	var m = ModifierDefinition.new()
	assert_eq(m.modifier_name, Modifiers.NORMAL)
	assert_eq(m.grid_width, 12)
	assert_eq(m.monsters_per_room, 1)
	assert_almost_eq(m.monster_hp_mult, 1.0, 0.001)

func test_modifier_definition_dense():
	var m = ModifierDefinition.new()
	m.modifier_name = Modifiers.DENSE
	m.monsters_per_room = 2
	m.tile_weights = {"room": 2.5, "spawn": 2.5, "cor": 0.3, "door": 0.5, "wall": 2.0, "empty": 0.5}
	assert_eq(m.modifier_name, Modifiers.DENSE)
	assert_eq(m.monsters_per_room, 2)
	assert_almost_eq(m.tile_weights["room"], 2.5, 0.001)

func test_modifier_tile_weights_keys():
	var m = ModifierDefinition.new()
	assert_true(m.tile_weights.has("room"))
	assert_true(m.tile_weights.has("wall"))
	assert_true(m.tile_weights.has("cor"))

# --- ElementDefinition ---

func test_element_definition_defaults():
	var e = ElementDefinition.new()
	assert_eq(e.element_name, ElementNames.NONE)
	assert_eq(e.condition_name, ConditionNames.NONE)
	assert_almost_eq(e.condition_duration, 3.0, 0.001)

func test_element_definition_fire():
	var e = ElementDefinition.new()
	e.element_name = ElementNames.FIRE
	e.condition_name = ConditionNames.BURNING
	e.condition_duration = 5.0
	e.default_color = Color(1.0, 0.5, 0.1)
	e.damage_per_tick = 2.0
	e.interactions = [{"combine_with": ConditionNames.OILY, "produces": ConditionNames.BURNING}]
	assert_eq(e.element_name, ElementNames.FIRE)
	assert_eq(e.condition_name, ConditionNames.BURNING)
	assert_eq(e.interactions.size(), 1)

# --- MonsterVariantDefinition ---

func test_monster_variant_defaults():
	var v = MonsterVariantDefinition.new()
	assert_eq(v.variant_name, "")
	assert_eq(v.variant_key, &"basic")
	assert_almost_eq(v.spawn_weight, 1.0, 0.001)
	assert_false(v.is_boss)

func test_monster_variant_boss():
	var v = MonsterVariantDefinition.new()
	v.variant_name = "Zmey Boss"
	v.is_boss = true
	v.spawn_weight = 0.0
	v.hp_mult = 5.0
	assert_true(v.is_boss)
	assert_almost_eq(v.spawn_weight, 0.0, 0.001)

func test_monster_variant_weighted_total():
	var variants = []
	for i in range(3):
		var v = MonsterVariantDefinition.new()
		variants.append(v)
	variants[0].spawn_weight = 2.0
	variants[1].spawn_weight = 1.0
	variants[2].spawn_weight = 1.0
	var total = 0.0
	for v in variants:
		total += v.spawn_weight
	assert_almost_eq(total, 4.0, 0.001)
