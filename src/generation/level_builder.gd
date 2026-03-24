class_name LevelBuilder
extends RefCounted

## Converts a 2D tile grid into 3D geometry nodes.
## Uses CSGBox3D for walls/floors (no external assets needed).

const WALL_HEIGHT := 3.0
const FLOOR_THICKNESS := 0.2

var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D

func _init() -> void:
	_floor_material = StandardMaterial3D.new()
	_floor_material.albedo_color = Color(0.35, 0.35, 0.3)

	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = Color(0.5, 0.45, 0.4)

	_ceiling_material = StandardMaterial3D.new()
	_ceiling_material.albedo_color = Color(0.25, 0.25, 0.25)

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

	# Add ambient directional light
	var dir_light = DirectionalLight3D.new()
	dir_light.transform = Transform3D(Basis(), Vector3(0, 10, 0))
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_energy = 1.0
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
	mesh_inst.material_override = _floor_material
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
	ceiling.material_override = _ceiling_material
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
	mesh_inst.material_override = _wall_material
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
