extends GutTest

func test_weapon_registry_has_4_weapons():
    assert_eq(WeaponRegistry.weapon_count(), 4)

func test_weapon_registry_get_weapon():
    var w = WeaponRegistry.get_weapon(0)
    assert_not_null(w)
    assert_eq(w.weapon_name, "Pistol")
    assert_eq(w.element, ElementNames.NONE)

func test_weapon_registry_all_have_names():
    for i in range(WeaponRegistry.weapon_count()):
        var w = WeaponRegistry.get_weapon(i)
        assert_true(w.weapon_name != "", "Weapon %d should have a name" % i)

func test_weapon_registry_all_have_callables():
    for i in range(WeaponRegistry.weapon_count()):
        var w = WeaponRegistry.get_weapon(i)
        assert_true(w.build_viewmodel.is_valid(), "Weapon %d needs build_viewmodel" % i)
        assert_true(w.build_world_model.is_valid(), "Weapon %d needs build_world_model" % i)
        assert_true(w.build_hud_icon.is_valid(), "Weapon %d needs build_hud_icon" % i)

func test_weapon_registry_invalid_index():
    assert_null(WeaponRegistry.get_weapon(99))
    assert_null(WeaponRegistry.get_weapon(-1))

func test_weapon_registry_elements():
    assert_eq(WeaponRegistry.get_weapon(0).element, ElementNames.NONE)
    assert_eq(WeaponRegistry.get_weapon(1).element, ElementNames.FIRE)
    assert_eq(WeaponRegistry.get_weapon(2).element, ElementNames.ICE)
    assert_eq(WeaponRegistry.get_weapon(3).element, ElementNames.WATER)

func test_modifier_registry_has_6_modifiers():
    assert_eq(ModifierRegistry.get_all_names().size(), 6)

func test_modifier_registry_get_normal():
    var m = ModifierRegistry.get_modifier(Modifiers.NORMAL)
    assert_not_null(m)
    assert_eq(m.grid_width, 12)

func test_modifier_registry_get_dense():
    var m = ModifierRegistry.get_modifier(Modifiers.DENSE)
    assert_not_null(m)
    assert_eq(m.monsters_per_room, 2)

func test_modifier_registry_boss_has_pin_override():
    var m = ModifierRegistry.get_modifier(Modifiers.BOSS)
    assert_not_null(m)
    assert_true(m.pin_rooms_override.is_valid())

func test_modifier_registry_spawnable_excludes_boss():
    var spawnable = ModifierRegistry.get_spawnable_names()
    assert_false(Modifiers.BOSS in spawnable)
    assert_true(Modifiers.NORMAL in spawnable)
