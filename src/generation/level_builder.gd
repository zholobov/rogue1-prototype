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
				_add_ceiling(root, world_pos, tile_size)

				# Edge strips where walkable meets wall
				var accent_color = ThemeManager.active_theme.get_random_palette_color()
				_add_edge_strips(root, grid, x, y, width, height, world_pos, tile_size, accent_color)

				# Floor glow overlay for rooms
				if is_room and ThemeManager.active_theme.accent_use_palette:
					_add_floor_glow(root, world_pos, tile_size, accent_color)

				if tile.can_spawn:
					_add_spawn_point(root, world_pos, tile_size)

				# Point lights at theme-defined spacing
				if x % ThemeManager.active_theme.point_light_spacing == 1 and y % ThemeManager.active_theme.point_light_spacing == 1:
					_add_light(root, world_pos, tile_size, light_index)
					light_index += 1
			else:
				if tile_name == "wall":
					_add_wall_block(root, world_pos, tile_size, grid, x, y, width, height)

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

func _add_ceiling(parent: Node3D, pos: Vector3, tile_size: float) -> void:
	var ceiling = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
	ceiling.mesh = box_mesh
	ceiling.material_override = _ceiling_material
	ceiling.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT, tile_size / 2.0)
	parent.add_child(ceiling)

func _add_wall_block(parent: Node3D, pos: Vector3, tile_size: float, grid: Array, x: int, y: int, width: int, height: int) -> void:
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
			dmg_pos.y = randf_range(0.2, 0.8)
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
