class_name NeonTheme

static func create() -> ThemeData:
	var t = ThemeData.new()

	t.theme_name = "Neon Dungeon"
	t.biome_name = "Neon"
	t.description = "Dark corridors lit by neon glow"

	# Palette (from neon_palette.gd)
	t.primary = Color(0.0, 0.83, 1.0)	   # CYAN
	t.secondary = Color(1.0, 0.0, 0.67)	   # MAGENTA
	t.tertiary = Color(0.67, 0.27, 1.0)	   # PURPLE
	t.highlight = Color(0.0, 1.0, 0.67)	   # TEAL
	t.danger = Color(1.0, 0.53, 0.0)	   # ORANGE
	t.rarity_colors = {
		"common": Color(0.8, 0.8, 0.8),
		"rare": Color(0.3, 0.5, 1.0),
		"epic": Color(0.7, 0.2, 1.0),
	}
	t.element_colors = {
		ElementNames.NONE: Color(1.0, 1.0, 1.0),
		ElementNames.FIRE: Color(1.0, 0.27, 0.0),
		ElementNames.ICE: Color(0.0, 0.87, 1.0),
		ElementNames.WATER: Color(0.0, 0.4, 1.0),
		ElementNames.OIL: Color(0.33, 0.42, 0.18),
	}

	# Environment
	t.background_color = Color(0.02, 0.02, 0.04)
	t.ambient_color = Color(0.15, 0.15, 0.25)
	t.ambient_energy = 0.8
	t.fog_color = Color(0.02, 0.02, 0.06)
	t.fog_density = 0.02
	t.fog_depth_begin = 5.0
	t.fog_depth_end = 40.0
	t.directional_light_color = Color(0.6, 0.65, 0.8)
	t.directional_light_energy = 0.5
	t.point_light_color = Color(1.0, 1.0, 1.0)
	t.point_light_energy = 0.8
	t.point_light_range_mult = 1.5
	t.point_light_attenuation = 2.0
	t.point_light_spacing = 2

	# Level materials
	t.floor_albedo = Color(0.45, 0.42, 0.48)
	t.floor_roughness = 0.9
	t.corridor_floor_albedo = Color(0.38, 0.40, 0.45)
	t.corridor_floor_roughness = 0.9
	t.wall_albedo = Color(0.65, 0.62, 0.68)
	t.wall_roughness = 0.85
	t.ceiling_albedo = Color(0.50, 0.50, 0.55)
	t.ceiling_roughness = 0.95
	t.accent_emission_energy = 3.0
	t.accent_use_palette = true

	# Monsters
	t.body_albedo = Color(0.08, 0.08, 0.1)
	t.body_emission = Color(0.0, 0.83, 1.0)
	t.boss_albedo = Color(0.2, 0.02, 0.02)
	t.boss_emission = Color(1.0, 0.15, 0.1)
	t.eye_color = Color(1.0, 0.1, 0.1)
	t.health_bar_foreground = Color(0.0, 1.0, 0.3)
	t.health_bar_background = Color(0.15, 0.15, 0.15)
	t.health_bar_low_color = Color(1.0, 0.0, 0.1)

	# Projectile
	t.projectile_color = Color(1.0, 1.0, 1.0)
	t.projectile_trail_color = Color(1.0, 1.0, 1.0)

	# VFX
	t.muzzle_flash_color = Color(1.0, 0.9, 0.6)
	t.impact_color = Color(1.0, 1.0, 1.0)
	t.death_color = Color(1.0, 0.3, 0.1)
	t.aoe_blast_color = Color(1.0, 0.6, 0.1)

	# UI
	t.ui_background_color = Color(0.05, 0.05, 0.1)
	t.ui_panel_color = Color(0.1, 0.1, 0.15)
	t.ui_text_color = Color(1.0, 1.0, 1.0)
	t.ui_accent_color = Color(0.0, 0.83, 1.0)
	t.ui_damage_flash_color = Color(1.0, 0.0, 0.0, 0.3)
	t.ui_crosshair_color = Color(1.0, 1.0, 1.0)
	t.ui_minimap_room = Color(0.1, 0.1, 0.2)
	t.ui_minimap_wall = Color(0.2, 0.3, 0.5)
	t.ui_kill_feed_color = Color(0.0, 0.83, 1.0)

	# Monster variants
	var basic = MonsterVariantDefinition.new()
	basic.variant_name = "Neon Basic"
	basic.variant_key = &"basic"
	basic.scene = load("res://themes/neon/monster_basic.tscn")
	basic.spawn_weight = 2.0
	t.monster_variants.append(basic)

	var boss = MonsterVariantDefinition.new()
	boss.variant_name = "Neon Boss"
	boss.variant_key = Modifiers.BOSS
	boss.scene = load("res://themes/neon/monster_boss.tscn")
	boss.is_boss = true
	boss.spawn_weight = 0.0
	t.monster_variants.append(boss)

	# Textures — neon uses minimal textures
	t.floor_pattern = {}
	t.wall_pattern = {}
	t.monster_skin = {}

	return t
