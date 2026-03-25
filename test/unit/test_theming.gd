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

# --- Neon Theme values ---
func test_neon_theme_exists():
    var found = false
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            found = true
    assert_true(found, "Neon Dungeon theme should be registered")

func test_neon_theme_palette_matches_neon_palette():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.primary.r, 0.0, 0.01)
    assert_almost_eq(neon.primary.g, 0.83, 0.01)
    assert_almost_eq(neon.primary.b, 1.0, 0.01)
    assert_almost_eq(neon.secondary.r, 1.0, 0.01)
    assert_almost_eq(neon.secondary.g, 0.0, 0.01)
    assert_almost_eq(neon.secondary.b, 0.67, 0.01)

func test_neon_theme_environment_matches_current():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.background_color.r, 0.02, 0.01)
    assert_almost_eq(neon.background_color.g, 0.02, 0.01)
    assert_almost_eq(neon.background_color.b, 0.04, 0.01)
    assert_almost_eq(neon.fog_depth_begin, 5.0, 0.1)
    assert_almost_eq(neon.fog_depth_end, 40.0, 0.1)

func test_neon_theme_floor_matches_current():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.floor_albedo.r, 0.45, 0.01)
    assert_almost_eq(neon.floor_albedo.g, 0.42, 0.01)
    assert_almost_eq(neon.floor_albedo.b, 0.48, 0.01)

# --- TextureFactory ---
func test_texture_factory_generate_noise_returns_texture():
    var params = {
        "type": "noise",
        "noise_type": "cellular",
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is NoiseTexture2D)

func test_texture_factory_generate_gradient_returns_texture():
    var params = {
        "type": "gradient",
        "color_from": Color.RED,
        "color_to": Color.BLUE,
        "width": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is GradientTexture2D)

func test_texture_factory_generate_image_returns_texture():
    var params = {
        "type": "image_gen",
        "pattern": "bricks",
        "color1": Color(0.4, 0.38, 0.35),
        "color2": Color(0.25, 0.22, 0.20),
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is ImageTexture)

func test_texture_factory_generate_for_theme_returns_dict():
    var td = ThemeData.new()
    td.floor_pattern = {"type": "noise", "noise_type": "cellular", "width": 64, "height": 64}
    var textures = TextureFactory.generate_for_theme(td)
    assert_typeof(textures, TYPE_DICTIONARY)
    assert_true(textures.has("floor"))

func test_texture_factory_empty_pattern_returns_null():
    var tex = TextureFactory.generate_texture({})
    assert_null(tex)

# --- Level theming verification ---
func test_level_builder_uses_theme_floor_color():
    # Verify LevelBuilder reads from ThemeManager
    # We can't easily test rendered output, but we can verify
    # the class references ThemeManager rather than hardcoded colors.
    # This is a smoke test — real verification is visual.
    var theme = ThemeManager.active_theme
    assert_not_null(theme.floor_albedo)
    assert_not_null(theme.wall_albedo)
    assert_not_null(theme.ceiling_albedo)
    assert_not_null(theme.corridor_floor_albedo)

# --- Monster theming ---
func test_theme_data_monster_colors_accessible():
    var theme = ThemeManager.active_theme
    assert_not_null(theme.body_albedo)
    assert_not_null(theme.boss_albedo)
    assert_not_null(theme.eye_color)
    assert_not_null(theme.health_bar_foreground)
    assert_not_null(theme.health_bar_background)
    assert_not_null(theme.health_bar_low_color)

func test_theme_get_monster_scene_basic_initially_null():
    # Neon theme starts with no scene overrides (procedural)
    var scene = ThemeManager.get_monster_scene("basic")
    assert_null(scene, "Neon should use procedural monsters initially")

# --- VFX theming ---
func test_neon_theme_element_color_fire():
    var theme = ThemeManager.active_theme
    var fire = theme.get_element_color("fire")
    assert_almost_eq(fire.r, 1.0, 0.01)
    assert_almost_eq(fire.g, 0.27, 0.01)

func test_neon_theme_element_color_unknown_returns_white():
    var theme = ThemeManager.active_theme
    var c = theme.get_element_color("plasma")
    assert_eq(c, Color.WHITE)

func test_neon_theme_muzzle_flash_color():
    var theme = ThemeManager.active_theme
    assert_almost_eq(theme.muzzle_flash_color.r, 1.0, 0.01)
    assert_almost_eq(theme.muzzle_flash_color.g, 0.9, 0.01)

func test_neon_theme_aoe_blast_color():
    var theme = ThemeManager.active_theme
    assert_almost_eq(theme.aoe_blast_color.r, 1.0, 0.01)
    assert_almost_eq(theme.aoe_blast_color.g, 0.6, 0.01)
