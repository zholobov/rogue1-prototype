class_name StoneTheme

static func create() -> ThemeData:
	var t = ThemeData.new()

	# Meta
	t.theme_name = "Stone Dungeon"
	t.biome_name = "Stone"
	t.description = "Ancient stone corridors lit by flickering torches"

	# Palette — warm earthy tones
	t.primary = Color(0.85, 0.65, 0.2)		# Warm gold
	t.secondary = Color(1.0, 0.55, 0.1)		# Torch orange
	t.tertiary = Color(0.9, 0.85, 0.75)		# Bone white
	t.highlight = Color(0.7, 0.1, 0.1)		# Blood red
	t.danger = Color(0.3, 0.5, 0.2)			# Moss green
	t.rarity_colors = {
		"common": Color(0.7, 0.65, 0.55),
		"rare": Color(0.4, 0.55, 0.8),
		"epic": Color(0.65, 0.3, 0.1),
	}
	t.element_colors = {
		ElementNames.NONE: Color(0.9, 0.85, 0.7),
		ElementNames.FIRE: Color(1.0, 0.4, 0.0),
		ElementNames.ICE: Color(0.6, 0.8, 0.95),
		ElementNames.WATER: Color(0.2, 0.5, 0.8),
		ElementNames.OIL: Color(0.4, 0.35, 0.15),
	}

	# Environment — warm, close, thick fog
	t.background_color = Color(0.04, 0.03, 0.02)
	t.ambient_color = Color(0.25, 0.18, 0.1)
	t.ambient_energy = 0.9
	t.fog_color = Color(0.06, 0.04, 0.02)
	t.fog_density = 0.015
	t.fog_depth_begin = 5.0
	t.fog_depth_end = 45.0
	t.directional_light_color = Color(0.9, 0.7, 0.4)
	t.directional_light_energy = 0.4
	t.point_light_color = Color(1.0, 0.75, 0.4)
	t.point_light_energy = 3.0
	t.point_light_range_mult = 1.8
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
	t.accent_use_palette = false

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
	t.ui_crosshair_color = Color(0.9, 0.85, 0.7)
	t.ui_minimap_room = Color(0.2, 0.18, 0.15)
	t.ui_minimap_wall = Color(0.4, 0.35, 0.3)
	t.ui_kill_feed_color = Color(0.9, 0.75, 0.4)

	# Textures — high-contrast stone patterns
	t.floor_pattern = {
		"type": "image_gen",
		"pattern": "flagstone",
		"color1": Color(0.45, 0.4, 0.35),
		"color2": Color(0.15, 0.12, 0.1),
		"width": 256,
		"height": 256,
	}
	t.corridor_floor_pattern = {
		"type": "image_gen",
		"pattern": "cobblestone",
		"color1": Color(0.4, 0.38, 0.35),
		"color2": Color(0.18, 0.15, 0.12),
		"width": 256,
		"height": 256,
	}
	t.wall_pattern = {
		"type": "image_gen",
		"pattern": "ashlar",
		"color1": Color(0.4, 0.35, 0.3),
		"color2": Color(0.15, 0.12, 0.1),
		"width": 256,
		"height": 256,
	}
	t.ceiling_pattern = {
		"type": "image_gen",
		"pattern": "slabs",
		"color1": Color(0.38, 0.35, 0.32),
		"color2": Color(0.15, 0.12, 0.1),
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

	# Props
	t.prop_density = 1.0
	t.torch_flicker = true
	t.light_source_style = LightStyles.TORCH
	t.floor_style = FloorStyles.CRACKED_SLAB
	t.beam_style = WallStyles.DEFAULT
	t.ceiling_beam_spacing = 2
	t.pillar_chance = 0.2
	t.rubble_chance = 0.15
	t.room_prop_min = 1
	t.room_prop_max = 3

	# Monster variants
	var basic = MonsterVariantDefinition.new()
	basic.variant_name = "Stone Basic"
	basic.variant_key = &"basic"
	basic.scene = load("res://themes/stone/monster_basic.tscn")
	basic.spawn_weight = 2.0
	t.monster_variants.append(basic)

	var boss = MonsterVariantDefinition.new()
	boss.variant_name = "Stone Boss"
	boss.variant_key = Modifiers.BOSS
	boss.scene = load("res://themes/stone/monster_boss.tscn")
	boss.is_boss = true
	boss.spawn_weight = 0.0
	t.monster_variants.append(boss)

	return t
