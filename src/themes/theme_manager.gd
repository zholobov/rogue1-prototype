extends Node

signal theme_changed(theme: ThemeData)

var active_theme: ThemeData
var available_themes: Array[ThemeData] = []

func _ready() -> void:
    _load_themes()
    if available_themes.size() > 0:
        active_theme = available_themes[0]

func set_theme(theme_name_to_set: String) -> void:
    for theme in available_themes:
        if theme.theme_name == theme_name_to_set:
            active_theme = theme
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
    var default_theme = ThemeData.new()
    default_theme.theme_name = "Default"
    default_theme.description = "Default theme"
    available_themes.append(default_theme)
