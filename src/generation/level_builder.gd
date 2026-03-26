class_name LevelBuilder
extends RefCounted

## Converts a 2D tile grid into 3D geometry nodes.

const WALL_HEIGHT := 3.0
const FLOOR_THICKNESS := 0.2

var _floor_material_room: StandardMaterial3D
var _floor_material_corridor: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D

func _init() -> void:
	var theme = ThemeManager.active_theme

	_floor_material_room = StandardMaterial3D.new()
	_floor_material_room.albedo_color = theme.floor_albedo
	_floor_material_room.roughness = theme.floor_roughness

	_floor_material_corridor = StandardMaterial3D.new()
	_floor_material_corridor.albedo_color = theme.corridor_floor_albedo
	_floor_material_corridor.roughness = theme.corridor_floor_roughness

	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = theme.wall_albedo
	_wall_material.roughness = theme.wall_roughness

	_ceiling_material = StandardMaterial3D.new()
	_ceiling_material.albedo_color = theme.ceiling_albedo
	_ceiling_material.roughness = theme.ceiling_roughness

	var textures = TextureFactory.get_cached()
	if textures.has("floor"):
		_floor_material_room.albedo_texture = textures["floor"]
	if textures.has("corridor_floor"):
		_floor_material_corridor.albedo_texture = textures["corridor_floor"]
	elif textures.has("floor"):
		_floor_material_corridor.albedo_texture = textures["floor"]
	if textures.has("wall"):
		_wall_material.albedo_texture = textures["wall"]
	if textures.has("ceiling"):
		_ceiling_material.albedo_texture = textures["ceiling"]

## Apply UV scaling at build time via _apply_uv_scaling()
func _apply_uv_scaling(tile_size: float) -> void:
	# Target: one texture repeat per ~2 meters
	_floor_material_room.uv1_scale = Vector3(tile_size / 2.0, tile_size / 2.0, 1.0)
	_floor_material_corridor.uv1_scale = Vector3(tile_size / 2.0, tile_size / 2.0, 1.0)
	_wall_material.uv1_scale = Vector3(tile_size / 2.0, WALL_HEIGHT / 2.0, 1.0)
	_ceiling_material.uv1_scale = Vector3(tile_size / 2.0, tile_size / 2.0, 1.0)

func build(grid: Array, rules: TileRules, tile_size: float) -> Node3D:
	_apply_uv_scaling(tile_size)
	var root = Node3D.new()
	root.name = "GeneratedLevel"

	var height = grid.size()
	var width = grid[0].size() if height > 0 else 0
	var light_index := 0

	for y in range(height):
		for x in range(width):
			var tile_name = grid[y][x]
			var tile = rules.get_tile(tile_name)
			if not tile:
				continue

			var world_pos = Vector3(x * tile_size, 0, y * tile_size)

			if tile.walkable:
				var is_room = (tile_name == "room" or tile_name == "spawn")
				var floor_mat = _floor_material_room if is_room else _floor_material_corridor
				_add_floor(root, world_pos, tile_size, floor_mat)
				if ThemeManager.active_theme.has_ceiling:
					_add_ceiling(root, world_pos, tile_size, is_room)

				# Edge strips where walkable meets wall
				var accent_color = ThemeManager.active_theme.get_random_palette_color()
				_add_edge_strips(root, grid, x, y, width, height, world_pos, tile_size, accent_color)

				# Floor glow overlay for rooms
				if is_room and ThemeManager.active_theme.accent_use_palette:
					_add_floor_glow(root, world_pos, tile_size, accent_color)

				if tile.can_spawn:
					_add_spawn_point(root, world_pos, tile_size)

				# Lights: torches for prop themes, floating for others
				if ThemeManager.active_theme.prop_density > 0.0:
					pass  # Torch pass happens after main loop
				else:
					if x % ThemeManager.active_theme.point_light_spacing == 1 and y % ThemeManager.active_theme.point_light_spacing == 1:
						_add_light(root, world_pos, tile_size, light_index)
						light_index += 1
			else:
				if tile_name == "wall":
					_add_wall_block(root, world_pos, tile_size, grid, x, y, width, height)

	# Ceiling beams
	var beam_spacing = ThemeManager.active_theme.ceiling_beam_spacing
	if ThemeManager.active_theme.has_ceiling and ThemeManager.active_theme.prop_density > 0.0 and beam_spacing > 0:
		for y in range(height):
			for x in range(width):
				var tile_name = grid[y][x]
				var tile = rules.get_tile(tile_name)
				if not tile or not tile.walkable:
					continue
				var world_pos_beam = Vector3(x * tile_size, 0, y * tile_size)
				var is_room_tile = (tile_name == "room" or tile_name == "spawn")
				# Z-direction beams every beam_spacing tiles
				if y % beam_spacing == 0:
					_add_ceiling_beam(root, world_pos_beam, tile_size, true)
				# X-direction beams in rooms for grid pattern
				if is_room_tile and x % beam_spacing == 0:
					_add_ceiling_beam(root, world_pos_beam, tile_size, false)

	# Torch placement (wall-adjacent)
	if ThemeManager.active_theme.prop_density > 0.0:
		var torch_candidates: Array = []
		for y in range(height):
			for x in range(width):
				var tile_name = grid[y][x]
				var tile = rules.get_tile(tile_name)
				if not tile or not tile.walkable:
					continue
				# Check if adjacent to a wall
				var wall_dir := Vector2i.ZERO
				for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nx = x + dir.x
					var ny = y + dir.y
					if nx >= 0 and nx < width and ny >= 0 and ny < height:
						if grid[ny][nx] == "wall":
							wall_dir = dir
							break
				if wall_dir != Vector2i.ZERO:
					torch_candidates.append({"x": x, "y": y, "dir": wall_dir})

		# Space torches by skipping candidates (global stride — good enough for prototype)
		var spacing = maxi(ThemeManager.active_theme.point_light_spacing, 1)
		var light_style = ThemeManager.active_theme.light_source_style
		for i in range(0, torch_candidates.size(), spacing):
			var c = torch_candidates[i]
			var world_pos_torch = Vector3(c.x * tile_size, 0, c.y * tile_size)
			match light_style:
				"mushroom":
					_add_mushroom_light(root, world_pos_torch, tile_size, c.dir, light_index)
				"crystal":
					_add_crystal_light(root, world_pos_torch, tile_size, c.dir, light_index)
				_:
					_add_torch(root, world_pos_torch, tile_size, c.dir, light_index)
			light_index += 1

	# Props (pillars, rubble, room props)
	if ThemeManager.active_theme.prop_density > 0.0:
		var room_spawn_positions: Array[Vector3] = []
		for child in root.get_children():
			if child.is_in_group("spawn_point"):
				room_spawn_positions.append(child.position)

		# Collect room tiles for room-prop placement
		var room_tiles: Array = []

		for y in range(height):
			for x in range(width):
				var tile_name = grid[y][x]
				var tile = rules.get_tile(tile_name)
				if not tile or not tile.walkable:
					continue
				var world_pos_prop = Vector3(x * tile_size, 0, y * tile_size)
				var is_room_tile = (tile_name == "room" or tile_name == "spawn")

				if is_room_tile:
					room_tiles.append(world_pos_prop)

				# Rubble along wall edges
				var next_to_wall := false
				for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nx = x + dir.x
					var ny = y + dir.y
					if nx >= 0 and nx < width and ny >= 0 and ny < height:
						if grid[ny][nx] == "wall":
							next_to_wall = true
							break
				if next_to_wall and randf() < ThemeManager.active_theme.rubble_chance * ThemeManager.active_theme.prop_density:
					_add_rubble(root, world_pos_prop, tile_size)

				# Pillars at room corners (walkable tile with 2+ adjacent walls forming corner)
				if is_room_tile:
					var wall_count := 0
					var has_north_wall := false
					var has_south_wall := false
					var has_east_wall := false
					var has_west_wall := false
					for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						var nx = x + dir.x
						var ny = y + dir.y
						if nx >= 0 and nx < width and ny >= 0 and ny < height:
							if grid[ny][nx] == "wall":
								wall_count += 1
								if dir == Vector2i(0, -1): has_north_wall = true
								elif dir == Vector2i(0, 1): has_south_wall = true
								elif dir == Vector2i(-1, 0): has_west_wall = true
								elif dir == Vector2i(1, 0): has_east_wall = true
					if wall_count >= 2 and randf() < ThemeManager.active_theme.pillar_chance * ThemeManager.active_theme.prop_density:
						var corner_offset = Vector3.ZERO
						if has_north_wall and has_west_wall:
							corner_offset = Vector3(-tile_size * 0.35, 0, -tile_size * 0.35)
						elif has_north_wall and has_east_wall:
							corner_offset = Vector3(tile_size * 0.35, 0, -tile_size * 0.35)
						elif has_south_wall and has_west_wall:
							corner_offset = Vector3(-tile_size * 0.35, 0, tile_size * 0.35)
						elif has_south_wall and has_east_wall:
							corner_offset = Vector3(tile_size * 0.35, 0, tile_size * 0.35)
						if corner_offset != Vector3.ZERO:
							_add_pillar(root, world_pos_prop + Vector3(tile_size / 2.0, 0, tile_size / 2.0) + corner_offset)

		# Room props (barrels, crates, chains)
		var prop_types = ["barrel", "crate", "chain"]
		var placed_this_room := 0
		var room_prop_max_count = ThemeManager.active_theme.room_prop_max
		var room_prop_min_count = ThemeManager.active_theme.room_prop_min
		# Simple approach: iterate room tiles and place props with chance
		var total_room_props := randi_range(room_prop_min_count, room_prop_max_count) * maxi(room_tiles.size() / 20, 1)
		room_tiles.shuffle()
		for i in range(mini(total_room_props, room_tiles.size())):
			var prop_pos = room_tiles[i] + Vector3(tile_size / 2.0 + randf_range(-0.3, 0.3), 0, tile_size / 2.0 + randf_range(-0.3, 0.3))
			# Check distance from spawn points
			var too_close := false
			for sp in room_spawn_positions:
				if prop_pos.distance_to(sp) < 1.0:
					too_close = true
					break
			if too_close:
				continue
			var prop_type = prop_types[randi() % prop_types.size()]
			match prop_type:
				"barrel":
					_add_barrel(root, prop_pos)
				"crate":
					_add_crate(root, prop_pos)
				"chain":
					_add_chain(root, prop_pos)

	# Directional light from theme
	var dir_light = DirectionalLight3D.new()
	dir_light.transform = Transform3D(Basis(), Vector3(0, 10, 0))
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_energy = ThemeManager.active_theme.directional_light_energy
	dir_light.light_color = ThemeManager.active_theme.directional_light_color
	root.add_child(dir_light)

	return root

func _add_floor(parent: Node3D, pos: Vector3, tile_size: float, mat: StandardMaterial3D) -> void:
	var floor_body = StaticBody3D.new()
	floor_body.position = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)
	floor_body.add_to_group("floor")

	# Collision stays as single box
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
	col.shape = box_shape
	floor_body.add_child(col)

	if ThemeManager.active_theme.prop_density > 0.0:
		_add_slab_grid(floor_body, tile_size, mat)
	else:
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
		mesh_inst.mesh = box_mesh
		mesh_inst.material_override = mat
		floor_body.add_child(mesh_inst)

	parent.add_child(floor_body)

func _add_slab_grid(floor_body: StaticBody3D, tile_size: float, mat: StandardMaterial3D) -> void:
	var gap := 0.025
	var slab_size := (tile_size - gap) / 2.0
	var theme = ThemeManager.active_theme

	for row in range(2):
		for col_idx in range(2):
			var y_offset := randf_range(-0.03, 0.03)
			var local_x := (col_idx - 0.5) * (slab_size + gap)
			var local_z := (row - 0.5) * (slab_size + gap)

			# Cracked slab: ~10% chance
			if randf() < 0.1:
				_add_cracked_slab(floor_body, local_x, local_z, y_offset, slab_size, mat, theme)
			else:
				var slab_mat := mat.duplicate() as StandardMaterial3D
				slab_mat.roughness = mat.roughness + randf_range(-0.05, 0.05)
				var mesh_inst = MeshInstance3D.new()
				var box_mesh = BoxMesh.new()
				box_mesh.size = Vector3(slab_size, FLOOR_THICKNESS, slab_size)
				mesh_inst.mesh = box_mesh
				mesh_inst.material_override = slab_mat
				mesh_inst.position = Vector3(local_x, y_offset, local_z)
				floor_body.add_child(mesh_inst)

func _add_cracked_slab(floor_body: StaticBody3D, local_x: float, local_z: float, y_offset: float, slab_size: float, mat: StandardMaterial3D, theme: ThemeData) -> void:
	var crack_gap := 0.03
	var split_along_x := randf() > 0.5
	var half_size: float = (slab_size - crack_gap) / 2.0

	for i in range(2):
		var slab_mat := mat.duplicate() as StandardMaterial3D
		slab_mat.roughness = mat.roughness + randf_range(-0.05, 0.05)
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		var offset_dir := (i * 2.0 - 1.0) * (half_size + crack_gap) / 2.0

		if split_along_x:
			box_mesh.size = Vector3(half_size, FLOOR_THICKNESS, slab_size)
			mesh_inst.position = Vector3(local_x + offset_dir, y_offset, local_z)
		else:
			box_mesh.size = Vector3(slab_size, FLOOR_THICKNESS, half_size)
			mesh_inst.position = Vector3(local_x, y_offset, local_z + offset_dir)

		mesh_inst.mesh = box_mesh
		mesh_inst.material_override = slab_mat
		floor_body.add_child(mesh_inst)

func _add_ceiling(parent: Node3D, pos: Vector3, tile_size: float, is_room: bool) -> void:
	var theme = ThemeManager.active_theme
	if theme.prop_density > 0.0:
		# Recessed panel (slightly higher)
		var panel = MeshInstance3D.new()
		var panel_mesh = BoxMesh.new()
		panel_mesh.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
		panel.mesh = panel_mesh
		panel.material_override = _ceiling_material
		panel.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT + 0.1, tile_size / 2.0)
		parent.add_child(panel)
	else:
		var ceiling = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
		ceiling.mesh = box_mesh
		ceiling.material_override = _ceiling_material
		ceiling.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT, tile_size / 2.0)
		parent.add_child(ceiling)

func _add_ceiling_beam(parent: Node3D, pos: Vector3, tile_size: float, along_x: bool) -> void:
	var beam = MeshInstance3D.new()
	var beam_mesh = BoxMesh.new()
	if along_x:
		beam_mesh.size = Vector3(tile_size, 0.15, 0.12)
	else:
		beam_mesh.size = Vector3(0.12, 0.15, tile_size)
	beam.mesh = beam_mesh
	beam.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT, tile_size / 2.0)

	var beam_mat = StandardMaterial3D.new()
	var theme = ThemeManager.active_theme
	beam_mat.albedo_color = Color(
		theme.ceiling_albedo.r - 0.05,
		theme.ceiling_albedo.g - 0.05,
		theme.ceiling_albedo.b - 0.05
	)
	beam_mat.roughness = 0.9
	beam.material_override = beam_mat
	parent.add_child(beam)

func _add_wall_block(parent: Node3D, pos: Vector3, tile_size: float, grid: Array, x: int, y: int, width: int, height: int) -> void:
	var style = ThemeManager.active_theme.wall_style
	if style != "default":
		_add_styled_wall(parent, pos, tile_size, grid, x, y, width, height, style)
		return
	var wall_body = StaticBody3D.new()
	wall_body.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT / 2.0, tile_size / 2.0)
	wall_body.add_to_group("wall_geo")

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(tile_size, WALL_HEIGHT, tile_size)
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = _wall_material
	wall_body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(tile_size, WALL_HEIGHT, tile_size)
	col.shape = box_shape
	wall_body.add_child(col)

	parent.add_child(wall_body)

	# Stone protrusions on faces adjacent to walkable tiles
	if ThemeManager.active_theme.prop_density > 0.0:
		_add_wall_detail(parent, pos, tile_size, grid, x, y, width, height)

func _add_wall_detail(parent: Node3D, pos: Vector3, tile_size: float, grid: Array, x: int, y: int, width: int, height: int) -> void:
	var theme = ThemeManager.active_theme
	var dirs = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
	]
	for dir in dirs:
		var nx = x + dir.x
		var ny = y + dir.y
		if nx < 0 or nx >= width or ny < 0 or ny >= height:
			continue
		# "empty" is a real tile type in TileRules (non-walkable, non-wall filler)
		if grid[ny][nx] == "wall" or grid[ny][nx] == "empty":
			continue

		# This face is adjacent to walkable — add protrusions
		var face_center = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)
		var num_protrusions = randi_range(2, 4)
		for _i in range(num_protrusions):
			var depth = randf_range(0.05, 0.15)
			var prot_w = randf_range(0.15, 0.4)
			var prot_h = randf_range(0.15, 0.3)
			var prot_y = randf_range(0.3, WALL_HEIGHT - 0.3)

			var prot = MeshInstance3D.new()
			var prot_mesh = BoxMesh.new()
			var prot_pos = face_center

			if dir.x != 0:
				prot_mesh.size = Vector3(depth, prot_h, prot_w)
				prot_pos.x += dir.x * (tile_size / 2.0 + depth / 2.0)
				prot_pos.z += randf_range(-tile_size * 0.3, tile_size * 0.3)
			else:
				prot_mesh.size = Vector3(prot_w, prot_h, depth)
				prot_pos.z += dir.y * (tile_size / 2.0 + depth / 2.0)
				prot_pos.x += randf_range(-tile_size * 0.3, tile_size * 0.3)
			prot_pos.y = prot_y

			prot.mesh = prot_mesh
			prot.position = prot_pos

			var prot_mat = _wall_material.duplicate() as StandardMaterial3D
			var variation = randf_range(-0.03, 0.03)
			prot_mat.albedo_color = Color(
				clampf(theme.wall_albedo.r + variation, 0.0, 1.0),
				clampf(theme.wall_albedo.g + variation, 0.0, 1.0),
				clampf(theme.wall_albedo.b + variation, 0.0, 1.0)
			)
			prot.material_override = prot_mat
			parent.add_child(prot)

		# Damage spot — 20% chance per face
		if randf() < 0.2:
			var dmg = MeshInstance3D.new()
			var dmg_mesh = BoxMesh.new()
			dmg_mesh.size = Vector3(0.3, 0.3, 0.3)
			var dmg_pos = face_center
			if dir.x != 0:
				dmg_pos.x += dir.x * (tile_size / 2.0 - 0.05)
			else:
				dmg_pos.z += dir.y * (tile_size / 2.0 - 0.05)
			dmg_pos.y = randf_range(0.3, WALL_HEIGHT - 0.3)
			dmg.mesh = dmg_mesh
			dmg.position = dmg_pos
			var dmg_mat = StandardMaterial3D.new()
			dmg_mat.albedo_color = Color(
				theme.wall_albedo.r - 0.08,
				theme.wall_albedo.g - 0.08,
				theme.wall_albedo.b - 0.08
			)
			dmg_mat.roughness = 1.0
			dmg.material_override = dmg_mat
			parent.add_child(dmg)

func _add_styled_wall(parent: Node3D, pos: Vector3, tile_size: float, grid: Array, x: int, y: int, width: int, height: int, style: String) -> void:
	# Always add collision (same as default wall)
	var wall_body = StaticBody3D.new()
	wall_body.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT / 2.0, tile_size / 2.0)
	wall_body.add_to_group("wall_geo")
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(tile_size, WALL_HEIGHT, tile_size)
	col.shape = box_shape
	wall_body.add_child(col)
	parent.add_child(wall_body)

	match style:
		"forest_thicket":
			_add_forest_wall(parent, pos, tile_size)
		"palace_ornate":
			_add_palace_wall(parent, pos, tile_size)
		"ice_crystal":
			_add_ice_wall(parent, pos, tile_size)

func _add_forest_wall(parent: Node3D, pos: Vector3, tile_size: float) -> void:
	var cx = pos.x + tile_size / 2.0
	var cz = pos.z + tile_size / 2.0
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(pos.x), int(pos.z)))
	# 2-3 tree trunks
	var trunk_count = rng.randi_range(2, 3)
	for i in range(trunk_count):
		var trunk = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		var radius = rng.randf_range(0.15, 0.3)
		cyl.top_radius = radius
		cyl.bottom_radius = radius * 1.1
		cyl.height = WALL_HEIGHT + rng.randf_range(-0.3, 0.3)
		trunk.mesh = cyl
		trunk.material_override = _wall_material
		var offset_x = rng.randf_range(-tile_size * 0.35, tile_size * 0.35)
		var offset_z = rng.randf_range(-tile_size * 0.35, tile_size * 0.35)
		trunk.position = Vector3(cx + offset_x, cyl.height / 2.0, cz + offset_z)
		parent.add_child(trunk)
		# Knot on trunk
		if rng.randf() < 0.6:
			var knot = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = rng.randf_range(0.05, 0.1)
			sphere.height = sphere.radius * 2.0
			knot.mesh = sphere
			knot.material_override = _wall_material
			knot.position = trunk.position + Vector3(radius * 0.8, rng.randf_range(0.5, 2.0), 0)
			parent.add_child(knot)
	# Branch crossbeam
	var branch = MeshInstance3D.new()
	var branch_mesh = BoxMesh.new()
	branch_mesh.size = Vector3(tile_size * 0.5, 0.08, 0.06)
	branch.mesh = branch_mesh
	branch.material_override = _wall_material
	branch.position = Vector3(cx, rng.randf_range(1.0, 2.0), cz)
	branch.rotation_degrees.z = rng.randf_range(-15, 15)
	parent.add_child(branch)
	# Moss patch (emissive)
	if rng.randf() < 0.5:
		var moss = MeshInstance3D.new()
		var moss_mesh = BoxMesh.new()
		moss_mesh.size = Vector3(0.2, 0.1, 0.15)
		moss.mesh = moss_mesh
		var moss_mat = StandardMaterial3D.new()
		moss_mat.albedo_color = Color(0.15, 0.3, 0.1)
		moss_mat.emission_enabled = true
		moss_mat.emission = Color(0.2, 0.5, 0.15)
		moss_mat.emission_energy_multiplier = 1.0
		moss.material_override = moss_mat
		moss.position = Vector3(cx + rng.randf_range(-0.3, 0.3), rng.randf_range(0.5, 1.5), cz + rng.randf_range(-0.3, 0.3))
		parent.add_child(moss)
	# Root tangle at base
	var root_mesh = MeshInstance3D.new()
	var root_box = BoxMesh.new()
	root_box.size = Vector3(tile_size * 0.8, 0.15, tile_size * 0.6)
	root_mesh.mesh = root_box
	root_mesh.material_override = _wall_material
	root_mesh.position = Vector3(cx, 0.075, cz)
	parent.add_child(root_mesh)

func _add_palace_wall(parent: Node3D, pos: Vector3, tile_size: float) -> void:
	var theme = ThemeManager.active_theme
	var cx = pos.x + tile_size / 2.0
	var cz = pos.z + tile_size / 2.0
	# Base wall panel
	var base = MeshInstance3D.new()
	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(tile_size, WALL_HEIGHT, tile_size)
	base.mesh = base_mesh
	base.material_override = _wall_material
	base.position = Vector3(cx, WALL_HEIGHT / 2.0, cz)
	parent.add_child(base)
	# Horizontal log lines (4)
	for i in range(4):
		var line = MeshInstance3D.new()
		var line_mesh = BoxMesh.new()
		line_mesh.size = Vector3(tile_size + 0.02, 0.03, tile_size + 0.02)
		line.mesh = line_mesh
		var dark_mat = StandardMaterial3D.new()
		dark_mat.albedo_color = theme.wall_albedo.darkened(0.3)
		dark_mat.roughness = 0.9
		line.material_override = dark_mat
		line.position = Vector3(cx, 0.5 + i * 0.65, cz)
		parent.add_child(line)
	# Pilaster column (left edge)
	var pilaster = MeshInstance3D.new()
	var pil_mesh = BoxMesh.new()
	pil_mesh.size = Vector3(0.2, WALL_HEIGHT, 0.2)
	pilaster.mesh = pil_mesh
	var pil_mat = StandardMaterial3D.new()
	pil_mat.albedo_color = theme.wall_albedo.lightened(0.15)
	pil_mat.roughness = 0.85
	pilaster.material_override = pil_mat
	pilaster.position = Vector3(pos.x + 0.1, WALL_HEIGHT / 2.0, cz)
	parent.add_child(pilaster)
	# Capital on pilaster
	var capital = MeshInstance3D.new()
	var cap_mesh = BoxMesh.new()
	cap_mesh.size = Vector3(0.3, 0.1, 0.3)
	capital.mesh = cap_mesh
	capital.material_override = pil_mat
	capital.position = Vector3(pos.x + 0.1, WALL_HEIGHT - 0.05, cz)
	parent.add_child(capital)
	# Gold trim strip
	var trim = MeshInstance3D.new()
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(tile_size * 0.7, 0.04, 0.02)
	trim.mesh = trim_mesh
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.6, 0.45, 0.1)
	gold_mat.emission_enabled = true
	gold_mat.emission = Color(0.85, 0.65, 0.2)
	gold_mat.emission_energy_multiplier = 2.0
	trim.material_override = gold_mat
	trim.position = Vector3(cx, WALL_HEIGHT - 0.15, pos.z + 0.01)
	parent.add_child(trim)
	# Ornamental panel (recessed)
	var panel = MeshInstance3D.new()
	var panel_mesh = BoxMesh.new()
	panel_mesh.size = Vector3(tile_size * 0.5, 0.8, 0.05)
	panel.mesh = panel_mesh
	var panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_color = theme.wall_albedo.darkened(0.2)
	panel_mat.roughness = 0.9
	panel.material_override = panel_mat
	panel.position = Vector3(cx, 1.2, pos.z + 0.03)
	parent.add_child(panel)
	# Gold ornament sphere in panel
	var ornament = MeshInstance3D.new()
	var orn_mesh = SphereMesh.new()
	orn_mesh.radius = 0.06
	orn_mesh.height = 0.12
	ornament.mesh = orn_mesh
	ornament.material_override = gold_mat
	ornament.position = Vector3(cx, 1.2, pos.z + 0.06)
	parent.add_child(ornament)
	# Baseboard
	var baseboard = MeshInstance3D.new()
	var bb_mesh = BoxMesh.new()
	bb_mesh.size = Vector3(tile_size + 0.02, 0.12, tile_size + 0.02)
	baseboard.mesh = bb_mesh
	baseboard.material_override = pil_mat
	baseboard.position = Vector3(cx, 0.06, cz)
	parent.add_child(baseboard)

func _add_ice_wall(parent: Node3D, pos: Vector3, tile_size: float) -> void:
	var theme = ThemeManager.active_theme
	var cx = pos.x + tile_size / 2.0
	var cz = pos.z + tile_size / 2.0
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(pos.x), int(pos.z)))
	# Shared materials
	var ice_colors = [
		Color(theme.wall_albedo.r - 0.05, theme.wall_albedo.g - 0.03, theme.wall_albedo.b),
		theme.wall_albedo,
		Color(theme.wall_albedo.r + 0.05, theme.wall_albedo.g + 0.05, theme.wall_albedo.b + 0.08),
	]
	var snow_mat = StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.85, 0.88, 0.92)
	snow_mat.roughness = 0.8
	var frost_mat = StandardMaterial3D.new()
	frost_mat.albedo_color = Color(0.7, 0.85, 1.0)
	frost_mat.emission_enabled = true
	frost_mat.emission = Color(0.7, 0.88, 1.0)
	frost_mat.emission_energy_multiplier = 2.0
	# Snow base across bottom
	var snow_base = MeshInstance3D.new()
	var snow_mesh = BoxMesh.new()
	snow_mesh.size = Vector3(tile_size * 0.95, 0.25, tile_size * 0.95)
	snow_base.mesh = snow_mesh
	snow_base.material_override = snow_mat
	snow_base.position = Vector3(cx, 0.125, cz)
	parent.add_child(snow_base)
	# Packed crystal pillars — 10-14 tightly filling the tile
	var pillar_count = rng.randi_range(10, 14)
	var half = tile_size * 0.42
	for i in range(pillar_count):
		var crystal = MeshInstance3D.new()
		var crystal_mesh = BoxMesh.new()
		var crystal_h = rng.randf_range(WALL_HEIGHT * 0.6, WALL_HEIGHT + 0.3)
		var crystal_w = rng.randf_range(0.15, 0.35)
		var crystal_d = rng.randf_range(0.12, 0.3)
		crystal_mesh.size = Vector3(crystal_w, crystal_h, crystal_d)
		crystal.mesh = crystal_mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = ice_colors[rng.randi() % ice_colors.size()]
		mat.roughness = rng.randf_range(0.15, 0.3)
		crystal.material_override = mat
		crystal.position = Vector3(
			cx + rng.randf_range(-half, half),
			crystal_h / 2.0 + 0.1,
			cz + rng.randf_range(-half, half)
		)
		crystal.rotation_degrees.y = rng.randf_range(-15, 15)
		crystal.rotation_degrees.z = rng.randf_range(-5, 5)
		parent.add_child(crystal)
	# Frost sparkles (3-4 scattered across crystals)
	for i in range(rng.randi_range(3, 4)):
		var sparkle = MeshInstance3D.new()
		var spark_mesh = SphereMesh.new()
		spark_mesh.radius = 0.04
		spark_mesh.height = 0.08
		sparkle.mesh = spark_mesh
		sparkle.material_override = frost_mat
		sparkle.position = Vector3(
			cx + rng.randf_range(-half, half),
			rng.randf_range(0.8, WALL_HEIGHT * 0.8),
			cz + rng.randf_range(-half * 0.5, half * 0.5)
		)
		parent.add_child(sparkle)
	# Icicles from top (3-4)
	var ice_hang_mat = StandardMaterial3D.new()
	ice_hang_mat.albedo_color = Color(0.55, 0.7, 0.9)
	ice_hang_mat.roughness = 0.15
	for i in range(rng.randi_range(3, 4)):
		var icicle = MeshInstance3D.new()
		var icicle_mesh = CylinderMesh.new()
		icicle_mesh.top_radius = 0.015
		icicle_mesh.bottom_radius = 0.05
		icicle_mesh.height = rng.randf_range(0.3, 0.7)
		icicle.mesh = icicle_mesh
		icicle.material_override = ice_hang_mat
		icicle.position = Vector3(
			cx + rng.randf_range(-half, half),
			WALL_HEIGHT - icicle_mesh.height / 2.0,
			cz + rng.randf_range(-half, half)
		)
		parent.add_child(icicle)

func _add_spawn_point(parent: Node3D, pos: Vector3, tile_size: float) -> void:
	var marker = Marker3D.new()
	marker.position = pos + Vector3(tile_size / 2.0, 1.0, tile_size / 2.0)
	marker.add_to_group("spawn_point")
	parent.add_child(marker)

func _add_light(parent: Node3D, pos: Vector3, tile_size: float, index: int) -> void:
	var theme = ThemeManager.active_theme
	var light = OmniLight3D.new()
	light.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT - 0.5, tile_size / 2.0)
	light.omni_range = tile_size * theme.point_light_range_mult
	light.light_energy = theme.point_light_energy
	light.omni_attenuation = theme.point_light_attenuation
	var palette = theme.get_palette_array()
	light.light_color = palette[index % palette.size()]
	parent.add_child(light)

func _add_torch(parent: Node3D, pos: Vector3, tile_size: float, wall_dir: Vector2i, index: int) -> void:
	var theme = ThemeManager.active_theme
	var torch_root = Node3D.new()
	torch_root.name = "Torch_%d" % index
	var base_pos = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)

	# Mount position on wall face
	var mount_y := WALL_HEIGHT * 0.6
	var mount_pos: Vector3 = base_pos
	if wall_dir.x != 0:
		mount_pos.x += wall_dir.x * (tile_size / 2.0 - 0.05)
	else:
		mount_pos.z += wall_dir.y * (tile_size / 2.0 - 0.05)
	mount_pos.y = mount_y
	torch_root.position = mount_pos

	# Bracket: box on wall
	var bracket = MeshInstance3D.new()
	var bracket_mesh = BoxMesh.new()
	bracket_mesh.size = Vector3(0.1, 0.05, 0.1)
	bracket.mesh = bracket_mesh
	var bracket_mat = StandardMaterial3D.new()
	bracket_mat.albedo_color = Color(0.15, 0.12, 0.08)
	bracket_mat.roughness = 0.8
	bracket.material_override = bracket_mat
	torch_root.add_child(bracket)

	# Arm: angled box
	var arm = MeshInstance3D.new()
	var arm_mesh = BoxMesh.new()
	arm_mesh.size = Vector3(0.03, 0.15, 0.03)
	arm.mesh = arm_mesh
	arm.position = Vector3(0, 0.1, 0)
	arm.material_override = bracket_mat
	torch_root.add_child(arm)

	# Torch body: cylinder
	var body = MeshInstance3D.new()
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.03
	body_mesh.bottom_radius = 0.03
	body_mesh.height = 0.2
	body.mesh = body_mesh
	body.position = Vector3(0, 0.27, 0)
	body.material_override = bracket_mat
	torch_root.add_child(body)

	# Flame: small emissive box
	var flame = MeshInstance3D.new()
	var flame_mesh = BoxMesh.new()
	flame_mesh.size = Vector3(0.06, 0.08, 0.06)
	flame.mesh = flame_mesh
	flame.position = Vector3(0, 0.41, 0)
	var flame_mat = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(0.1, 0.05, 0.0)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.6, 0.15)
	flame_mat.emission_energy_multiplier = 3.0
	flame.material_override = flame_mat
	torch_root.add_child(flame)

	# Light at flame position
	var light = OmniLight3D.new()
	light.position = Vector3(0, 0.41, 0)
	light.omni_range = tile_size * theme.point_light_range_mult
	light.light_energy = theme.point_light_energy
	light.omni_attenuation = theme.point_light_attenuation
	light.light_color = theme.point_light_color
	torch_root.add_child(light)

	# Flicker tween
	if theme.torch_flicker:
		var tween = parent.create_tween().set_loops()
		tween.tween_property(light, "light_energy", theme.point_light_energy * 0.7, randf_range(0.1, 0.3))
		tween.tween_property(light, "light_energy", theme.point_light_energy, randf_range(0.1, 0.3))

	parent.add_child(torch_root)

func _add_mushroom_light(parent: Node3D, pos: Vector3, tile_size: float, wall_dir: Vector2i, index: int) -> void:
	var theme = ThemeManager.active_theme
	var light_root = Node3D.new()
	light_root.name = "Mushroom_%d" % index
	var base_pos = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)
	var mount_pos: Vector3 = base_pos
	if wall_dir.x != 0:
		mount_pos.x += wall_dir.x * (tile_size / 2.0 - 0.2)
	else:
		mount_pos.z += wall_dir.y * (tile_size / 2.0 - 0.2)
	mount_pos.y = 0.0
	light_root.position = mount_pos
	# Stem: thin cylinder
	var stem = MeshInstance3D.new()
	var stem_mesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.04
	stem_mesh.bottom_radius = 0.05
	stem_mesh.height = 0.3
	stem.mesh = stem_mesh
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.25, 0.2, 0.15)
	stem_mat.roughness = 0.9
	stem.material_override = stem_mat
	stem.position = Vector3(0, 0.15, 0)
	light_root.add_child(stem)
	# Cap: wide flat sphere (emissive)
	var cap = MeshInstance3D.new()
	var cap_mesh = SphereMesh.new()
	cap_mesh.radius = 0.15
	cap_mesh.height = 0.12
	cap.mesh = cap_mesh
	var cap_mat = StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.1, 0.2, 0.08)
	cap_mat.emission_enabled = true
	cap_mat.emission = theme.point_light_color
	cap_mat.emission_energy_multiplier = 2.5
	cap.material_override = cap_mat
	cap.position = Vector3(0, 0.35, 0)
	light_root.add_child(cap)
	# Light
	var light = OmniLight3D.new()
	light.position = Vector3(0, 0.4, 0)
	light.omni_range = tile_size * theme.point_light_range_mult
	light.light_energy = theme.point_light_energy
	light.omni_attenuation = theme.point_light_attenuation
	light.light_color = theme.point_light_color
	light_root.add_child(light)
	if theme.torch_flicker:
		var tween = parent.create_tween().set_loops()
		tween.tween_property(light, "light_energy", theme.point_light_energy * 0.6, randf_range(0.2, 0.5))
		tween.tween_property(light, "light_energy", theme.point_light_energy, randf_range(0.2, 0.5))
	parent.add_child(light_root)

func _add_crystal_light(parent: Node3D, pos: Vector3, tile_size: float, wall_dir: Vector2i, index: int) -> void:
	var theme = ThemeManager.active_theme
	var light_root = Node3D.new()
	light_root.name = "Crystal_%d" % index
	var base_pos = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)
	var mount_pos: Vector3 = base_pos
	if wall_dir.x != 0:
		mount_pos.x += wall_dir.x * (tile_size / 2.0 - 0.15)
	else:
		mount_pos.z += wall_dir.y * (tile_size / 2.0 - 0.15)
	mount_pos.y = 0.0
	light_root.position = mount_pos
	# Ice crystal: tall narrow emissive box
	var crystal = MeshInstance3D.new()
	var crystal_mesh = BoxMesh.new()
	crystal_mesh.size = Vector3(0.1, 0.5, 0.08)
	crystal.mesh = crystal_mesh
	var crystal_mat = StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.3, 0.5, 0.8)
	crystal_mat.roughness = 0.15
	crystal_mat.emission_enabled = true
	crystal_mat.emission = theme.point_light_color
	crystal_mat.emission_energy_multiplier = 2.0
	crystal.material_override = crystal_mat
	crystal.position = Vector3(0, 0.25, 0)
	crystal.rotation_degrees.z = randf_range(-10, 10)
	light_root.add_child(crystal)
	# Smaller shard next to it
	var shard = MeshInstance3D.new()
	var shard_mesh = BoxMesh.new()
	shard_mesh.size = Vector3(0.06, 0.3, 0.05)
	shard.mesh = shard_mesh
	shard.material_override = crystal_mat
	shard.position = Vector3(0.08, 0.15, 0.04)
	shard.rotation_degrees.z = randf_range(-15, 15)
	light_root.add_child(shard)
	# Light
	var light = OmniLight3D.new()
	light.position = Vector3(0, 0.35, 0)
	light.omni_range = tile_size * theme.point_light_range_mult
	light.light_energy = theme.point_light_energy
	light.omni_attenuation = theme.point_light_attenuation
	light.light_color = theme.point_light_color
	light_root.add_child(light)
	# No flicker — steady frozen glow
	parent.add_child(light_root)

func _add_edge_strips(parent: Node3D, grid: Array, x: int, y: int, width: int, height: int, pos: Vector3, tile_size: float, accent: Color) -> void:
	var dirs = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
	]
	for dir in dirs:
		var nx = x + dir.x
		var ny = y + dir.y
		if nx < 0 or nx >= width or ny < 0 or ny >= height:
			continue
		if grid[ny][nx] == "wall":
			if ThemeManager.active_theme.accent_use_palette:
				_place_strip(parent, pos, tile_size, dir, accent, 0.0)
				_place_strip(parent, pos, tile_size, dir, accent, WALL_HEIGHT)
			else:
				_place_wall_trim(parent, pos, tile_size, dir, 0.0)
				_place_wall_trim(parent, pos, tile_size, dir, WALL_HEIGHT)

func _place_strip(parent: Node3D, pos: Vector3, tile_size: float, dir: Vector2i, color: Color, y_offset: float) -> void:
	var strip = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	var center = pos + Vector3(tile_size / 2.0, y_offset, tile_size / 2.0)
	if dir.x != 0:
		mesh.size = Vector3(0.05, 0.02, tile_size)
		center.x += dir.x * (tile_size / 2.0 - 0.025)
	else:
		mesh.size = Vector3(tile_size, 0.02, 0.05)
		center.z += dir.y * (tile_size / 2.0 - 0.025)
	strip.mesh = mesh
	strip.position = center
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = randf_range(ThemeManager.active_theme.accent_emission_energy * 0.67, ThemeManager.active_theme.accent_emission_energy)
	strip.material_override = mat
	parent.add_child(strip)

func _place_wall_trim(parent: Node3D, pos: Vector3, tile_size: float, dir: Vector2i, y_offset: float) -> void:
	var trim = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	var center = pos + Vector3(tile_size / 2.0, y_offset, tile_size / 2.0)
	if dir.x != 0:
		mesh.size = Vector3(0.08, 0.04, tile_size)
		center.x += dir.x * (tile_size / 2.0 - 0.04)
	else:
		mesh.size = Vector3(tile_size, 0.04, 0.08)
		center.z += dir.y * (tile_size / 2.0 - 0.04)
	trim.mesh = mesh
	trim.position = center
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(
		ThemeManager.active_theme.wall_albedo.r - 0.05,
		ThemeManager.active_theme.wall_albedo.g - 0.05,
		ThemeManager.active_theme.wall_albedo.b - 0.05
	)
	mat.roughness = 0.95
	trim.material_override = mat
	parent.add_child(trim)

func _add_floor_glow(parent: Node3D, pos: Vector3, tile_size: float, color: Color) -> void:
	var glow = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(tile_size, 0.01, tile_size)
	glow.mesh = mesh
	glow.position = pos + Vector3(tile_size / 2.0, 0.01, tile_size / 2.0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	glow.material_override = mat

	parent.add_child(glow)

func _add_rubble(parent: Node3D, pos: Vector3, tile_size: float) -> void:
	var theme = ThemeManager.active_theme
	var rubble_color = Color(
		theme.floor_albedo.r - 0.05,
		theme.floor_albedo.g - 0.05,
		theme.floor_albedo.b - 0.05
	)
	var center = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)
	var num_pieces = randi_range(3, 6)
	for _i in range(num_pieces):
		var piece = MeshInstance3D.new()
		var size = randf_range(0.05, 0.15)
		if randf() > 0.5:
			var box = BoxMesh.new()
			box.size = Vector3(size, size * 0.6, size * randf_range(0.7, 1.3))
			piece.mesh = box
		else:
			var sphere = SphereMesh.new()
			sphere.radius = size / 2.0
			sphere.height = size
			piece.mesh = sphere
		piece.position = center + Vector3(randf_range(-0.3, 0.3), size * 0.3, randf_range(-0.3, 0.3))
		var mat = StandardMaterial3D.new()
		mat.albedo_color = rubble_color
		mat.roughness = 1.0
		piece.material_override = mat
		parent.add_child(piece)

func _add_pillar(parent: Node3D, pos: Vector3) -> void:
	var theme = ThemeManager.active_theme
	var pillar_mat = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(
		theme.wall_albedo.r + 0.03,
		theme.wall_albedo.g + 0.03,
		theme.wall_albedo.b + 0.03
	)
	pillar_mat.roughness = 0.85

	# Base
	var base = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.2
	base_mesh.bottom_radius = 0.2
	base_mesh.height = 0.15
	base.mesh = base_mesh
	base.position = pos + Vector3(0, 0.075, 0)
	base.material_override = pillar_mat
	parent.add_child(base)

	# Shaft
	var shaft = MeshInstance3D.new()
	var shaft_mesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.12
	shaft_mesh.bottom_radius = 0.12
	shaft_mesh.height = WALL_HEIGHT - 0.3
	shaft.mesh = shaft_mesh
	shaft.position = pos + Vector3(0, WALL_HEIGHT / 2.0, 0)
	shaft.material_override = pillar_mat
	parent.add_child(shaft)

	# Capital
	var capital = MeshInstance3D.new()
	var cap_mesh = CylinderMesh.new()
	cap_mesh.top_radius = 0.2
	cap_mesh.bottom_radius = 0.2
	cap_mesh.height = 0.15
	capital.mesh = cap_mesh
	capital.position = pos + Vector3(0, WALL_HEIGHT - 0.075, 0)
	capital.material_override = pillar_mat
	parent.add_child(capital)

func _add_barrel(parent: Node3D, pos: Vector3) -> void:
	var barrel_mat = StandardMaterial3D.new()
	barrel_mat.albedo_color = Color(0.35, 0.22, 0.1)
	barrel_mat.roughness = 0.9

	# Body
	var body = MeshInstance3D.new()
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.15
	body_mesh.bottom_radius = 0.15
	body_mesh.height = 0.4
	body.mesh = body_mesh
	body.position = pos + Vector3(0, 0.2, 0)
	body.material_override = barrel_mat
	parent.add_child(body)

	# Rim
	var rim = MeshInstance3D.new()
	var rim_mesh = CylinderMesh.new()
	rim_mesh.top_radius = 0.16
	rim_mesh.bottom_radius = 0.16
	rim_mesh.height = 0.02
	rim.mesh = rim_mesh
	rim.position = pos + Vector3(0, 0.41, 0)
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.2, 0.15, 0.08)
	rim_mat.roughness = 0.7
	rim.material_override = rim_mat
	parent.add_child(rim)

func _add_crate(parent: Node3D, pos: Vector3) -> void:
	var crate_mat = StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.3, 0.2, 0.1)
	crate_mat.roughness = 0.95

	# Box body
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.3, 0.3, 0.3)
	body.mesh = body_mesh
	body.position = pos + Vector3(0, 0.15, 0)
	body.material_override = crate_mat
	parent.add_child(body)

	# Cross strip
	var strip_mat = StandardMaterial3D.new()
	strip_mat.albedo_color = Color(0.2, 0.12, 0.06)
	strip_mat.roughness = 0.8

	var h_strip = MeshInstance3D.new()
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(0.32, 0.02, 0.04)
	h_strip.mesh = h_mesh
	h_strip.position = pos + Vector3(0, 0.15, -0.16)
	h_strip.material_override = strip_mat
	parent.add_child(h_strip)

	var v_strip = MeshInstance3D.new()
	var v_mesh = BoxMesh.new()
	v_mesh.size = Vector3(0.04, 0.32, 0.02)
	v_strip.mesh = v_mesh
	v_strip.position = pos + Vector3(0, 0.15, -0.16)
	v_strip.material_override = strip_mat
	parent.add_child(v_strip)

func _add_chain(parent: Node3D, pos: Vector3) -> void:
	var chain_mat = StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.25, 0.22, 0.2)
	chain_mat.roughness = 0.6

	var num_links = randi_range(5, 8)
	for i in range(num_links):
		var link = MeshInstance3D.new()
		var link_mesh = BoxMesh.new()
		link_mesh.size = Vector3(0.03, 0.06, 0.03)
		link.mesh = link_mesh
		link.position = pos + Vector3(0, WALL_HEIGHT - 0.1 - i * 0.08, 0)
		link.material_override = chain_mat
		parent.add_child(link)
