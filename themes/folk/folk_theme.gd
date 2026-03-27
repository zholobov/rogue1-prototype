class_name FolkTheme

static func create_group() -> ThemeGroup:
    var group = ThemeGroup.new()
    group.group_name = "Russian Folk Tales"
    group.description = "Three biomes from Russian mythology"
    group.biomes = [_create_dark_forest(), _create_golden_palace(), _create_winter_realm()]
    return group

static func _apply_shared_properties(t: ThemeData) -> void:
    # Shared element colors (section 4)
    t.element_colors = {
        ElementNames.NONE: Color.WHITE,
        ElementNames.FIRE: Color(1.0, 0.5, 0.1),
        ElementNames.ICE: Color(0.0, 0.8, 1.0),
        ElementNames.WATER: Color(0.0, 0.5, 1.0),
        ElementNames.OIL: Color(0.2, 0.15, 0.05),
    }

    # Shared rarity colors (section 4)
    t.rarity_colors = {
        "common": Color(0.85, 0.8, 0.7),
        "rare": Color(0.8, 0.15, 0.1),
        "epic": Color(0.9, 0.75, 0.2),
    }

    # Shared UI colors (section 4)
    t.ui_background_color = Color(0.1, 0.07, 0.04)
    t.ui_panel_color = Color(0.15, 0.1, 0.06)
    t.ui_text_color = Color(0.9, 0.82, 0.65)
    t.ui_accent_color = Color(0.85, 0.65, 0.2)
    t.ui_damage_flash_color = Color(0.8, 0.0, 0.0, 0.3)
    t.ui_crosshair_color = Color(0.9, 0.8, 0.6)
    t.ui_minimap_room = Color(0.6, 0.55, 0.45)
    t.ui_minimap_wall = Color(0.2, 0.15, 0.1)
    t.ui_kill_feed_color = Color(0.85, 0.65, 0.2)

static func _create_dark_forest() -> ThemeData:
    var t = ThemeData.new()

    # Meta
    t.theme_name = "Russian Folk Tales"
    t.biome_name = "Dark Forest"
    t.description = "Dense primeval forest haunted by Baba Yaga and forest spirits"

    # Shared properties
    _apply_shared_properties(t)

    # Palette (section 5)
    t.primary = Color(0.2, 0.5, 0.2)       # moss green
    t.secondary = Color(0.4, 0.2, 0.55)    # mystic purple
    t.tertiary = Color(0.35, 0.25, 0.15)   # bark brown
    t.highlight = Color(1.0, 0.4, 0.2)     # firebird orange
    t.danger = Color(0.3, 0.8, 0.1)        # poison green

    # Environment (section 5)
    t.background_color = Color(0.02, 0.04, 0.02)
    t.ambient_color = Color(0.2, 0.3, 0.15)
    t.ambient_energy = 0.6
    t.fog_color = Color(0.1, 0.15, 0.08)
    t.fog_density = 0.015
    t.fog_depth_begin = 5.0
    t.fog_depth_end = 35.0
    t.directional_light_color = Color(0.3, 0.4, 0.2)
    t.directional_light_energy = 0.6
    t.point_light_color = Color(0.3, 0.5, 0.2)
    t.point_light_energy = 3.5
    t.point_light_range_mult = 1.8
    t.point_light_attenuation = 2.0
    t.point_light_spacing = 3

    # Level Structure (section 5)
    t.has_ceiling = false
    t.wall_style = WallStyles.FOREST_THICKET
    t.light_source_style = LightStyles.MUSHROOM
    t.sky_config = {
        "sky_top_color": Color(0.08, 0.15, 0.08),
        "sky_horizon_color": Color(0.15, 0.25, 0.12),
        "ground_bottom_color": Color(0.05, 0.08, 0.04),
        "ground_horizon_color": Color(0.1, 0.15, 0.08),
        "sun_angle_max": 25.0,
        "sun_energy": 0.3,
    }

    # Level Materials (section 5)
    t.floor_albedo = Color(0.15, 0.25, 0.12)       # mossy dark green
    t.floor_roughness = 0.85
    t.corridor_floor_albedo = Color(0.12, 0.2, 0.1)
    t.corridor_floor_roughness = 0.9
    t.wall_albedo = Color(0.25, 0.18, 0.1)          # bark brown
    t.wall_roughness = 0.9
    t.ceiling_albedo = Color(0.1, 0.1, 0.08)        # unused, no ceiling
    t.ceiling_roughness = 0.9
    t.accent_emission_energy = 0.5
    t.accent_use_palette = false  # no neon strips — forest uses moss glow from wall builder

    # Textures (section 5)
    t.floor_pattern = {
        "type": "image_gen",
        "pattern": "cobblestone",
        "color1": Color(0.15, 0.25, 0.12),
        "color2": Color(0.08, 0.12, 0.06),
        "width": 256,
        "height": 256,
    }
    t.corridor_floor_pattern = {
        "type": "image_gen",
        "pattern": "cobblestone",
        "color1": Color(0.12, 0.2, 0.1),
        "color2": Color(0.06, 0.1, 0.05),
        "width": 256,
        "height": 256,
    }
    t.wall_pattern = {
        "type": "image_gen",
        "pattern": "ashlar",
        "color1": Color(0.25, 0.18, 0.1),
        "color2": Color(0.15, 0.1, 0.05),
        "width": 256,
        "height": 256,
    }
    t.ceiling_pattern = {}
    t.monster_skin = {
        "type": "noise",
        "noise_type": "simplex",
        "frequency": 0.15,
        "octaves": 3,
        "width": 128,
        "height": 128,
    }

    # Props (section 5)
    t.prop_density = 0.5
    t.torch_flicker = true
    t.floor_style = FloorStyles.PLAIN
    t.beam_style = "none"
    t.ceiling_beam_spacing = 4  # unused, no ceiling, set for compat
    t.pillar_chance = 0.3
    t.rubble_chance = 0.4
    t.room_prop_min = 1
    t.room_prop_max = 3

    # Monsters (section 5)
    t.body_albedo = Color(0.2, 0.3, 0.15)       # bark green
    t.body_emission = Color(0.15, 0.3, 0.1)     # subtle moss glow
    t.boss_albedo = Color(0.15, 0.25, 0.1)
    t.boss_emission = Color(0.2, 0.5, 0.15)     # stronger green glow
    t.eye_color = Color(1.0, 0.4, 0.2)          # firebird orange

    # Health Bars (section 5)
    t.health_bar_foreground = Color(0.2, 0.7, 0.15)
    t.health_bar_background = Color(0.1, 0.1, 0.08)
    t.health_bar_low_color = Color(0.8, 0.2, 0.1)

    # VFX (section 5)
    t.muzzle_flash_color = Color(0.3, 0.8, 0.2)
    t.impact_color = Color(0.2, 0.6, 0.15)
    t.death_color = Color(0.4, 0.2, 0.55)       # purple burst
    t.aoe_blast_color = Color(0.3, 0.7, 0.2)

    # Projectile (section 5)
    t.projectile_color = Color(0.3, 0.6, 0.2)
    t.projectile_trail_color = Color(0.2, 0.5, 0.15)

    # Monster variants (section 9)
    var df_basic = MonsterVariantDefinition.new()
    df_basic.variant_name = "Leshy"
    df_basic.variant_key = &"basic"
    df_basic.scene = load("res://themes/folk/leshy_basic.tscn")
    df_basic.spawn_weight = 2.0
    t.monster_variants.append(df_basic)

    var df_v1 = MonsterVariantDefinition.new()
    df_v1.variant_name = "Kikimora"
    df_v1.variant_key = &"variant1"
    df_v1.scene = load("res://themes/folk/kikimora_basic.tscn")
    df_v1.spawn_weight = 1.0
    t.monster_variants.append(df_v1)

    var df_v2 = MonsterVariantDefinition.new()
    df_v2.variant_name = "Vodyanoy"
    df_v2.variant_key = &"variant2"
    df_v2.scene = load("res://themes/folk/vodyanoy_basic.tscn")
    df_v2.spawn_weight = 1.0
    t.monster_variants.append(df_v2)

    var df_boss = MonsterVariantDefinition.new()
    df_boss.variant_name = "Leshy Boss"
    df_boss.variant_key = Modifiers.BOSS
    df_boss.scene = load("res://themes/folk/leshy_boss.tscn")
    df_boss.is_boss = true
    df_boss.spawn_weight = 0.0
    t.monster_variants.append(df_boss)

    return t

static func _create_golden_palace() -> ThemeData:
    var t = ThemeData.new()

    # Meta
    t.theme_name = "Russian Folk Tales"
    t.biome_name = "Golden Palace"
    t.description = "Ornate golden palace halls from the bylina epics"

    # Shared properties
    _apply_shared_properties(t)

    # Palette (section 6)
    t.primary = Color(0.85, 0.65, 0.2)     # bright gold
    t.secondary = Color(0.3, 0.2, 0.1)     # dark wood
    t.tertiary = Color(0.9, 0.85, 0.75)    # birch white
    t.highlight = Color(0.8, 0.13, 0.0)    # warrior red
    t.danger = Color(0.7, 0.1, 0.1)        # blood red

    # Environment (section 6) — warm bright palace interior
    t.background_color = Color(0.06, 0.04, 0.02)
    t.ambient_color = Color(0.35, 0.25, 0.15)
    t.ambient_energy = 0.6
    t.fog_color = Color(0.15, 0.1, 0.05)
    t.fog_density = 0.01
    t.fog_depth_begin = 6.0
    t.fog_depth_end = 40.0
    t.directional_light_color = Color(0.5, 0.4, 0.2)
    t.directional_light_energy = 0.6
    t.point_light_color = Color(1.0, 0.75, 0.35)
    t.point_light_energy = 4.0
    t.point_light_range_mult = 2.0
    t.point_light_attenuation = 1.8
    t.point_light_spacing = 2

    # Level Structure (section 6)
    t.has_ceiling = true
    t.wall_style = WallStyles.PALACE_ORNATE
    t.light_source_style = LightStyles.TORCH
    t.sky_config = {}

    # Level Materials (section 6)
    t.floor_albedo = Color(0.35, 0.25, 0.12)       # dark wood plank
    t.floor_roughness = 0.9
    t.corridor_floor_albedo = Color(0.3, 0.2, 0.1)
    t.corridor_floor_roughness = 0.9
    t.wall_albedo = Color(0.22, 0.15, 0.08)         # dark log wall
    t.wall_roughness = 0.9
    t.ceiling_albedo = Color(0.28, 0.2, 0.1)        # wooden ceiling
    t.ceiling_roughness = 0.85
    t.accent_emission_energy = 1.5
    t.accent_use_palette = false  # no neon strips — palace uses matte gold trim from wall builder

    # Textures (section 6)
    t.floor_pattern = {
        "type": "image_gen",
        "pattern": "flagstone",
        "color1": Color(0.35, 0.25, 0.12),
        "color2": Color(0.2, 0.14, 0.07),
        "width": 256,
        "height": 256,
    }
    t.corridor_floor_pattern = {
        "type": "image_gen",
        "pattern": "flagstone",
        "color1": Color(0.3, 0.2, 0.1),
        "color2": Color(0.18, 0.12, 0.06),
        "width": 256,
        "height": 256,
    }
    t.wall_pattern = {
        "type": "image_gen",
        "pattern": "ashlar",
        "color1": Color(0.22, 0.15, 0.08),
        "color2": Color(0.14, 0.1, 0.05),
        "width": 256,
        "height": 256,
    }
    t.ceiling_pattern = {
        "type": "image_gen",
        "pattern": "slabs",
        "color1": Color(0.28, 0.2, 0.1),
        "color2": Color(0.18, 0.12, 0.06),
        "width": 256,
        "height": 256,
    }
    t.monster_skin = {
        "type": "noise",
        "noise_type": "cellular",
        "frequency": 0.1,
        "octaves": 2,
        "width": 128,
        "height": 128,
    }

    # Props (section 6)
    t.prop_density = 0.5
    t.torch_flicker = true
    t.floor_style = FloorStyles.PLAIN
    t.beam_style = "ornate"
    t.ceiling_beam_spacing = 3
    t.pillar_chance = 0.35
    t.rubble_chance = 0.2
    t.room_prop_min = 1
    t.room_prop_max = 3

    # Monsters (section 6)
    t.body_albedo = Color(0.55, 0.3, 0.08)      # bronze
    t.body_emission = Color(0.4, 0.25, 0.05)    # warm bronze glow
    t.boss_albedo = Color(0.45, 0.25, 0.06)
    t.boss_emission = Color(0.6, 0.35, 0.1)     # bright bronze glow
    t.eye_color = Color(0.8, 0.13, 0.0)         # warrior red

    # Health Bars (section 6)
    t.health_bar_foreground = Color(0.85, 0.65, 0.2)
    t.health_bar_background = Color(0.12, 0.08, 0.04)
    t.health_bar_low_color = Color(0.8, 0.15, 0.05)

    # VFX (section 6)
    t.muzzle_flash_color = Color(1.0, 0.7, 0.2)
    t.impact_color = Color(0.9, 0.6, 0.15)
    t.death_color = Color(0.8, 0.13, 0.0)       # red burst
    t.aoe_blast_color = Color(1.0, 0.75, 0.25)

    # Projectile (section 6)
    t.projectile_color = Color(0.9, 0.65, 0.15)
    t.projectile_trail_color = Color(0.8, 0.5, 0.1)

    # Monster variants (section 9)
    var gp_basic = MonsterVariantDefinition.new()
    gp_basic.variant_name = "Zmey"
    gp_basic.variant_key = &"basic"
    gp_basic.scene = load("res://themes/folk/zmey_basic.tscn")
    gp_basic.spawn_weight = 2.0
    t.monster_variants.append(gp_basic)

    var gp_v1 = MonsterVariantDefinition.new()
    gp_v1.variant_name = "Koschei"
    gp_v1.variant_key = &"variant1"
    gp_v1.scene = load("res://themes/folk/koschei_basic.tscn")
    gp_v1.spawn_weight = 1.0
    t.monster_variants.append(gp_v1)

    var gp_v2 = MonsterVariantDefinition.new()
    gp_v2.variant_name = "Strazh"
    gp_v2.variant_key = &"variant2"
    gp_v2.scene = load("res://themes/folk/strazh_basic.tscn")
    gp_v2.spawn_weight = 1.0
    t.monster_variants.append(gp_v2)

    var gp_boss = MonsterVariantDefinition.new()
    gp_boss.variant_name = "Zmey Boss"
    gp_boss.variant_key = Modifiers.BOSS
    gp_boss.scene = load("res://themes/folk/zmey_boss.tscn")
    gp_boss.is_boss = true
    gp_boss.spawn_weight = 0.0
    t.monster_variants.append(gp_boss)

    return t

static func _create_winter_realm() -> ThemeData:
    var t = ThemeData.new()

    # Meta
    t.theme_name = "Russian Folk Tales"
    t.biome_name = "Winter Realm"
    t.description = "Frozen kingdom of Morozko from the Skazka winter tales"

    # Shared properties
    _apply_shared_properties(t)

    # Palette (section 7)
    t.primary = Color(0.27, 0.53, 0.8)     # ice blue
    t.secondary = Color(0.85, 0.9, 0.95)   # frost white
    t.tertiary = Color(0.15, 0.2, 0.4)     # deep blue
    t.highlight = Color(0.8, 0.0, 0.0)     # folk red
    t.danger = Color(0.4, 0.6, 1.0)        # frostbite blue

    # Environment (section 7)
    t.background_color = Color(0.03, 0.03, 0.08)
    t.ambient_color = Color(0.15, 0.18, 0.25)
    t.ambient_energy = 0.25
    t.fog_color = Color(0.12, 0.15, 0.22)
    t.fog_density = 0.008
    t.fog_depth_begin = 8.0
    t.fog_depth_end = 50.0
    t.directional_light_color = Color(0.4, 0.5, 0.7)
    t.directional_light_energy = 0.5
    t.point_light_color = Color(0.5, 0.65, 0.9)
    t.point_light_energy = 2.5
    t.point_light_range_mult = 1.8
    t.point_light_attenuation = 1.5
    t.point_light_spacing = 2

    # Level Structure (section 7)
    t.has_ceiling = false
    t.wall_style = WallStyles.ICE_CRYSTAL
    t.light_source_style = LightStyles.CRYSTAL
    t.sky_config = {
        "sky_top_color": Color(0.05, 0.05, 0.15),
        "sky_horizon_color": Color(0.3, 0.4, 0.6),
        "ground_bottom_color": Color(0.05, 0.05, 0.08),
        "ground_horizon_color": Color(0.2, 0.25, 0.35),
        "sun_angle_max": 10.0,
        "sun_energy": 0.3,
    }

    # Level Materials (section 7)
    t.floor_albedo = Color(0.3, 0.35, 0.42)        # frozen stone
    t.floor_roughness = 0.3                          # icy sheen
    t.corridor_floor_albedo = Color(0.25, 0.3, 0.38)
    t.corridor_floor_roughness = 0.25
    t.wall_albedo = Color(0.35, 0.4, 0.5)           # frost-covered stone
    t.wall_roughness = 0.35
    t.ceiling_albedo = Color(0.3, 0.35, 0.42)       # unused, no ceiling
    t.ceiling_roughness = 0.3
    t.accent_emission_energy = 2.0
    t.accent_use_palette = false                     # use frost white accents

    # Textures (section 7)
    t.floor_pattern = {
        "type": "image_gen",
        "pattern": "cobblestone",
        "color1": Color(0.3, 0.35, 0.42),
        "color2": Color(0.2, 0.25, 0.32),
        "width": 256,
        "height": 256,
    }
    t.corridor_floor_pattern = {
        "type": "image_gen",
        "pattern": "cobblestone",
        "color1": Color(0.25, 0.3, 0.38),
        "color2": Color(0.18, 0.22, 0.3),
        "width": 256,
        "height": 256,
    }
    t.wall_pattern = {
        "type": "image_gen",
        "pattern": "ashlar",
        "color1": Color(0.35, 0.4, 0.5),
        "color2": Color(0.25, 0.3, 0.4),
        "width": 256,
        "height": 256,
    }
    t.ceiling_pattern = {}
    t.monster_skin = {
        "type": "noise",
        "noise_type": "simplex",
        "frequency": 0.2,
        "octaves": 4,
        "width": 128,
        "height": 128,
    }

    # Props (section 7)
    t.prop_density = 0.35
    t.torch_flicker = false     # steady frozen light
    t.floor_style = FloorStyles.PLAIN
    t.beam_style = "none"
    t.ceiling_beam_spacing = 4  # unused, no ceiling
    t.pillar_chance = 0.25
    t.rubble_chance = 0.3
    t.room_prop_min = 1
    t.room_prop_max = 2

    # Monsters (section 7)
    t.body_albedo = Color(0.25, 0.35, 0.55)     # ice blue
    t.body_emission = Color(0.2, 0.35, 0.6)     # cold glow
    t.boss_albedo = Color(0.2, 0.3, 0.5)
    t.boss_emission = Color(0.3, 0.5, 0.8)      # bright ice glow
    t.eye_color = Color(0.8, 0.0, 0.0)          # folk red

    # Health Bars (section 7)
    t.health_bar_foreground = Color(0.27, 0.53, 0.8)
    t.health_bar_background = Color(0.1, 0.1, 0.15)
    t.health_bar_low_color = Color(0.8, 0.15, 0.1)

    # VFX (section 7)
    t.muzzle_flash_color = Color(0.5, 0.7, 1.0)
    t.impact_color = Color(0.4, 0.6, 0.9)
    t.death_color = Color(0.8, 0.0, 0.0)        # red burst on blue
    t.aoe_blast_color = Color(0.5, 0.7, 1.0)

    # Projectile (section 7)
    t.projectile_color = Color(0.4, 0.6, 0.9)
    t.projectile_trail_color = Color(0.3, 0.5, 0.8)

    # Monster variants (section 9)
    var wr_basic = MonsterVariantDefinition.new()
    wr_basic.variant_name = "Morozko"
    wr_basic.variant_key = &"basic"
    wr_basic.scene = load("res://themes/folk/morozko_basic.tscn")
    wr_basic.spawn_weight = 2.0
    t.monster_variants.append(wr_basic)

    var wr_v1 = MonsterVariantDefinition.new()
    wr_v1.variant_name = "Snegurochka"
    wr_v1.variant_key = &"variant1"
    wr_v1.scene = load("res://themes/folk/snegurochka_basic.tscn")
    wr_v1.spawn_weight = 1.0
    t.monster_variants.append(wr_v1)

    var wr_v2 = MonsterVariantDefinition.new()
    wr_v2.variant_name = "Medved"
    wr_v2.variant_key = &"variant2"
    wr_v2.scene = load("res://themes/folk/medved_basic.tscn")
    wr_v2.spawn_weight = 1.0
    t.monster_variants.append(wr_v2)

    var wr_boss = MonsterVariantDefinition.new()
    wr_boss.variant_name = "Morozko Boss"
    wr_boss.variant_key = Modifiers.BOSS
    wr_boss.scene = load("res://themes/folk/morozko_boss.tscn")
    wr_boss.is_boss = true
    wr_boss.spawn_weight = 0.0
    t.monster_variants.append(wr_boss)

    return t
