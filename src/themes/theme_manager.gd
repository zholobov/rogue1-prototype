extends Node

signal theme_changed(theme: ThemeData)

var active_theme: ThemeData
var available_themes: Array[ThemeData] = []

var active_group: ThemeGroup
var available_groups: Array[ThemeGroup] = []

func _ready() -> void:
	_load_themes()
	if available_groups.size() > 0:
		active_group = available_groups[0]
		active_theme = active_group.biomes[0]
		TextureFactory.generate_for_theme(active_theme)

func set_theme(theme_name_to_set: String) -> void:
	# Search by group name
	for group in available_groups:
		if group.group_name == theme_name_to_set:
			active_group = group
			active_theme = group.biomes[0]
			TextureFactory.generate_for_theme(active_theme)
			VfxFactory.clear_cache()
			theme_changed.emit(active_theme)
			return
	# Fallback: search by biome name in current group
	for biome in active_group.biomes:
		if biome.theme_name == theme_name_to_set or biome.biome_name == theme_name_to_set:
			set_biome(biome)
			return

func set_biome(biome: ThemeData) -> void:
	active_theme = biome
	TextureFactory.generate_for_theme(biome)
	VfxFactory.clear_cache()
	theme_changed.emit(active_theme)

func get_palette() -> Array[Color]:
	return active_theme.get_palette_array()

func get_monster_scene(type: StringName) -> PackedScene:
	for variant in active_theme.monster_variants:
		if variant.variant_key == type:
			return variant.scene
	return null

func get_spawnable_variants() -> Array:
	var result: Array = []
	for variant in active_theme.monster_variants:
		if not variant.is_boss and variant.spawn_weight > 0.0:
			result.append(variant)
	return result

func get_projectile_scene() -> PackedScene:
	return active_theme.projectile_scene

func _load_themes() -> void:
	var neon_biome = NeonTheme.create()
	var neon_group = ThemeGroup.new()
	neon_group.group_name = "Neon Dungeon"
	neon_group.description = "Glowing neon corridors"
	neon_group.biomes = [neon_biome]
	available_groups.append(neon_group)

	var stone_biome = StoneTheme.create()
	var stone_group = ThemeGroup.new()
	stone_group.group_name = "Stone Dungeon"
	stone_group.description = "Ancient stone halls"
	stone_group.biomes = [stone_biome]
	available_groups.append(stone_group)

	var folk_group = FolkTheme.create_group()
	available_groups.append(folk_group)

	# Flat list for backward compat
	for group in available_groups:
		available_themes.append_array(group.biomes)

	active_group = available_groups[0]
	active_theme = active_group.biomes[0]
