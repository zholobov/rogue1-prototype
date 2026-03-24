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
