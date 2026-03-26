extends GutTest

func test_theme_data_has_ceiling_default():
    var t = ThemeData.new()
    assert_true(t.has_ceiling)
    assert_eq(t.wall_style, "default")
    assert_eq(t.sky_config.size(), 0)
