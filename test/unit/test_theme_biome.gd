extends GutTest

func test_theme_group_defaults():
	var g = ThemeGroup.new()
	assert_eq(g.group_name, "")
	assert_eq(g.biomes.size(), 0)

func test_theme_group_get_biome():
	var g = ThemeGroup.new()
	var b1 = ThemeData.new()
	b1.biome_name = "Forest"
	var b2 = ThemeData.new()
	b2.biome_name = "Palace"
	g.biomes = [b1, b2]
	assert_eq(g.get_biome(0).biome_name, "Forest")
	assert_eq(g.get_biome(1).biome_name, "Palace")
	assert_eq(g.get_biome(99).biome_name, "Forest")

func test_theme_group_get_random_biome():
	var g = ThemeGroup.new()
	var b = ThemeData.new()
	b.biome_name = "Only"
	g.biomes = [b]
	assert_eq(g.get_random_biome().biome_name, "Only")

func test_theme_group_empty_returns_null():
	var g = ThemeGroup.new()
	assert_null(g.get_random_biome())
	assert_null(g.get_biome(0))

func test_theme_data_has_biome_name():
	var t = ThemeData.new()
	assert_eq(t.biome_name, "")
	t.biome_name = "Test"
	assert_eq(t.biome_name, "Test")

# --- ThemeManager group integration ---

func test_theme_manager_has_groups():
	assert_true(ThemeManager.available_groups.size() >= 2, "Should have at least 2 theme groups")

func test_theme_manager_active_group_not_null():
	assert_not_null(ThemeManager.active_group)
	assert_true(ThemeManager.active_group.biomes.size() > 0)

func test_theme_manager_set_theme_by_group_name():
	ThemeManager.set_theme("Stone Dungeon")
	assert_eq(ThemeManager.active_group.group_name, "Stone Dungeon")
	assert_eq(ThemeManager.active_theme.biome_name, "Stone")
	ThemeManager.set_theme("Neon Dungeon")

func test_theme_manager_set_biome():
	var biome = ThemeManager.active_group.biomes[0]
	ThemeManager.set_biome(biome)
	assert_eq(ThemeManager.active_theme, biome)

func test_existing_themes_have_biome_name():
	for group in ThemeManager.available_groups:
		for biome in group.biomes:
			assert_true(biome.biome_name != "", "%s should have biome_name" % group.group_name)

func test_backward_compat_available_themes():
	assert_true(ThemeManager.available_themes.size() >= 2, "Flat list should have all biomes")
	for t in ThemeManager.available_themes:
		assert_true(t is ThemeData)
