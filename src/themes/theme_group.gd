class_name ThemeGroup
extends RefCounted

var group_name: String = ""
var description: String = ""
var biomes: Array = []
var player_scene: PackedScene
var player_body_albedo: Color = Color(0.4, 0.4, 0.5)
var player_body_emission: Color = Color(0.2, 0.2, 0.3)

func get_random_biome() -> ThemeData:
    if biomes.is_empty():
        return null
    return biomes[randi() % biomes.size()]

func get_biome(index: int) -> ThemeData:
    if index >= 0 and index < biomes.size():
        return biomes[index]
    return biomes[0] if not biomes.is_empty() else null
