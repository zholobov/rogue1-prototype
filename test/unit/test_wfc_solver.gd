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
				assert_true(grid[y][x + 1] in allowed, "Adjacency violated at [%d,%d]->[%d,%d]: %s next to %s" % [x, y, x+1, y, tile, grid[y][x+1]])
			# Check bottom neighbor
			if y + 1 < grid.size():
				assert_true(grid[y + 1][x] in allowed, "Adjacency violated at [%d,%d]->[%d,%d]: %s next to %s" % [x, y, x, y+1, tile, grid[y+1][x]])

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
