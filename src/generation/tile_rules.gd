class_name TileRules
extends RefCounted

var tiles: Dictionary = {}
var adjacency_dir: Dictionary = {}

func setup_profile(modifier: String) -> void:
    tiles.clear()
    adjacency_dir.clear()

    # Weight profiles per modifier
    var w: Dictionary
    match modifier:
        "dense":
            # Open arenas, many doors, less wall
            w = { room = 2.5, spawn = 2.5, cor = 0.3, door = 0.5, wall = 2.0, empty = 0.5 }
        "large":
            # Sprawling corridors, scattered rooms
            w = { room = 1.0, spawn = 1.0, cor = 0.8, door = 0.3, wall = 3.0, empty = 1.5 }
        "dark":
            # Tight, claustrophobic — tiny rooms, few doors
            w = { room = 0.8, spawn = 0.8, cor = 0.5, door = 0.15, wall = 4.0, empty = 1.5 }
        "horde":
            # Big open rooms for fighting, many doors for enemy flow
            w = { room = 3.0, spawn = 3.0, cor = 0.3, door = 0.6, wall = 2.0, empty = 0.3 }
        "boss":
            # One big arena
            w = { room = 3.0, spawn = 3.0, cor = 0.2, door = 0.3, wall = 2.5, empty = 0.5 }
        _:  # "normal"
            w = { room = 1.5, spawn = 1.5, cor = 0.4, door = 0.2, wall = 3.5, empty = 1.0 }

    add_tile("room", w.room, true, false)
    add_tile("spawn", w.spawn, true, true)
    add_tile("corridor_h", w.cor, true, false)
    add_tile("corridor_v", w.cor, true, false)
    add_tile("door", w.door, true, false)
    add_tile("wall", w.wall, false, false)
    add_tile("empty", w.empty, false, false)

    _setup_adjacency()

func _setup_adjacency() -> void:
    set_dir_adjacency("room",
        ["room", "spawn", "door", "wall"],
        ["room", "spawn", "door", "wall"],
        ["room", "spawn", "door", "wall"],
        ["room", "spawn", "door", "wall"])

    set_dir_adjacency("spawn",
        ["room"], ["room"], ["room"], ["room"])

    set_dir_adjacency("corridor_h",
        ["wall"],
        ["wall"],
        ["corridor_h", "door", "wall"],
        ["corridor_h", "door", "wall"])

    set_dir_adjacency("corridor_v",
        ["corridor_v", "door", "wall"],
        ["corridor_v", "door", "wall"],
        ["wall"],
        ["wall"])

    set_dir_adjacency("door",
        ["room", "corridor_v", "wall"],
        ["room", "corridor_v", "wall"],
        ["room", "corridor_h", "wall"],
        ["room", "corridor_h", "wall"])

    var wall_adj = ["room", "corridor_h", "corridor_v", "door", "wall", "empty"]
    set_dir_adjacency("wall", wall_adj, wall_adj, wall_adj, wall_adj)

    var empty_adj = ["wall", "empty"]
    set_dir_adjacency("empty", empty_adj, empty_adj, empty_adj, empty_adj)

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

func set_dir_adjacency(tile_name: String, north: Array, south: Array, east: Array, west: Array) -> void:
    adjacency_dir[tile_name] = {
        "north": north,
        "south": south,
        "east": east,
        "west": west,
    }

func get_allowed_neighbors_dir(tile_name: String, direction: String) -> Variant:
    if adjacency_dir.has(tile_name):
        return adjacency_dir[tile_name].get(direction, null)
    return null
