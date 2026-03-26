extends GutTest

func test_theme_data_has_ceiling_default():
    var t = ThemeData.new()
    assert_true(t.has_ceiling)
    assert_eq(t.wall_style, "default")
    assert_eq(t.sky_config.size(), 0)

func test_folk_theme_group_exists():
    var found = false
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            found = true
            assert_eq(group.biomes.size(), 3)
    assert_true(found, "Folk Tales group should be registered")

func test_folk_biomes_have_names():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_eq(group.biomes[0].biome_name, "Dark Forest")
            assert_eq(group.biomes[1].biome_name, "Golden Palace")
            assert_eq(group.biomes[2].biome_name, "Winter Realm")

func test_dark_forest_has_no_ceiling():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_false(group.biomes[0].has_ceiling)
            assert_eq(group.biomes[0].wall_style, "forest_thicket")

func test_golden_palace_has_ceiling():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_true(group.biomes[1].has_ceiling)
            assert_eq(group.biomes[1].wall_style, "palace_ornate")

func test_winter_realm_has_no_ceiling():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_false(group.biomes[2].has_ceiling)
            assert_eq(group.biomes[2].wall_style, "ice_crystal")

func test_folk_biomes_have_monster_scenes():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            for biome in group.biomes:
                assert_true(biome.monster_scenes.has("basic"), "%s needs basic" % biome.biome_name)
                assert_true(biome.monster_scenes.has("variant1"), "%s needs variant1" % biome.biome_name)
                assert_true(biome.monster_scenes.has("variant2"), "%s needs variant2" % biome.biome_name)
                assert_true(biome.monster_scenes.has("boss"), "%s needs boss" % biome.biome_name)

func test_folk_biomes_have_sky_config():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_true(group.biomes[0].sky_config.size() > 0, "Dark Forest needs sky_config")
            assert_eq(group.biomes[1].sky_config.size(), 0, "Golden Palace has ceiling, no sky")
            assert_true(group.biomes[2].sky_config.size() > 0, "Winter Realm needs sky_config")
