extends Node

signal theme_changed(theme: ThemeData)

var active_theme: ThemeData
var available_themes: Array[ThemeData] = []

func _ready() -> void:
    _load_themes()
    if available_themes.size() > 0:
        active_theme = available_themes[0]
        TextureFactory.generate_for_theme(active_theme)

func set_theme(theme_name_to_set: String) -> void:
    for theme in available_themes:
        if theme.theme_name == theme_name_to_set:
            active_theme = theme
            TextureFactory.generate_for_theme(theme)
            theme_changed.emit(theme)
            return

func get_palette() -> Array[Color]:
    return active_theme.get_palette_array()

func get_monster_scene(type: String) -> PackedScene:
    if active_theme.monster_scenes.has(type):
        return active_theme.monster_scenes[type]
    return null

func get_projectile_scene() -> PackedScene:
    return active_theme.projectile_scene

func _load_themes() -> void:
    available_themes.append(NeonTheme.create())
    available_themes.append(StoneTheme.create())
    active_theme = available_themes[0]
