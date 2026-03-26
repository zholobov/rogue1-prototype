class_name ThemeData
extends Resource

# --- Meta ---
@export var theme_name: String = ""
@export var biome_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

# --- Palette ---
@export_group("Palette")
@export var primary: Color = Color(1.0, 1.0, 1.0)
@export var secondary: Color = Color(0.8, 0.8, 0.8)
@export var tertiary: Color = Color(0.6, 0.6, 0.6)
@export var highlight: Color = Color(1.0, 1.0, 0.0)
@export var danger: Color = Color(1.0, 0.0, 0.0)
@export var rarity_colors: Dictionary = {
    "common": Color(0.8, 0.8, 0.8),
    "rare": Color(0.3, 0.5, 1.0),
    "epic": Color(0.7, 0.2, 1.0),
}
@export var element_colors: Dictionary = {
    "": Color(1.0, 1.0, 1.0),
    "fire": Color(1.0, 0.27, 0.0),
    "ice": Color(0.0, 0.87, 1.0),
    "water": Color(0.0, 0.4, 1.0),
    "oil": Color(0.33, 0.42, 0.18),
}

# --- Environment ---
@export_group("Environment")
@export var background_color: Color = Color(0.02, 0.02, 0.04)
@export var ambient_color: Color = Color(0.15, 0.15, 0.25)
@export var ambient_energy: float = 0.8
@export var fog_color: Color = Color(0.02, 0.02, 0.06)
@export var fog_density: float = 0.02
@export var fog_depth_begin: float = 5.0
@export var fog_depth_end: float = 40.0
@export var directional_light_color: Color = Color(0.6, 0.65, 0.8)
@export var directional_light_energy: float = 0.5
@export var point_light_color: Color = Color(1.0, 1.0, 1.0)
@export var point_light_energy: float = 0.8
@export var point_light_range_mult: float = 1.5
@export var point_light_attenuation: float = 2.0
@export var point_light_spacing: int = 2

# --- Level Materials ---
@export_group("Level Materials")
@export var floor_albedo: Color = Color(0.45, 0.42, 0.48)
@export var floor_roughness: float = 0.9
@export var corridor_floor_albedo: Color = Color(0.38, 0.40, 0.45)
@export var corridor_floor_roughness: float = 0.9
@export var wall_albedo: Color = Color(0.65, 0.62, 0.68)
@export var wall_roughness: float = 0.85
@export var ceiling_albedo: Color = Color(0.50, 0.50, 0.55)
@export var ceiling_roughness: float = 0.95
@export var accent_emission_energy: float = 3.0
@export var accent_use_palette: bool = true

# --- Monsters ---
@export_group("Monsters")
@export var monster_scenes: Dictionary = {}
@export var body_albedo: Color = Color(0.08, 0.08, 0.1)
@export var body_emission: Color = Color(0.0, 0.83, 1.0)
@export var boss_albedo: Color = Color(0.2, 0.02, 0.02)
@export var boss_emission: Color = Color(1.0, 0.15, 0.1)
@export var eye_color: Color = Color(1.0, 0.1, 0.1)
@export var health_bar_foreground: Color = Color(0.0, 1.0, 0.3)
@export var health_bar_background: Color = Color(0.15, 0.15, 0.15)
@export var health_bar_low_color: Color = Color(1.0, 0.0, 0.1)

# --- Projectile ---
@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_color: Color = Color(1.0, 1.0, 1.0)
@export var projectile_trail_color: Color = Color(1.0, 1.0, 1.0)

# --- VFX ---
@export_group("VFX")
@export var muzzle_flash_color: Color = Color(1.0, 0.9, 0.6)
@export var impact_color: Color = Color(1.0, 1.0, 1.0)
@export var death_color: Color = Color(1.0, 0.3, 0.1)
@export var aoe_blast_color: Color = Color(1.0, 0.6, 0.1)

# --- UI ---
@export_group("UI")
@export var ui_background_color: Color = Color(0.05, 0.05, 0.1)
@export var ui_panel_color: Color = Color(0.1, 0.1, 0.15)
@export var ui_text_color: Color = Color(1.0, 1.0, 1.0)
@export var ui_accent_color: Color = Color(0.0, 0.83, 1.0)
@export var ui_damage_flash_color: Color = Color(1.0, 0.0, 0.0, 0.3)
@export var ui_crosshair_color: Color = Color(1.0, 1.0, 1.0)
@export var ui_minimap_room: Color = Color(0.15, 0.15, 0.2)
@export var ui_minimap_wall: Color = Color(0.3, 0.3, 0.4)
@export var ui_kill_feed_color: Color = Color(1.0, 1.0, 1.0)

# --- Audio ---
@export_group("Audio")
@export var ambient_loop: AudioStream
@export var death_sound: AudioStream
@export var music: AudioStream

# --- Textures ---
@export_group("Textures")
@export var floor_pattern: Dictionary = {}
@export var wall_pattern: Dictionary = {}
@export var accent_shader: Shader
@export var monster_skin: Dictionary = {}
@export var corridor_floor_pattern: Dictionary = {}
@export var ceiling_pattern: Dictionary = {}

# --- Props ---
@export_group("Props")
@export var prop_density: float = 0.0
@export var torch_flicker: bool = true
@export var ceiling_beam_spacing: int = 2
@export var pillar_chance: float = 0.2
@export var rubble_chance: float = 0.15
@export var room_prop_min: int = 1
@export var room_prop_max: int = 3

# --- Helper methods ---

func get_palette_array() -> Array[Color]:
    return [primary, secondary, tertiary, highlight, danger]

func get_random_palette_color() -> Color:
    var arr = get_palette_array()
    return arr[randi() % arr.size()]

func get_element_color(element: String) -> Color:
    if element_colors.has(element):
        return element_colors[element]
    return Color.WHITE
