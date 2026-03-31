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
