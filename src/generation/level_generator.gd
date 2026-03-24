class_name LevelGenerator
extends RefCounted

## Orchestrates level generation: pins room seeds, runs WFC, ensures connectivity, builds 3D.

var tile_rules: TileRules
var solver: WFCSolver
var builder: LevelBuilder

func _init() -> void:
    tile_rules = TileRules.new()
    solver = WFCSolver.new()
    builder = LevelBuilder.new()

func generate(width: int, height: int, seed_val: int, tile_size: float = 4.0) -> Dictionary:
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_val

    var modifier = Config.current_modifier
    tile_rules.setup_profile(modifier)

    # Pin room seeds — count and spacing vary by modifier
    var pinned = _generate_room_seeds(rng, width, height, modifier)

    var grid = solver.solve(tile_rules, width, height, seed_val, pinned)
    _ensure_connectivity(grid)
    _remove_tiny_rooms(grid)
    _prune_dead_ends(grid)
    _seal_empty_borders(grid)
    var geometry = builder.build(grid, tile_rules, tile_size)

    var spawn_points: Array[Vector3] = []
    for child in _find_in_group(geometry, "spawn_point"):
        spawn_points.append(child.position)

    return {
        "geometry": geometry,
        "grid": grid,
        "spawn_points": spawn_points,
        "seed": seed_val,
        "width": width,
        "height": height,
    }

func _generate_room_seeds(rng: RandomNumberGenerator, width: int, height: int, modifier: String) -> Dictionary:
    var pinned: Dictionary = {}
    var seeds: Array = []

    # Per-modifier seed count and spacing
    var room_count: int
    var min_dist: int
    match modifier:
        "dense":
            room_count = rng.randi_range(6, 9)
            min_dist = 3
        "large":
            room_count = rng.randi_range(3, 5)
            min_dist = 5
        "dark":
            room_count = rng.randi_range(5, 8)
            min_dist = 3
        "horde":
            room_count = rng.randi_range(3, 5)
            min_dist = 5
        "boss":
            # Large central arena — pin a 5x5 block of room tiles with spawn at center
            var cx = width / 2
            var cy = height / 2
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    var px = cx + dx
                    var py = cy + dy
                    if px > 0 and px < width - 1 and py > 0 and py < height - 1:
                        if dx == 0 and dy == 0:
                            pinned[Vector2i(px, py)] = "spawn"
                        else:
                            pinned[Vector2i(px, py)] = "room"
            return pinned
        _:  # "normal"
            room_count = rng.randi_range(4, 7)
            min_dist = 4

    var attempts = 0

    while seeds.size() < room_count and attempts < 100:
        attempts += 1
        var x = rng.randi_range(2, width - 3)
        var y = rng.randi_range(2, height - 3)
        var too_close = false
        for s in seeds:
            if absi(x - s.x) + absi(y - s.y) < min_dist:
                too_close = true
                break
        if too_close:
            continue
        seeds.append(Vector2i(x, y))
        pinned[Vector2i(x, y)] = "spawn"

    return pinned

func _ensure_connectivity(grid: Array) -> void:
    var height = grid.size()
    var width = grid[0].size() if height > 0 else 0

    var visited: Dictionary = {}
    var clusters: Array = []

    for y in range(height):
        for x in range(width):
            var key = Vector2i(x, y)
            if visited.has(key):
                continue
            if not _is_walkable(grid[y][x]):
                continue
            var cluster: Array = []
            var stack: Array = [key]
            while not stack.is_empty():
                var cell = stack.pop_back()
                if visited.has(cell):
                    continue
                if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
                    continue
                if not _is_walkable(grid[cell.y][cell.x]):
                    continue
                visited[cell] = true
                cluster.append(cell)
                stack.append(Vector2i(cell.x + 1, cell.y))
                stack.append(Vector2i(cell.x - 1, cell.y))
                stack.append(Vector2i(cell.x, cell.y + 1))
                stack.append(Vector2i(cell.x, cell.y - 1))
            if cluster.size() > 0:
                clusters.append(cluster)

    if clusters.size() <= 1:
        return

    clusters.sort_custom(func(a, b): return a.size() > b.size())
    var main_cluster = clusters[0]
    for i in range(1, clusters.size()):
        var small_cluster = clusters[i]
        var best_dist = 9999
        var best_main = Vector2i.ZERO
        var best_small = Vector2i.ZERO
        for mc in main_cluster:
            for sc in small_cluster:
                var dist = absi(mc.x - sc.x) + absi(mc.y - sc.y)
                if dist < best_dist:
                    best_dist = dist
                    best_main = mc
                    best_small = sc
        _carve_corridor(grid, best_main, best_small, width, height)
        main_cluster.append_array(small_cluster)

func _carve_corridor(grid: Array, from: Vector2i, to: Vector2i, width: int, height: int) -> void:
    var x = from.x
    var y = from.y
    # Horizontal segment
    while x != to.x:
        x += 1 if to.x > x else -1
        if x > 0 and x < width - 1 and not _is_walkable(grid[y][x]):
            grid[y][x] = "corridor_h"
    # Vertical segment
    while y != to.y:
        y += 1 if to.y > y else -1
        if y > 0 and y < height - 1 and not _is_walkable(grid[y][x]):
            grid[y][x] = "corridor_v"

func _remove_tiny_rooms(grid: Array) -> void:
    var height = grid.size()
    var width = grid[0].size() if height > 0 else 0
    var visited: Dictionary = {}
    var room_tiles = ["room", "spawn"]

    for y in range(height):
        for x in range(width):
            var key = Vector2i(x, y)
            if visited.has(key):
                continue
            if grid[y][x] not in room_tiles:
                continue
            # Flood fill this room cluster
            var cluster: Array = []
            var has_spawn = false
            var stack: Array = [key]
            while not stack.is_empty():
                var cell = stack.pop_back()
                if visited.has(cell):
                    continue
                if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= height:
                    continue
                if grid[cell.y][cell.x] not in room_tiles:
                    continue
                visited[cell] = true
                cluster.append(cell)
                if grid[cell.y][cell.x] == "spawn":
                    has_spawn = true
                stack.append(Vector2i(cell.x + 1, cell.y))
                stack.append(Vector2i(cell.x - 1, cell.y))
                stack.append(Vector2i(cell.x, cell.y + 1))
                stack.append(Vector2i(cell.x, cell.y - 1))
            # Fill tiny rooms (< 4 tiles) with wall, but keep rooms that have spawn points
            if cluster.size() < 4 and not has_spawn:
                for cell in cluster:
                    grid[cell.y][cell.x] = "wall"

func _prune_dead_ends(grid: Array) -> void:
    var height = grid.size()
    var width = grid[0].size() if height > 0 else 0
    var corridor_tiles = ["corridor_h", "corridor_v"]
    var changed = true

    while changed:
        changed = false
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                if grid[y][x] not in corridor_tiles:
                    continue
                # Count walkable neighbors
                var walkable_neighbors = 0
                for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                    var nx = x + dir.x
                    var ny = y + dir.y
                    if _is_walkable(grid[ny][nx]):
                        walkable_neighbors += 1
                # Dead end: only 1 walkable neighbor
                if walkable_neighbors <= 1:
                    grid[y][x] = "wall"
                    changed = true

func _seal_empty_borders(grid: Array) -> void:
    var height = grid.size()
    var width = grid[0].size() if height > 0 else 0
    var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

    for y in range(height):
        for x in range(width):
            if grid[y][x] != "empty":
                continue
            for dir in dirs:
                var nx = x + dir.x
                var ny = y + dir.y
                if nx >= 0 and nx < width and ny >= 0 and ny < height:
                    if _is_walkable(grid[ny][nx]):
                        grid[y][x] = "wall"
                        break

func _is_walkable(tile_name: String) -> bool:
    return tile_name in ["room", "spawn", "corridor_h", "corridor_v", "door"]

func _find_in_group(node: Node, group: String) -> Array[Node]:
    var found: Array[Node] = []
    for child in node.get_children():
        if child.is_in_group(group):
            found.append(child)
        found.append_array(_find_in_group(child, group))
    return found
