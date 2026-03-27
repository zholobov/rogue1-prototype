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
    assert_typeof(td.monster_variants, TYPE_ARRAY)
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

func test_theme_get_monster_scene_basic():
    var scene = ThemeManager.get_monster_scene("basic")
    assert_not_null(scene, "Neon should have a basic monster scene")

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

# --- UI theming ---
func test_neon_theme_ui_background():
    var theme = ThemeManager.active_theme
    assert_almost_eq(theme.ui_background_color.r, 0.05, 0.01)

func test_neon_theme_rarity_colors():
    var theme = ThemeManager.active_theme
    assert_true(theme.rarity_colors.has("common"))
    assert_true(theme.rarity_colors.has("rare"))
    assert_true(theme.rarity_colors.has("epic"))

func test_neon_palette_file_removed():
    assert_false(FileAccess.file_exists("res://src/effects/neon_palette.gd"),
        "neon_palette.gd should be deleted")

# --- Stone Theme ---
func test_stone_theme_exists():
    var found = false
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            found = true
    assert_true(found, "Stone Dungeon theme should be registered")

func test_stone_theme_palette_is_warm():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    # Primary should be warm gold
    assert_gt(stone.primary.r, 0.7, "primary should be warm/red-heavy")
    assert_gt(stone.primary.g, 0.5, "primary should have golden green")

func test_stone_theme_fog_is_closer():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_lt(stone.fog_depth_end, 50.0, "stone fog should not be infinite")

func test_stone_theme_has_textures():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_gt(stone.floor_pattern.size(), 0, "stone should define floor texture")
    assert_gt(stone.wall_pattern.size(), 0, "stone should define wall texture")

func test_stone_theme_textures_generate():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    var textures = TextureFactory.generate_for_theme(stone)
    assert_true(textures.has("floor"), "should generate floor texture")
    assert_true(textures.has("wall"), "should generate wall texture")

# --- Neon Monster Scenes ---
func test_neon_monster_basic_scene_loads():
    var scene = load("res://themes/neon/monster_basic.tscn")
    assert_not_null(scene)

func test_neon_monster_basic_has_body_mesh():
    var scene = load("res://themes/neon/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("BodyMesh"))
    instance.queue_free()

func test_neon_monster_basic_has_health_bar_anchor():
    var scene = load("res://themes/neon/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("HealthBarAnchor"))
    instance.queue_free()

func test_neon_monster_boss_scene_loads():
    var scene = load("res://themes/neon/monster_boss.tscn")
    assert_not_null(scene)

func test_neon_theme_has_monster_variants():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    var keys: Array = []
    for v in neon.monster_variants:
        keys.append(v.variant_key)
    assert_true(&"basic" in keys)
    assert_true(&"boss" in keys)

# --- Stone Monster Scenes ---
func test_stone_monster_basic_scene_loads():
    var scene = load("res://themes/stone/monster_basic.tscn")
    assert_not_null(scene)

func test_stone_monster_basic_has_body_mesh():
    var scene = load("res://themes/stone/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("BodyMesh"))
    instance.queue_free()

func test_stone_monster_basic_has_health_bar_anchor():
    var scene = load("res://themes/stone/monster_basic.tscn")
    var instance = scene.instantiate()
    assert_not_null(instance.get_node_or_null("HealthBarAnchor"))
    instance.queue_free()

func test_stone_monster_boss_scene_loads():
    var scene = load("res://themes/stone/monster_boss.tscn")
    assert_not_null(scene)

func test_stone_theme_has_monster_variants():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    var keys: Array = []
    for v in stone.monster_variants:
        keys.append(v.variant_key)
    assert_true(&"basic" in keys)
    assert_true(&"boss" in keys)

# --- Theme Selector ---
func test_theme_selector_instantiates():
    var selector = preload("res://src/ui/theme_selector.gd").new()
    assert_not_null(selector)
    selector.queue_free()

# --- Integration ---
func test_switch_to_stone_and_back():
    ThemeManager.set_theme("Stone Dungeon")
    assert_eq(ThemeManager.active_theme.theme_name, "Stone Dungeon")
    ThemeManager.set_theme("Neon Dungeon")
    assert_eq(ThemeManager.active_theme.theme_name, "Neon Dungeon")

func test_all_themes_have_required_fields():
    for t in ThemeManager.available_themes:
        assert_ne(t.theme_name, "", "%s needs a name" % t)
        assert_ne(t.description, "", "%s needs a description" % t)
        assert_gt(t.get_palette_array().size(), 0, "%s needs palette colors" % t.theme_name)
        assert_gt(t.fog_depth_end, t.fog_depth_begin, "%s fog end > begin" % t.theme_name)

func test_all_themes_have_monster_variants():
    for t in ThemeManager.available_themes:
        var keys: Array = []
        for v in t.monster_variants:
            keys.append(v.variant_key)
        assert_true(&"basic" in keys, "%s needs basic monster variant" % t.theme_name)
        assert_true(&"boss" in keys, "%s needs boss monster variant" % t.theme_name)

func test_texture_cache_updates_on_theme_switch():
    ThemeManager.set_theme("Stone Dungeon")
    var cache = TextureFactory.get_cached()
    if ThemeManager.active_theme.floor_pattern.size() > 0:
        assert_true(cache.has("floor"), "stone theme should have cached floor texture")
    ThemeManager.set_theme("Neon Dungeon")

func test_theme_changed_signal_carries_theme():
    var result := [null]
    var callback = func(t): result[0] = t
    ThemeManager.theme_changed.connect(callback)
    ThemeManager.set_theme("Stone Dungeon")
    assert_not_null(result[0])
    assert_eq(result[0].theme_name, "Stone Dungeon")
    ThemeManager.theme_changed.disconnect(callback)
    ThemeManager.set_theme("Neon Dungeon")

func test_theme_data_has_corridor_floor_pattern():
    var td = ThemeData.new()
    assert_typeof(td.corridor_floor_pattern, TYPE_DICTIONARY)
    assert_eq(td.corridor_floor_pattern.size(), 0)

func test_theme_data_has_ceiling_pattern():
    var td = ThemeData.new()
    assert_typeof(td.ceiling_pattern, TYPE_DICTIONARY)
    assert_eq(td.ceiling_pattern.size(), 0)

func test_theme_data_has_prop_density():
    var td = ThemeData.new()
    assert_eq(td.prop_density, 0.0)

func test_theme_data_has_torch_flicker():
    var td = ThemeData.new()
    assert_true(td.torch_flicker)

func test_theme_data_has_ceiling_beam_spacing():
    var td = ThemeData.new()
    assert_eq(td.ceiling_beam_spacing, 2)

func test_theme_data_has_pillar_chance():
    var td = ThemeData.new()
    assert_almost_eq(td.pillar_chance, 0.2, 0.01)

func test_theme_data_has_rubble_chance():
    var td = ThemeData.new()
    assert_almost_eq(td.rubble_chance, 0.15, 0.01)

func test_theme_data_has_room_prop_min_max():
    var td = ThemeData.new()
    assert_eq(td.room_prop_min, 1)
    assert_eq(td.room_prop_max, 3)

func test_texture_factory_flagstone_pattern():
    var params = {
        "type": "image_gen",
        "pattern": "flagstone",
        "color1": Color(0.45, 0.4, 0.35),
        "color2": Color(0.15, 0.12, 0.1),
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is ImageTexture)

func test_texture_factory_cobblestone_pattern():
    var params = {
        "type": "image_gen",
        "pattern": "cobblestone",
        "color1": Color(0.4, 0.38, 0.35),
        "color2": Color(0.2, 0.18, 0.15),
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is ImageTexture)

func test_texture_factory_ashlar_pattern():
    var params = {
        "type": "image_gen",
        "pattern": "ashlar",
        "color1": Color(0.4, 0.35, 0.3),
        "color2": Color(0.15, 0.12, 0.1),
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is ImageTexture)

func test_texture_factory_slabs_pattern():
    var params = {
        "type": "image_gen",
        "pattern": "slabs",
        "color1": Color(0.35, 0.33, 0.3),
        "color2": Color(0.15, 0.12, 0.1),
        "width": 64,
        "height": 64,
    }
    var tex = TextureFactory.generate_texture(params)
    assert_not_null(tex)
    assert_true(tex is ImageTexture)

func test_texture_factory_generate_for_theme_corridor_floor():
    var td = ThemeData.new()
    td.corridor_floor_pattern = {"type": "image_gen", "pattern": "cobblestone", "color1": Color.GRAY, "color2": Color.BLACK, "width": 64, "height": 64}
    var textures = TextureFactory.generate_for_theme(td)
    assert_true(textures.has("corridor_floor"))

func test_texture_factory_generate_for_theme_ceiling():
    var td = ThemeData.new()
    td.ceiling_pattern = {"type": "image_gen", "pattern": "slabs", "color1": Color.GRAY, "color2": Color.BLACK, "width": 64, "height": 64}
    var textures = TextureFactory.generate_for_theme(td)
    assert_true(textures.has("ceiling"))

func test_stone_theme_accent_use_palette_false():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_false(stone.accent_use_palette, "stone should not use emissive accent strips")

func test_stone_theme_has_corridor_floor_pattern():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_gt(stone.corridor_floor_pattern.size(), 0)
    assert_eq(stone.corridor_floor_pattern["pattern"], "cobblestone")

func test_stone_theme_has_ceiling_pattern():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_gt(stone.ceiling_pattern.size(), 0)
    assert_eq(stone.ceiling_pattern["pattern"], "slabs")

func test_stone_theme_prop_density():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_eq(stone.prop_density, 1.0)

func test_stone_theme_textures_generate_corridor_and_ceiling():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    var textures = TextureFactory.generate_for_theme(stone)
    assert_true(textures.has("corridor_floor"), "should generate corridor floor texture")
    assert_true(textures.has("ceiling"), "should generate ceiling texture")

func test_stone_theme_floor_pattern_is_flagstone():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_eq(stone.floor_pattern["pattern"], "flagstone")

func test_stone_theme_prop_density_nonzero():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_gt(stone.prop_density, 0.0, "stone should have props enabled")
    assert_false(stone.accent_use_palette, "stone should use wall trim not accent strips")

func test_neon_theme_prop_density_zero():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_eq(neon.prop_density, 0.0, "neon should not spawn props")
    assert_true(neon.accent_use_palette, "neon should use emissive accent strips")

# --- HUD ThemeData properties ---
func test_theme_data_has_ui_crosshair_color():
    var td = ThemeData.new()
    assert_eq(td.ui_crosshair_color, Color(1.0, 1.0, 1.0))

func test_theme_data_has_ui_minimap_room():
    var td = ThemeData.new()
    assert_almost_eq(td.ui_minimap_room.r, 0.15, 0.01)
    assert_almost_eq(td.ui_minimap_room.g, 0.15, 0.01)
    assert_almost_eq(td.ui_minimap_room.b, 0.2, 0.01)

func test_theme_data_has_ui_minimap_wall():
    var td = ThemeData.new()
    assert_almost_eq(td.ui_minimap_wall.r, 0.3, 0.01)
    assert_almost_eq(td.ui_minimap_wall.g, 0.3, 0.01)
    assert_almost_eq(td.ui_minimap_wall.b, 0.4, 0.01)

func test_theme_data_has_ui_kill_feed_color():
    var td = ThemeData.new()
    assert_eq(td.ui_kill_feed_color, Color(1.0, 1.0, 1.0))

func test_stone_theme_hud_crosshair_color():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_almost_eq(stone.ui_crosshair_color.r, 0.9, 0.01)
    assert_almost_eq(stone.ui_crosshair_color.g, 0.85, 0.01)
    assert_almost_eq(stone.ui_crosshair_color.b, 0.7, 0.01)

func test_stone_theme_hud_minimap_room():
    var stone: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Stone Dungeon":
            stone = t
    assert_almost_eq(stone.ui_minimap_room.r, 0.2, 0.01)
    assert_almost_eq(stone.ui_minimap_room.g, 0.18, 0.01)
    assert_almost_eq(stone.ui_minimap_room.b, 0.15, 0.01)

func test_neon_theme_hud_kill_feed_color():
    var neon: ThemeData
    for t in ThemeManager.available_themes:
        if t.theme_name == "Neon Dungeon":
            neon = t
    assert_almost_eq(neon.ui_kill_feed_color.r, 0.0, 0.01)
    assert_almost_eq(neon.ui_kill_feed_color.g, 0.83, 0.01)
    assert_almost_eq(neon.ui_kill_feed_color.b, 1.0, 0.01)

func test_all_themes_have_hud_properties():
    for t in ThemeManager.available_themes:
        assert_ne(t.ui_crosshair_color, Color.BLACK, "%s needs crosshair color" % t.theme_name)
        assert_ne(t.ui_minimap_wall, Color.BLACK, "%s needs minimap wall color" % t.theme_name)

# --- HUD smoke tests ---
func test_hud_scene_instantiates():
    var scene = preload("res://src/ui/hud.tscn")
    var hud = scene.instantiate()
    assert_not_null(hud)
    # Add to tree so _ready fires
    add_child(hud)
    # Verify key child nodes were created
    await get_tree().process_frame
    assert_true(hud.has_method("setup_minimap"), "HUD should have setup_minimap method")
    assert_true(hud.has_method("show_boss_bar"), "HUD should have show_boss_bar method")
    assert_true(hud.has_method("on_actor_died"), "HUD should have on_actor_died method")
    hud.queue_free()

func test_crosshair_manager_instantiates():
    var cm = CrosshairManager.new()
    assert_not_null(cm)
    add_child(cm)
    cm.set_weapon(0, "")
    cm.set_weapon(1, "fire")
    cm.set_weapon(2, "ice")
    cm.set_weapon(3, "water")
    cm.queue_free()

func test_ability_indicator_instantiates():
    var ai = AbilityIndicator.new()
    assert_not_null(ai)
    add_child(ai)
    ai.setup("TEST", 5.0)
    ai.update_state(2.5)
    ai.update_state(0.0)
    ai.update_state(0.0, true)
    ai.queue_free()

func test_minimap_instantiates():
    var mm = Minimap.new()
    assert_not_null(mm)
    add_child(mm)
    mm.setup({"grid": [["room", "wall"], ["corridor_h", "empty"]], "width": 2, "height": 2})
    mm.queue_free()

func test_damage_number_factory_creates_floating_text():
    var ft = DamageNumberFactory.create("fire")
    assert_not_null(ft)
    assert_true(ft is FloatingText)
    ft.queue_free()
