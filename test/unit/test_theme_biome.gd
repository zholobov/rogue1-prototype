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
