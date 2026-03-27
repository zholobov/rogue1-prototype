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
