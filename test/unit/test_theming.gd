extends GutTest

# --- ThemeData defaults ---
func test_theme_data_has_name():
    var td = ThemeData.new()
    assert_eq(td.theme_name, "")

func test_theme_data_has_palette():
    var td = ThemeData.new()
    assert_ne(td.primary, Color.BLACK, "primary should have a non-black default")
    assert_typeof(td.rarity_colors, TYPE_DICTIONARY)
    assert_typeof(td.element_colors, TYPE_DICTIONARY)

func test_theme_data_has_environment():
    var td = ThemeData.new()
    assert_gt(td.fog_depth_end, td.fog_depth_begin, "fog end > begin")
    assert_gt(td.point_light_spacing, 0)

func test_theme_data_has_level_materials():
    var td = ThemeData.new()
    assert_gt(td.floor_roughness, 0.0)
    assert_gt(td.wall_roughness, 0.0)

func test_theme_data_has_monsters():
    var td = ThemeData.new()
    assert_typeof(td.monster_scenes, TYPE_DICTIONARY)
    assert_ne(td.eye_color, Color.BLACK)

func test_theme_data_has_vfx():
    var td = ThemeData.new()
    assert_ne(td.muzzle_flash_color, Color.BLACK)

func test_theme_data_has_ui():
    var td = ThemeData.new()
    assert_ne(td.ui_text_color, Color.BLACK)

func test_theme_data_get_palette_array():
    var td = ThemeData.new()
    td.primary = Color.RED
    td.secondary = Color.GREEN
    td.tertiary = Color.BLUE
    td.highlight = Color.YELLOW
    td.danger = Color.WHITE
    var arr = td.get_palette_array()
    assert_eq(arr.size(), 5)
    assert_eq(arr[0], Color.RED)

func test_theme_data_get_random_palette_color():
    var td = ThemeData.new()
    td.primary = Color.RED
    td.secondary = Color.GREEN
    td.tertiary = Color.BLUE
    td.highlight = Color.YELLOW
    td.danger = Color.WHITE
    var c = td.get_random_palette_color()
    assert_has([Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.WHITE], c)

func test_theme_data_get_element_color_known():
    var td = ThemeData.new()
    td.element_colors = {"fire": Color.RED}
    assert_eq(td.get_element_color("fire"), Color.RED)

func test_theme_data_get_element_color_unknown():
    var td = ThemeData.new()
    td.element_colors = {"fire": Color.RED}
    var c = td.get_element_color("unknown")
    assert_eq(c, Color.WHITE, "unknown elements default to white")

# --- ThemeManager ---
func test_theme_manager_has_active_theme():
    assert_not_null(ThemeManager)
    assert_not_null(ThemeManager.active_theme)

func test_theme_manager_available_themes_not_empty():
    assert_gt(ThemeManager.available_themes.size(), 0)

func test_theme_manager_set_theme_emits_signal():
    var theme_name = ThemeManager.available_themes[0].theme_name
    watch_signals(ThemeManager)
    ThemeManager.set_theme(theme_name)
    assert_signal_emitted(ThemeManager, "theme_changed")

func test_theme_manager_set_theme_changes_active():
    var first = ThemeManager.available_themes[0]
    ThemeManager.set_theme(first.theme_name)
    assert_eq(ThemeManager.active_theme.theme_name, first.theme_name)

func test_theme_manager_get_monster_scene_returns_null_for_missing():
    var scene = ThemeManager.get_monster_scene("nonexistent_type")
    assert_null(scene)

func test_theme_manager_get_palette_returns_active_palette():
    var palette = ThemeManager.get_palette()
    assert_eq(palette, ThemeManager.active_theme.get_palette_array())
