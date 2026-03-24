class_name TileRules
extends RefCounted

var tiles: Dictionary = {}
var adjacency: Dictionary = {}

func setup_defaults() -> void:
    add_tile("room", 3.0, true, true)
    add_tile("corridor", 2.0, true, false)
    add_tile("wall", 1.0, false, false)
    add_tile("empty", 0.3, false, false)

    set_adjacency("room", ["room", "corridor", "wall"])
    set_adjacency("corridor", ["room", "corridor", "wall"])
    set_adjacency("wall", ["room", "corridor", "wall", "empty"])
    set_adjacency("empty", ["wall", "empty"])

func add_tile(name: String, weight: float, walkable: bool, can_spawn: bool) -> void:
    tiles[name] = {
        "name": name,
        "weight": weight,
        "walkable": walkable,
        "can_spawn": can_spawn,
    }

func get_tile(name: String) -> Variant:
    if tiles.has(name):
        return tiles[name]
    return null

func has_tile(name: String) -> bool:
    return tiles.has(name)

func get_all_tile_names() -> Array[String]:
    var names: Array[String] = []
    for key in tiles.keys():
        names.append(key)
    return names

func set_adjacency(tile_name: String, neighbors: Array) -> void:
    adjacency[tile_name] = neighbors

func get_allowed_neighbors(tile_name: String) -> Variant:
    if adjacency.has(tile_name):
        return adjacency[tile_name]
    return null
