class_name WFCSolver
extends RefCounted

## Grid-based Wave Function Collapse solver with directional adjacency.
## Each cell starts with all possible tiles, then collapses via constraint propagation.

var _rng: RandomNumberGenerator

const DIRS = [
    Vector2i(0, -1),  # north
    Vector2i(0, 1),   # south
    Vector2i(1, 0),   # east
    Vector2i(-1, 0),  # west
]
const DIR_NAMES = ["north", "south", "east", "west"]

func solve(rules: TileRules, width: int, height: int, seed: int, pinned: Dictionary = {}) -> Array:
    _rng = RandomNumberGenerator.new()
    _rng.seed = seed

    var tile_names = rules.get_all_tile_names()

    # Initialize grid: each cell has all possible tiles
    var possibilities: Array = []
    for y in range(height):
        var row: Array = []
        for x in range(width):
            row.append(tile_names.duplicate())
        possibilities.append(row)

    # Pre-constrain borders: only wall or empty
    _constrain_borders(possibilities, rules, width, height)

    # Collapse loop
    var collapsed: Array = []
    for y in range(height):
        var row: Array = []
        for _x in range(width):
            row.append("")
        collapsed.append(row)

    # Pre-collapse pinned cells and propagate their constraints
    for pos in pinned:
        var tile = pinned[pos]
        collapsed[pos.y][pos.x] = tile
        possibilities[pos.y][pos.x] = [tile]
        _propagate(possibilities, collapsed, rules, pos.x, pos.y, width, height)

    var max_iterations = width * height * 10
    var iterations = 0

    while iterations < max_iterations:
        iterations += 1

        # Find cell with lowest entropy that isn't collapsed
        var min_entropy = 999
        var candidates: Array = []
        for y in range(height):
            for x in range(width):
                if collapsed[y][x] != "":
                    continue
                var entropy = possibilities[y][x].size()
                if entropy == 0:
                    # Contradiction — restart with offset seed
                    return solve(rules, width, height, seed + 1, pinned)
                if entropy < min_entropy:
                    min_entropy = entropy
                    candidates = [Vector2i(x, y)]
                elif entropy == min_entropy:
                    candidates.append(Vector2i(x, y))

        if candidates.is_empty():
            break

        var pick = candidates[_rng.randi_range(0, candidates.size() - 1)]
        var chosen = _weighted_pick(possibilities[pick.y][pick.x], rules)
        collapsed[pick.y][pick.x] = chosen
        possibilities[pick.y][pick.x] = [chosen]

        _propagate(possibilities, collapsed, rules, pick.x, pick.y, width, height)

    # Fill any remaining uncollapsed cells
    for y in range(height):
        for x in range(width):
            if collapsed[y][x] == "":
                collapsed[y][x] = "wall"

    return collapsed

func _constrain_borders(possibilities: Array, rules: TileRules, width: int, height: int) -> void:
    var non_walkable: Array = []
    for name in rules.get_all_tile_names():
        var tile = rules.get_tile(name)
        if not tile.walkable:
            non_walkable.append(name)

    for x in range(width):
        possibilities[0][x] = non_walkable.duplicate()
        possibilities[height - 1][x] = non_walkable.duplicate()
    for y in range(height):
        possibilities[y][0] = non_walkable.duplicate()
        possibilities[y][width - 1] = non_walkable.duplicate()

func _weighted_pick(options: Array, rules: TileRules) -> String:
    var total_weight := 0.0
    for name in options:
        total_weight += rules.get_tile(name).weight
    var roll = _rng.randf() * total_weight
    var running := 0.0
    for name in options:
        running += rules.get_tile(name).weight
        if roll <= running:
            return name
    return options[options.size() - 1]

func _propagate(possibilities: Array, collapsed: Array, rules: TileRules, x: int, y: int, width: int, height: int) -> void:
    var stack: Array[Vector2i] = [Vector2i(x, y)]
    var visited: Dictionary = {}

    while not stack.is_empty():
        var current = stack.pop_back()
        var cx = current.x
        var cy = current.y
        var key = "%d,%d" % [cx, cy]
        if visited.has(key):
            continue
        visited[key] = true

        var current_possible = possibilities[cy][cx]

        # Check each direction independently
        for d in range(DIRS.size()):
            var dir = DIRS[d]
            var dir_name = DIR_NAMES[d]
            var nx = cx + dir.x
            var ny = cy + dir.y
            if nx < 0 or nx >= width or ny < 0 or ny >= height:
                continue
            if collapsed[ny][nx] != "":
                continue

            # Collect tiles allowed in this direction from current cell's possibilities
            var valid_set: Dictionary = {}
            for tile_name in current_possible:
                var allowed = rules.get_allowed_neighbors_dir(tile_name, dir_name)
                if allowed:
                    for n in allowed:
                        valid_set[n] = true

            var before_size = possibilities[ny][nx].size()
            var filtered: Array = []
            for p in possibilities[ny][nx]:
                if valid_set.has(p):
                    filtered.append(p)
            possibilities[ny][nx] = filtered

            if filtered.size() < before_size:
                stack.append(Vector2i(nx, ny))
