class_name StoneTheme

static func create() -> ThemeData:
    var t = ThemeData.new()

    # Meta
    t.theme_name = "Stone Dungeon"
    t.description = "Ancient stone corridors lit by flickering torches"

    # Palette — warm earthy tones
    t.primary = Color(0.85, 0.65, 0.2)      # Warm gold
    t.secondary = Color(1.0, 0.55, 0.1)     # Torch orange
    t.tertiary = Color(0.9, 0.85, 0.75)     # Bone white
    t.highlight = Color(0.7, 0.1, 0.1)      # Blood red
    t.danger = Color(0.3, 0.5, 0.2)         # Moss green
    t.rarity_colors = {
        "common": Color(0.7, 0.65, 0.55),
        "rare": Color(0.4, 0.55, 0.8),
        "epic": Color(0.65, 0.3, 0.1),
    }
    t.element_colors = {
        "": Color(0.9, 0.85, 0.7),
        "fire": Color(1.0, 0.4, 0.0),
        "ice": Color(0.6, 0.8, 0.95),
        "water": Color(0.2, 0.5, 0.8),
        "oil": Color(0.4, 0.35, 0.15),
    }

    # Environment — warm, close, thick fog
    t.background_color = Color(0.04, 0.03, 0.02)
    t.ambient_color = Color(0.25, 0.18, 0.1)
    t.ambient_energy = 0.6
    t.fog_color = Color(0.06, 0.04, 0.02)
    t.fog_density = 0.03
    t.fog_depth_begin = 3.0
    t.fog_depth_end = 30.0
    t.directional_light_color = Color(0.9, 0.7, 0.4)
    t.directional_light_energy = 0.3
    t.point_light_color = Color(1.0, 0.75, 0.4)
    t.point_light_energy = 2.0
    t.point_light_range_mult = 1.2
    t.point_light_attenuation = 1.8
    t.point_light_spacing = 3

    # Level materials — stone surfaces
    t.floor_albedo = Color(0.4, 0.38, 0.35)
    t.floor_roughness = 0.95
    t.corridor_floor_albedo = Color(0.35, 0.33, 0.30)
    t.corridor_floor_roughness = 0.95
    t.wall_albedo = Color(0.3, 0.28, 0.25)
    t.wall_roughness = 0.9
    t.ceiling_albedo = Color(0.35, 0.33, 0.30)
    t.ceiling_roughness = 0.95
    t.accent_emission_energy = 1.5
    t.accent_use_palette = true

    # Monsters — earthy golems
    t.body_albedo = Color(0.35, 0.3, 0.25)
    t.body_emission = Color(0.6, 0.35, 0.1)
    t.boss_albedo = Color(0.4, 0.2, 0.1)
    t.boss_emission = Color(0.9, 0.4, 0.1)
    t.eye_color = Color(1.0, 0.6, 0.1)
    t.health_bar_foreground = Color(0.2, 0.8, 0.3)
    t.health_bar_background = Color(0.2, 0.18, 0.15)
    t.health_bar_low_color = Color(0.8, 0.2, 0.1)

    # Projectile
    t.projectile_color = Color(0.9, 0.7, 0.3)
    t.projectile_trail_color = Color(1.0, 0.6, 0.2)

    # VFX — embers, warm sparks
    t.muzzle_flash_color = Color(1.0, 0.7, 0.3)
    t.impact_color = Color(0.9, 0.6, 0.2)
    t.death_color = Color(0.7, 0.4, 0.1)
    t.aoe_blast_color = Color(1.0, 0.5, 0.15)

    # UI — parchment/brown
    t.ui_background_color = Color(0.12, 0.08, 0.05)
    t.ui_panel_color = Color(0.18, 0.12, 0.08)
    t.ui_text_color = Color(0.9, 0.8, 0.6)
    t.ui_accent_color = Color(0.85, 0.65, 0.2)
    t.ui_damage_flash_color = Color(0.8, 0.2, 0.0, 0.3)

    # Textures — stone and brick patterns
    t.floor_pattern = {
        "type": "noise",
        "noise_type": "cellular",
        "frequency": 0.08,
        "octaves": 4,
        "width": 256,
        "height": 256,
    }
    t.wall_pattern = {
        "type": "image_gen",
        "pattern": "bricks",
        "color1": Color(0.35, 0.32, 0.28),
        "color2": Color(0.22, 0.20, 0.18),
        "width": 256,
        "height": 256,
    }
    t.monster_skin = {
        "type": "noise",
        "noise_type": "simplex",
        "frequency": 0.1,
        "octaves": 3,
        "width": 128,
        "height": 128,
    }

    t.monster_scenes = {
        "basic": load("res://themes/stone/monster_basic.tscn"),
        "boss": load("res://themes/stone/monster_boss.tscn"),
    }

    return t
