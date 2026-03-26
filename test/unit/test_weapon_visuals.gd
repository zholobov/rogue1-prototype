extends GutTest

# --- C_WeaponVisual defaults ---

func test_weapon_visual_defaults():
    var wv = C_WeaponVisual.new()
    assert_eq(wv.weapon_index, -1)
    assert_eq(wv.element, "")
    assert_eq(wv.show_viewmodel, false)
    assert_eq(wv.just_fired, false)
