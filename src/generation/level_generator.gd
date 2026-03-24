class_name LevelGenerator
extends RefCounted

## Orchestrates level generation: runs WFC solver, then builds 3D geometry.

var tile_rules: TileRules
var solver: WFCSolver
var builder: LevelBuilder

func _init() -> void:
    tile_rules = TileRules.new()
    tile_rules.setup_defaults()
    solver = WFCSolver.new()
    builder = LevelBuilder.new()

func generate(width: int, height: int, seed: int, tile_size: float = 4.0) -> Dictionary:
    var grid = solver.solve(tile_rules, width, height, seed)
    var geometry = builder.build(grid, tile_rules, tile_size)

    # Collect spawn points
    var spawn_points: Array[Vector3] = []
    for child in _find_in_group(geometry, "spawn_point"):
        spawn_points.append(child.position)

    return {
        "geometry": geometry,
        "grid": grid,
        "spawn_points": spawn_points,
        "seed": seed,
        "width": width,
        "height": height,
    }

func _find_in_group(node: Node, group: String) -> Array[Node]:
    var found: Array[Node] = []
    for child in node.get_children():
        if child.is_in_group(group):
            found.append(child)
        found.append_array(_find_in_group(child, group))
    return found
