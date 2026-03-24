# Procedural Level Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate playable 3D levels from configurable WFC rules — rooms, corridors, spawn points, and lighting — with deterministic seeding and runtime-adjustable parameters.

**Architecture:** A grid-based WFC solver operates on abstract tile types (room, corridor, wall, open) to produce a 2D layout. A geometry builder converts this layout into Godot 3D nodes (CSG boxes for walls/floors, lights, spawn markers). The generator is a standalone class (no ECS dependency) that returns a Node3D subtree. The level script wires generation output into the scene, adds ECS systems, and spawns actors at generated spawn points.

**Tech Stack:** Godot 4.4+, GDScript, CSGBox3D for geometry (no meshes/imports needed), existing GECS/ECS framework for gameplay

**Spec:** See `SPEC.md` — section: Procedural Generation

**Important:** GECS requires `ECS.world` created before adding systems/entities (done in level script). The generator itself does NOT use ECS — it produces geometry nodes. Actor spawning uses existing MonsterScene/PlayerEntity patterns.

---

## Scope

This plan covers **v1 procedural levels**: playable generated arenas with rooms and corridors. NOT covered (future plans): environment elemental interactions, destructibility, biomes, loot placement, difficulty scaling.

---

## File Structure

```
src/
  generation/
    wfc_solver.gd                  # NEW: WFC algorithm — grid collapse with backtracking
    tile_rules.gd                  # NEW: defines tile types, adjacency rules, weights
    level_builder.gd               # NEW: converts WFC grid into 3D geometry nodes
    level_generator.gd             # NEW: orchestrator — runs WFC + builder, returns Node3D
  config/
    game_config.gd                 # MODIFY: add generation parameters (grid size, seed, tile size)
  levels/
    generated_level.gd             # NEW: level script for generated levels (replaces test_level for runs)
    generated_level.tscn           # NEW: minimal scene (just root + script)
    test_level.gd                  # MODIFY: optionally use generator instead of static geometry
test/
  unit/
    test_wfc_solver.gd             # NEW: WFC constraint propagation and determinism tests
    test_tile_rules.gd             # NEW: adjacency rule validation tests
    test_level_builder.gd          # NEW: geometry output validation tests
```

---

### Task 1: Tile Rules — Define Tile Types and Adjacency Constraints

**Files:**
- Create: `src/generation/tile_rules.gd`
- Create: `test/unit/test_tile_rules.gd`

- [ ] **Step 1: Write failing tests**

Create `test/unit/test_tile_rules.gd`:
```gdscript
extends GutTest

var rules: TileRules

func before_each():
    rules = TileRules.new()
    rules.setup_defaults()

func test_has_default_tile_types():
    assert_true(rules.has_tile("room"))
    assert_true(rules.has_tile("corridor"))
    assert_true(rules.has_tile("wall"))
    assert_true(rules.has_tile("empty"))

func test_tile_has_properties():
    var room = rules.get_tile("room")
    assert_not_null(room)
    assert_has(room, "name")
    assert_has(room, "weight")
    assert_has(room, "walkable")

func test_room_is_walkable():
    var room = rules.get_tile("room")
    assert_true(room.walkable)

func test_wall_is_not_walkable():
    var wall = rules.get_tile("wall")
    assert_false(wall.walkable)

func test_adjacency_rules_exist():
    var allowed = rules.get_allowed_neighbors("room")
    assert_not_null(allowed)
    assert_true(allowed.size() > 0)

func test_room_can_neighbor_corridor():
    var allowed = rules.get_allowed_neighbors("room")
    assert_true("corridor" in allowed)

func test_room_can_neighbor_room():
    var allowed = rules.get_allowed_neighbors("room")
    assert_true("room" in allowed)

func test_corridor_can_neighbor_room():
    var allowed = rules.get_allowed_neighbors("corridor")
    assert_true("room" in allowed)

func test_empty_cannot_neighbor_room():
    var allowed = rules.get_allowed_neighbors("empty")
    assert_false("room" in allowed)

func test_unknown_tile_returns_null():
    assert_null(rules.get_tile("nonexistent"))

func test_weight_is_positive():
    for tile_name in rules.get_all_tile_names():
        var tile = rules.get_tile(tile_name)
        assert_gt(tile.weight, 0.0, "Tile '%s' should have positive weight" % tile_name)
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
godot --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit -gselect=test_tile_rules
```
Expected: FAIL — `TileRules` not found.

- [ ] **Step 3: Implement TileRules**

Create `src/generation/tile_rules.gd`:
```gdscript
class_name TileRules
extends RefCounted

# Tile definitions: { name, weight, walkable, can_spawn }
var tiles: Dictionary = {}

# Adjacency rules: tile_name -> Array[String] of allowed neighbor tile names
var adjacency: Dictionary = {}

func setup_defaults() -> void:
    add_tile("room", 1.0, true, true)
    add_tile("corridor", 0.8, true, false)
    add_tile("wall", 1.5, false, false)
    add_tile("empty", 2.0, false, false)

    # Adjacency: which tiles can be next to each other
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
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add src/generation/tile_rules.gd test/unit/test_tile_rules.gd
git commit -m "feat: add TileRules with tile types and adjacency constraints"
```

---

### Task 2: WFC Solver — Grid-Based Wave Function Collapse

**Files:**
- Create: `src/generation/wfc_solver.gd`
- Create: `test/unit/test_wfc_solver.gd`

- [ ] **Step 1: Write failing tests**

Create `test/unit/test_wfc_solver.gd`:
```gdscript
extends GutTest

var rules: TileRules
var solver: WFCSolver

func before_each():
    rules = TileRules.new()
    rules.setup_defaults()
    solver = WFCSolver.new()

func test_solve_returns_grid():
    var grid = solver.solve(rules, 4, 4, 42)
    assert_not_null(grid)
    assert_eq(grid.size(), 4)
    assert_eq(grid[0].size(), 4)

func test_grid_contains_valid_tiles():
    var grid = solver.solve(rules, 4, 4, 42)
    var valid_names = rules.get_all_tile_names()
    for y in range(grid.size()):
        for x in range(grid[y].size()):
            assert_true(grid[y][x] in valid_names, "Cell [%d,%d] has invalid tile '%s'" % [x, y, grid[y][x]])

func test_adjacency_respected():
    var grid = solver.solve(rules, 6, 6, 42)
    for y in range(grid.size()):
        for x in range(grid[y].size()):
            var tile = grid[y][x]
            var allowed = rules.get_allowed_neighbors(tile)
            # Check right neighbor
            if x + 1 < grid[y].size():
                assert_true(grid[y][x + 1] in allowed, "Adjacency violated at [%d,%d]→[%d,%d]: %s next to %s" % [x, y, x+1, y, tile, grid[y][x+1]])
            # Check bottom neighbor
            if y + 1 < grid.size():
                assert_true(grid[y + 1][x] in allowed, "Adjacency violated at [%d,%d]→[%d,%d]: %s next to %s" % [x, y, x, y+1, tile, grid[y+1][x]])

func test_deterministic_with_same_seed():
    var grid_a = solver.solve(rules, 8, 8, 123)
    var grid_b = solver.solve(rules, 8, 8, 123)
    assert_eq(grid_a, grid_b, "Same seed should produce identical grids")

func test_different_seeds_produce_different_grids():
    var grid_a = solver.solve(rules, 8, 8, 100)
    var grid_b = solver.solve(rules, 8, 8, 200)
    assert_ne(grid_a, grid_b, "Different seeds should usually produce different grids")

func test_has_walkable_tiles():
    var grid = solver.solve(rules, 8, 8, 42)
    var has_walkable = false
    for y in range(grid.size()):
        for x in range(grid[y].size()):
            if rules.get_tile(grid[y][x]).walkable:
                has_walkable = true
                break
    assert_true(has_walkable, "Grid should contain at least one walkable tile")

func test_border_is_wall_or_empty():
    var grid = solver.solve(rules, 8, 8, 42)
    var h = grid.size()
    var w = grid[0].size()
    for x in range(w):
        assert_false(rules.get_tile(grid[0][x]).walkable, "Top border should not be walkable")
        assert_false(rules.get_tile(grid[h-1][x]).walkable, "Bottom border should not be walkable")
    for y in range(h):
        assert_false(rules.get_tile(grid[y][0]).walkable, "Left border should not be walkable")
        assert_false(rules.get_tile(grid[y][w-1]).walkable, "Right border should not be walkable")
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement WFCSolver**

Create `src/generation/wfc_solver.gd`:
```gdscript
class_name WFCSolver
extends RefCounted

## Grid-based Wave Function Collapse solver.
## Each cell starts with all possible tiles, then collapses via constraint propagation.

var _rng: RandomNumberGenerator

func solve(rules: TileRules, width: int, height: int, seed: int) -> Array:
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

    var max_iterations = width * height * 10  # safety limit
    var iterations = 0

    while iterations < max_iterations:
        iterations += 1

        # Find cell with lowest entropy (fewest possibilities) that isn't collapsed
        var min_entropy = 999
        var candidates: Array = []
        for y in range(height):
            for x in range(width):
                if collapsed[y][x] != "":
                    continue
                var entropy = possibilities[y][x].size()
                if entropy == 0:
                    # Contradiction — restart with offset seed
                    return solve(rules, width, height, seed + 1)
                if entropy < min_entropy:
                    min_entropy = entropy
                    candidates = [Vector2i(x, y)]
                elif entropy == min_entropy:
                    candidates.append(Vector2i(x, y))

        if candidates.is_empty():
            break  # All collapsed

        # Pick random cell among lowest entropy
        var pick = candidates[_rng.randi_range(0, candidates.size() - 1)]
        var px = pick.x
        var py = pick.y

        # Collapse: pick tile weighted by tile weight
        var chosen = _weighted_pick(possibilities[py][px], rules)
        collapsed[py][px] = chosen
        possibilities[py][px] = [chosen]

        # Propagate constraints to neighbors
        _propagate(possibilities, collapsed, rules, px, py, width, height)

    # Fill any remaining uncollapsed cells (shouldn't happen but safety)
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

        # Collect all tiles that could be neighbors of any tile in current cell
        var valid_neighbor_set: Dictionary = {}
        for tile_name in current_possible:
            var allowed = rules.get_allowed_neighbors(tile_name)
            if allowed:
                for n in allowed:
                    valid_neighbor_set[n] = true

        # Check each neighbor
        var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
        for dir in dirs:
            var nx = cx + dir.x
            var ny = cy + dir.y
            if nx < 0 or nx >= width or ny < 0 or ny >= height:
                continue
            if collapsed[ny][nx] != "":
                continue

            var before_size = possibilities[ny][nx].size()
            var filtered: Array = []
            for p in possibilities[ny][nx]:
                if valid_neighbor_set.has(p):
                    filtered.append(p)
            possibilities[ny][nx] = filtered

            if filtered.size() < before_size:
                stack.append(Vector2i(nx, ny))
```

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add src/generation/wfc_solver.gd test/unit/test_wfc_solver.gd
git commit -m "feat: add WFC solver with constraint propagation and deterministic seeding"
```

---

### Task 3: Level Builder — Convert WFC Grid to 3D Geometry

**Files:**
- Create: `src/generation/level_builder.gd`
- Create: `test/unit/test_level_builder.gd`

- [ ] **Step 1: Write failing tests**

Create `test/unit/test_level_builder.gd`:
```gdscript
extends GutTest

var builder: LevelBuilder
var rules: TileRules

func before_each():
    rules = TileRules.new()
    rules.setup_defaults()
    builder = LevelBuilder.new()

func test_build_returns_node3d():
    var grid = [["wall", "wall"], ["wall", "wall"]]
    var result = builder.build(grid, rules, 4.0)
    assert_not_null(result)
    assert_true(result is Node3D)
    result.queue_free()

func test_build_creates_floor_for_walkable():
    var grid = [["wall", "wall", "wall"], ["wall", "room", "wall"], ["wall", "wall", "wall"]]
    var result = builder.build(grid, rules, 4.0)
    var floors = _find_children_by_group(result, "floor")
    assert_gt(floors.size(), 0, "Should have floor geometry for walkable tiles")
    result.queue_free()

func test_build_creates_walls():
    var grid = [["wall", "wall", "wall"], ["wall", "room", "wall"], ["wall", "wall", "wall"]]
    var result = builder.build(grid, rules, 4.0)
    var walls = _find_children_by_group(result, "wall_geo")
    assert_gt(walls.size(), 0, "Should have wall geometry")
    result.queue_free()

func test_build_creates_spawn_points_for_rooms():
    var grid = [["wall", "wall", "wall"], ["wall", "room", "wall"], ["wall", "wall", "wall"]]
    var result = builder.build(grid, rules, 4.0)
    var spawns = _find_children_by_group(result, "spawn_point")
    assert_gt(spawns.size(), 0, "Room tiles should generate spawn points")
    result.queue_free()

func test_build_creates_light():
    var grid = [["wall", "wall", "wall"], ["wall", "room", "wall"], ["wall", "wall", "wall"]]
    var result = builder.build(grid, rules, 4.0)
    var lights = _find_children_of_type(result, "OmniLight3D")
    assert_gt(lights.size(), 0, "Should have at least one light")
    result.queue_free()

func test_tile_size_affects_position():
    var grid = [["wall", "room"], ["wall", "wall"]]
    var result_small = builder.build(grid, rules, 2.0)
    var result_large = builder.build(grid, rules, 8.0)
    # The geometry positions should differ
    var small_floors = _find_children_by_group(result_small, "floor")
    var large_floors = _find_children_by_group(result_large, "floor")
    if small_floors.size() > 0 and large_floors.size() > 0:
        assert_ne(small_floors[0].position, large_floors[0].position, "Tile size should affect positions")
    result_small.queue_free()
    result_large.queue_free()

func _find_children_by_group(node: Node, group: String) -> Array[Node]:
    var found: Array[Node] = []
    for child in node.get_children():
        if child.is_in_group(group):
            found.append(child)
        found.append_array(_find_children_by_group(child, group))
    return found

func _find_children_of_type(node: Node, type_name: String) -> Array[Node]:
    var found: Array[Node] = []
    for child in node.get_children():
        if child.get_class() == type_name:
            found.append(child)
        found.append_array(_find_children_of_type(child, type_name))
    return found
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement LevelBuilder**

Create `src/generation/level_builder.gd`:
```gdscript
class_name LevelBuilder
extends RefCounted

## Converts a 2D tile grid into 3D geometry nodes.
## Uses CSGBox3D for walls/floors (no external assets needed).

const WALL_HEIGHT := 3.0
const FLOOR_THICKNESS := 0.2

func build(grid: Array, rules: TileRules, tile_size: float) -> Node3D:
    var root = Node3D.new()
    root.name = "GeneratedLevel"

    var height = grid.size()
    var width = grid[0].size() if height > 0 else 0

    for y in range(height):
        for x in range(width):
            var tile_name = grid[y][x]
            var tile = rules.get_tile(tile_name)
            if not tile:
                continue

            var world_pos = Vector3(x * tile_size, 0, y * tile_size)

            if tile.walkable:
                _add_floor(root, world_pos, tile_size)
                _add_ceiling(root, world_pos, tile_size)
                if tile.can_spawn:
                    _add_spawn_point(root, world_pos, tile_size)
                # Add light every few room tiles
                if x % 3 == 1 and y % 3 == 1:
                    _add_light(root, world_pos, tile_size)
            else:
                if tile_name == "wall":
                    _add_wall_block(root, world_pos, tile_size)

    # Add ambient directional light as fallback
    var dir_light = DirectionalLight3D.new()
    dir_light.transform = Transform3D(Basis(), Vector3(0, 10, 0))
    dir_light.rotation_degrees = Vector3(-45, 30, 0)
    dir_light.light_energy = 0.3
    root.add_child(dir_light)

    return root

func _add_floor(parent: Node3D, pos: Vector3, tile_size: float) -> void:
    var floor_body = StaticBody3D.new()
    floor_body.position = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)
    floor_body.add_to_group("floor")

    var mesh_inst = MeshInstance3D.new()
    var box_mesh = BoxMesh.new()
    box_mesh.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
    mesh_inst.mesh = box_mesh
    floor_body.add_child(mesh_inst)

    var col = CollisionShape3D.new()
    var box_shape = BoxShape3D.new()
    box_shape.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
    col.shape = box_shape
    floor_body.add_child(col)

    parent.add_child(floor_body)

func _add_ceiling(parent: Node3D, pos: Vector3, tile_size: float) -> void:
    var ceiling = MeshInstance3D.new()
    var box_mesh = BoxMesh.new()
    box_mesh.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
    ceiling.mesh = box_mesh
    ceiling.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT, tile_size / 2.0)
    parent.add_child(ceiling)

func _add_wall_block(parent: Node3D, pos: Vector3, tile_size: float) -> void:
    var wall_body = StaticBody3D.new()
    wall_body.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT / 2.0, tile_size / 2.0)
    wall_body.add_to_group("wall_geo")

    var mesh_inst = MeshInstance3D.new()
    var box_mesh = BoxMesh.new()
    box_mesh.size = Vector3(tile_size, WALL_HEIGHT, tile_size)
    mesh_inst.mesh = box_mesh
    wall_body.add_child(mesh_inst)

    var col = CollisionShape3D.new()
    var box_shape = BoxShape3D.new()
    box_shape.size = Vector3(tile_size, WALL_HEIGHT, tile_size)
    col.shape = box_shape
    wall_body.add_child(col)

    parent.add_child(wall_body)

func _add_spawn_point(parent: Node3D, pos: Vector3, tile_size: float) -> void:
    var marker = Marker3D.new()
    marker.position = pos + Vector3(tile_size / 2.0, 1.0, tile_size / 2.0)
    marker.add_to_group("spawn_point")
    parent.add_child(marker)

func _add_light(parent: Node3D, pos: Vector3, tile_size: float) -> void:
    var light = OmniLight3D.new()
    light.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT - 0.5, tile_size / 2.0)
    light.omni_range = tile_size * 2.0
    light.light_energy = 1.5
    parent.add_child(light)

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add src/generation/level_builder.gd test/unit/test_level_builder.gd
git commit -m "feat: add LevelBuilder — converts WFC grid to 3D geometry"
```

---

### Task 4: Level Generator — Orchestrator

**Files:**
- Create: `src/generation/level_generator.gd`

- [ ] **Step 1: Create orchestrator**

Create `src/generation/level_generator.gd`:
```gdscript
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
        spawn_points.append(child.global_position if child.is_inside_tree() else child.position)

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
```

- [ ] **Step 2: Commit**

```bash
git add src/generation/level_generator.gd
git commit -m "feat: add LevelGenerator orchestrator — WFC + builder pipeline"
```

---

### Task 5: Generation Config — Runtime Parameters

**Files:**
- Modify: `src/config/game_config.gd`

- [ ] **Step 1: Add generation parameters to GameConfig**

Add to `src/config/game_config.gd` after the weapon presets section:
```gdscript
# Level generation
@export var level_grid_width: int = 12
@export var level_grid_height: int = 12
@export var level_tile_size: float = 4.0
@export var level_seed: int = 0  # 0 = random seed
@export var monsters_per_room: int = 1
```

- [ ] **Step 2: Commit**

```bash
git add src/config/game_config.gd
git commit -m "feat: add level generation config parameters"
```

---

### Task 6: Generated Level Scene — Playable Generated Level

**Files:**
- Create: `src/levels/generated_level.gd`
- Create: `src/levels/generated_level.tscn`

- [ ] **Step 1: Create generated level script**

Create `src/levels/generated_level.gd`:
```gdscript
extends Node3D

const HUDScene = preload("res://src/ui/hud.tscn")
const ProjectileScene = preload("res://src/entities/projectile.tscn")
const MonsterScene = preload("res://src/entities/monster.tscn")

var weapon_system: S_Weapon
var level_data: Dictionary = {}

func _ready():
    # Create and register the ECS world
    var world = World.new()
    world.name = "World"
    add_child(world)
    ECS.world = world

    # Register all systems
    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())
    ECS.world.add_system(S_Conditions.new())
    ECS.world.add_system(S_Lifetime.new())
    ECS.world.add_system(S_Death.new())
    ECS.world.add_system(S_MonsterAI.new())

    weapon_system = S_Weapon.new()
    weapon_system.projectile_requested.connect(_on_projectile_requested)
    ECS.world.add_system(weapon_system)

    # Generate level
    var gen = LevelGenerator.new()
    var seed_val = Config.level_seed if Config.level_seed != 0 else randi()
    level_data = gen.generate(Config.level_grid_width, Config.level_grid_height, seed_val, Config.level_tile_size)
    add_child(level_data.geometry)

    print("Level generated with seed: %d" % level_data.seed)

    # HUD
    var hud = HUDScene.instantiate()
    add_child(hud)

    # Spawn monsters at spawn points
    _spawn_monsters()

func get_spawn_points() -> Array[Vector3]:
    var points: Array[Vector3] = []
    for child in _find_in_group(level_data.geometry, "spawn_point"):
        points.append(child.global_position)
    return points

func get_player_spawn() -> Vector3:
    var points = get_spawn_points()
    if points.size() > 0:
        return points[0]
    return Vector3(0, 1, 0)  # fallback

func _spawn_monsters() -> void:
    var spawn_points = get_spawn_points()
    # Skip the first spawn point (used for player)
    for i in range(1, spawn_points.size()):
        for _m in range(Config.monsters_per_room):
            var monster = MonsterScene.instantiate()
            var offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
            monster.position = spawn_points[i] + offset
            add_child(monster)

func _physics_process(delta: float) -> void:
    ECS.process(delta)

func _on_projectile_requested(owner_body: Node3D, weapon: C_Weapon) -> void:
    var projectile = ProjectileScene.instantiate()
    var camera = owner_body.get_node("Camera3D") as Camera3D
    var spawn_pos = camera.global_position + (-camera.global_transform.basis.z * 1.0)
    projectile.global_position = spawn_pos
    add_child(projectile)
    projectile.setup(
        -camera.global_transform.basis.z,
        weapon.projectile_speed,
        weapon.damage,
        weapon.element,
        owner_body.get_instance_id()
    )

func _find_in_group(node: Node, group: String) -> Array[Node]:
    var found: Array[Node] = []
    for child in node.get_children():
        if child.is_in_group(group):
            found.append(child)
        found.append_array(_find_in_group(child, group))
    return found
```

- [ ] **Step 2: Create minimal scene**

Create `src/levels/generated_level.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/levels/generated_level.gd" id="1"]

[node name="GeneratedLevel" type="Node3D"]
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add src/levels/generated_level.gd src/levels/generated_level.tscn
git commit -m "feat: add generated level scene with WFC generation and monster spawning"
```

---

### Task 7: Wire Up Main — Use Generated Levels

**Files:**
- Modify: `src/main.gd`

- [ ] **Step 1: Update main.gd to use generated levels**

In `src/main.gd`, change the level preload and update spawn logic to use generated spawn points:

Replace `const TestLevel = preload("res://src/levels/test_level.tscn")` with:
```gdscript
const GeneratedLevel = preload("res://src/levels/generated_level.tscn")
const TestLevel = preload("res://src/levels/test_level.tscn")  # keep as fallback
```

Replace `_start_game()`:
```gdscript
func _start_game():
    current_level = GeneratedLevel.instantiate()
    add_child(current_level)

    if is_solo:
        _spawn_player(1, true)
    else:
        _spawn_player(Net.my_peer_id, true)
        for peer_id in Net.peers:
            _spawn_player(peer_id, false)
        Net.player_connected.connect(_on_player_joined)
        Net.player_disconnected.connect(_on_player_left)
```

Replace `_spawn_player()` to use generated spawn points:
```gdscript
func _spawn_player(peer_id: int, is_local: bool) -> void:
    var player = PlayerScene.instantiate()
    player.name = "Player_%d" % peer_id

    var spawn_pos = Vector3(0, 1, 0)
    if current_level.has_method("get_player_spawn"):
        spawn_pos = current_level.get_player_spawn()

    player.position = spawn_pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
    current_level.add_child(player)
    player.setup(peer_id, is_local)
```

- [ ] **Step 2: Commit**

```bash
git add src/main.gd
git commit -m "feat: wire main.gd to use generated levels with spawn points"
```

---

## Summary

After completing all 7 tasks, you will have:
- **TileRules** — configurable tile types (room, corridor, wall, empty) with adjacency constraints and weights
- **WFCSolver** — grid-based Wave Function Collapse with constraint propagation, backtracking, deterministic seeding
- **LevelBuilder** — converts 2D tile grids to 3D geometry (CSG walls, floors, ceilings, lights, spawn points)
- **LevelGenerator** — orchestrates WFC + builder pipeline
- **GeneratedLevel** — playable scene that generates a level, spawns monsters at room spawn points, has full combat
- **Main wiring** — game starts with a generated level instead of the static test level
- **Config** — grid size, tile size, seed, monsters per room all runtime-configurable
- 26+ unit tests covering tile rules, WFC constraints, determinism, and geometry output

**Next plan:** Plan 4 — Game Loop & Progression (hub, run structure, inter-level, boss)
