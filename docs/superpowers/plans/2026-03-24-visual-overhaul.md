# Visual Overhaul (Neon Dungeon) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the flat-colored prototype into a moody neon dungeon aesthetic with emissive materials, colored lighting, particle effects, and player feedback.

**Architecture:** All visuals use StandardMaterial3D emission and GPUParticles3D — no custom shaders. A shared NeonPalette provides color constants. VfxFactory creates particle effects. LevelBuilder and GeneratedLevel handle environment. Monster/projectile entities handle per-entity effects.

**Tech Stack:** Godot 4.6, GL Compatibility renderer, GDScript, GECS ECS framework

**Spec:** `docs/superpowers/specs/2026-03-24-visual-overhaul-design.md`

---

## File Structure

**Create:**
- `src/effects/neon_palette.gd` — Shared neon color palette constants and helper to pick random colors
- `src/effects/vfx_factory.gd` — Static factory methods for GPUParticles3D (muzzle flash, trail, impact)
- `src/effects/floating_text.gd` — Floating Label3D that rises and fades (for kill currency text)

**Modify:**
- `src/generation/level_builder.gd` — Dark materials, emissive edge strips, floor glow overlays, neon-colored OmniLights
- `src/levels/generated_level.gd` — Dark WorldEnvironment with fog, dimmer directional light, muzzle flash on fire
- `src/entities/monster.gd` — Dark emissive body, glowing eyes, size variation, hit flash, health bar
- `src/entities/projectile.gd` — Attach trail particles, spawn impact on collision
- `src/ui/hud.gd` — Damage flash overlay (track prev health, tween red ColorRect)
- `src/ui/hud.tscn` — Add DamageFlash ColorRect node
- `src/systems/s_death.gd` — Spawn floating kill text on monster death

---

### Task 1: Neon Palette

**Files:**
- Create: `src/effects/neon_palette.gd`

- [ ] **Step 1: Create NeonPalette class**

```gdscript
class_name NeonPalette
extends RefCounted

const CYAN := Color(0.0, 0.83, 1.0)
const MAGENTA := Color(1.0, 0.0, 0.67)
const PURPLE := Color(0.67, 0.27, 1.0)
const TEAL := Color(0.0, 1.0, 0.67)
const ORANGE := Color(1.0, 0.53, 0.0)

const ALL := [CYAN, MAGENTA, PURPLE, TEAL, ORANGE]

# Element to VFX color mapping
const ELEMENT_COLORS := {
    "": Color(1.0, 1.0, 1.0),
    "fire": Color(1.0, 0.27, 0.0),
    "ice": Color(0.0, 0.87, 1.0),
    "water": Color(0.0, 0.4, 1.0),
}

static func random_color() -> Color:
    return ALL[randi() % ALL.size()]

static func element_color(element: String) -> Color:
    return ELEMENT_COLORS.get(element, Color.WHITE)
```

- [ ] **Step 2: Verify file loads without errors**

Run: Open Godot editor or run the project. Check Output panel for parse errors on `neon_palette.gd`.

- [ ] **Step 3: Commit**

```bash
git add src/effects/neon_palette.gd
git commit -m "feat: add NeonPalette shared color constants"
```

---

### Task 2: LevelBuilder Dark Materials & Edge Strips

**Files:**
- Modify: `src/generation/level_builder.gd`

This task changes the LevelBuilder to use dark materials, add emissive edge strips along wall-floor/wall-ceiling seams, and add floor glow overlays for room tiles. The build() method needs the grid and rules passed through so it can check tile neighbors.

- [ ] **Step 1: Update material colors and add edge strip / glow overlay methods**

Replace the entire `level_builder.gd` with:

```gdscript
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
	_floor_material_room = StandardMaterial3D.new()
	_floor_material_room.albedo_color = Color(0.06, 0.05, 0.08)
	_floor_material_room.roughness = 0.9

	_floor_material_corridor = StandardMaterial3D.new()
	_floor_material_corridor.albedo_color = Color(0.04, 0.05, 0.07)
	_floor_material_corridor.roughness = 0.9

	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = Color(0.08, 0.08, 0.1)
	_wall_material.roughness = 0.85

	_ceiling_material = StandardMaterial3D.new()
	_ceiling_material.albedo_color = Color(0.03, 0.03, 0.05)
	_ceiling_material.roughness = 0.95

func build(grid: Array, rules: TileRules, tile_size: float) -> Node3D:
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
				var is_room = (tile_name == "room")
				var floor_mat = _floor_material_room if is_room else _floor_material_corridor
				_add_floor(root, world_pos, tile_size, floor_mat)
				_add_ceiling(root, world_pos, tile_size)

				# Edge strips where walkable meets wall
				var accent_color = NeonPalette.random_color()
				_add_edge_strips(root, grid, x, y, width, height, world_pos, tile_size, accent_color)

				# Floor glow overlay for rooms
				if is_room:
					_add_floor_glow(root, world_pos, tile_size, accent_color)

				if tile.can_spawn:
					_add_spawn_point(root, world_pos, tile_size)

				# Neon lights every 2x2 tiles
				if x % 2 == 1 and y % 2 == 1:
					_add_light(root, world_pos, tile_size, light_index)
					light_index += 1
			else:
				if tile_name == "wall":
					_add_wall_block(root, world_pos, tile_size)

	# Dim directional light — neon should dominate
	var dir_light = DirectionalLight3D.new()
	dir_light.transform = Transform3D(Basis(), Vector3(0, 10, 0))
	dir_light.rotation_degrees = Vector3(-45, 30, 0)
	dir_light.light_energy = 0.1
	dir_light.light_color = Color(0.6, 0.65, 0.8)
	root.add_child(dir_light)

	return root

func _add_floor(parent: Node3D, pos: Vector3, tile_size: float, mat: StandardMaterial3D) -> void:
	var floor_body = StaticBody3D.new()
	floor_body.position = pos + Vector3(tile_size / 2.0, 0, tile_size / 2.0)
	floor_body.add_to_group("floor")

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(tile_size, FLOOR_THICKNESS, tile_size)
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat
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

func _add_light(parent: Node3D, pos: Vector3, tile_size: float, index: int) -> void:
	var light = OmniLight3D.new()
	light.position = pos + Vector3(tile_size / 2.0, WALL_HEIGHT - 0.5, tile_size / 2.0)
	light.omni_range = tile_size * 1.5
	light.light_energy = 0.8
	light.omni_attenuation = 2.0
	light.light_color = NeonPalette.ALL[index % NeonPalette.ALL.size()]
	parent.add_child(light)

func _add_edge_strips(parent: Node3D, grid: Array, x: int, y: int, width: int, height: int, pos: Vector3, tile_size: float, accent: Color) -> void:
	# Check 4 cardinal neighbors; place strips where walkable meets wall
	var dirs = [
		Vector2i(0, -1),  # North (Z-)
		Vector2i(0, 1),   # South (Z+)
		Vector2i(-1, 0),  # West (X-)
		Vector2i(1, 0),   # East (X+)
	]
	for dir in dirs:
		var nx = x + dir.x
		var ny = y + dir.y
		if nx < 0 or nx >= width or ny < 0 or ny >= height:
			continue
		if grid[ny][nx] == "wall":
			_place_strip(parent, pos, tile_size, dir, accent, 0.0)  # Floor level
			_place_strip(parent, pos, tile_size, dir, accent, WALL_HEIGHT)  # Ceiling level

func _place_strip(parent: Node3D, pos: Vector3, tile_size: float, dir: Vector2i, color: Color, y_offset: float) -> void:
	var strip = MeshInstance3D.new()
	var mesh = BoxMesh.new()

	# Strip runs perpendicular to the wall direction
	var center = pos + Vector3(tile_size / 2.0, y_offset, tile_size / 2.0)
	if dir.x != 0:
		# East or West wall — strip runs along Z axis
		mesh.size = Vector3(0.05, 0.02, tile_size)
		center.x += dir.x * (tile_size / 2.0 - 0.025)
	else:
		# North or South wall — strip runs along X axis
		mesh.size = Vector3(tile_size, 0.02, 0.05)
		center.z += dir.y * (tile_size / 2.0 - 0.025)

	strip.mesh = mesh
	strip.position = center

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = randf_range(2.0, 3.0)
	strip.material_override = mat

	parent.add_child(strip)

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
```

- [ ] **Step 2: Visual test**

Run: `Play Solo` in Godot. Verify:
- Floors and walls are very dark
- Glowing colored edge strips appear where walkable tiles meet walls
- Room floors have a subtle colored glow
- Colored OmniLights illuminate pools of neon color
- Directional light is barely visible

- [ ] **Step 3: Commit**

```bash
git add src/generation/level_builder.gd
git commit -m "feat: neon dungeon materials, edge strips, floor glow, colored lights"
```

---

### Task 3: Dark WorldEnvironment & Fog

**Files:**
- Modify: `src/levels/generated_level.gd`

- [ ] **Step 1: Update the WorldEnvironment setup in _ready()**

In `src/levels/generated_level.gd`, replace the environment block (lines 13-22) with:

```gdscript
    # Neon dungeon environment
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.02, 0.02, 0.04)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.1, 0.1, 0.2)
    env.ambient_light_energy = 0.1
    # Depth fog (do NOT use volumetric — Forward+ only)
    env.fog_enabled = true
    env.fog_light_color = Color(0.02, 0.02, 0.06)
    env.fog_density = 0.02
    env.fog_depth_begin = 5.0
    env.fog_depth_end = 40.0
    env.fog_sky_affect = 0.0
    var world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
```

- [ ] **Step 2: Visual test**

Run: `Play Solo`. Verify:
- Background is near-black (not the previous blue-gray)
- Distant areas fade into dark blue fog
- Ambient light is very low — neon lights from Task 2 dominate

- [ ] **Step 3: Commit**

```bash
git add src/levels/generated_level.gd
git commit -m "feat: dark WorldEnvironment with depth fog"
```

---

### Task 4: VFX Factory

**Files:**
- Create: `src/effects/vfx_factory.gd`

- [ ] **Step 1: Create VfxFactory with static methods for all three particle effects**

```gdscript
class_name VfxFactory
extends RefCounted

static func create_muzzle_flash(pos: Vector3) -> GPUParticles3D:
    var particles = GPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 6
    particles.lifetime = 0.05
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)

    var mat = ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0, -1)
    mat.spread = 30.0
    mat.initial_velocity_min = 2.0
    mat.initial_velocity_max = 4.0
    mat.gravity = Vector3.ZERO
    mat.scale_min = 0.1
    mat.scale_max = 0.2
    particles.process_material = mat

    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = Color(1.0, 0.9, 0.6)
    draw_mat.emission_enabled = true
    draw_mat.emission = Color(1.0, 0.9, 0.6)
    draw_mat.emission_energy_multiplier = 5.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    var mesh = SphereMesh.new()
    mesh.radius = 0.03
    mesh.height = 0.06
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    return particles

static func create_trail(element: String) -> GPUParticles3D:
    var particles = GPUParticles3D.new()
    particles.emitting = true
    particles.amount = 12
    particles.lifetime = 0.3
    particles.explosiveness = 0.0

    var mat = ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0, 0)
    mat.spread = 10.0
    mat.initial_velocity_min = 0.0
    mat.initial_velocity_max = 0.5
    mat.gravity = Vector3.ZERO
    mat.scale_min = 0.05
    mat.scale_max = 0.05
    mat.damping_min = 5.0
    mat.damping_max = 5.0
    particles.process_material = mat

    var color = NeonPalette.element_color(element)
    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = color
    draw_mat.emission_enabled = true
    draw_mat.emission = color
    draw_mat.emission_energy_multiplier = 3.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    draw_mat.albedo_color.a = 0.8

    var mesh = SphereMesh.new()
    mesh.radius = 0.02
    mesh.height = 0.04
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    return particles

static func create_impact(pos: Vector3, direction: Vector3, element: String) -> GPUParticles3D:
    var particles = GPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 10
    particles.lifetime = 0.2
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)

    var mat = ParticleProcessMaterial.new()
    # Spray opposite to projectile travel direction
    mat.direction = -direction.normalized()
    mat.spread = 60.0
    mat.initial_velocity_min = 3.0
    mat.initial_velocity_max = 5.0
    mat.gravity = Vector3(0, -5, 0)
    mat.scale_min = 0.03
    mat.scale_max = 0.06
    particles.process_material = mat

    var color = NeonPalette.element_color(element)
    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = color
    draw_mat.emission_enabled = true
    draw_mat.emission = color
    draw_mat.emission_energy_multiplier = 4.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    var mesh = SphereMesh.new()
    mesh.radius = 0.02
    mesh.height = 0.04
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    return particles
```

- [ ] **Step 2: Verify file loads without errors**

Run: Open Godot. Check Output for parse errors.

- [ ] **Step 3: Commit**

```bash
git add src/effects/vfx_factory.gd
git commit -m "feat: add VfxFactory for muzzle flash, trail, and impact particles"
```

---

### Task 5: Combat VFX Integration

**Files:**
- Modify: `src/entities/projectile.gd`
- Modify: `src/levels/generated_level.gd`

- [ ] **Step 1: Add trail particles to projectile and impact on collision**

Replace `src/entities/projectile.gd` with:

```gdscript
class_name ProjectileEntity
extends Area3D

var ecs_entity: Entity

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    ecs_entity.add_component(C_Projectile.new())
    ecs_entity.add_component(C_DamageDealer.new())
    ecs_entity.add_component(C_Lifetime.new())

    body_entered.connect(_on_body_entered)

func setup(dir: Vector3, spd: float, dmg: int, elem: String, owner_id: int) -> void:
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    proj.direction = dir
    proj.speed = spd
    proj.element = elem
    proj.damage = dmg
    proj.owner_id = owner_id

    var dd := ecs_entity.get_component(C_DamageDealer) as C_DamageDealer
    dd.damage = dmg
    dd.element = elem
    dd.owner_entity_id = owner_id

    # Attach trail particles
    var trail = VfxFactory.create_trail(elem)
    add_child(trail)

func _physics_process(delta: float) -> void:
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    position += proj.direction * proj.speed * delta

func _on_body_entered(body: Node) -> void:
    var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
    # Spawn impact particles at collision point
    var impact = VfxFactory.create_impact(global_position, proj.direction, proj.element)
    get_tree().current_scene.add_child(impact)

    if body is CharacterBody3D and body.has_method("get_component"):
        if body.get_instance_id() != proj.owner_id:
            S_Damage.apply_damage(body.ecs_entity, proj.damage, proj.element)
    queue_free()
```

- [ ] **Step 2: Add muzzle flash to projectile spawn in generated_level.gd**

In `src/levels/generated_level.gd`, in `_on_projectile_requested()`, add muzzle flash after `add_child(projectile)`:

```gdscript
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

    # Muzzle flash
    var flash = VfxFactory.create_muzzle_flash(spawn_pos)
    add_child(flash)
```

- [ ] **Step 3: Visual test**

Run: `Play Solo`. Fire weapons. Verify:
- Muzzle flash appears briefly at gun position
- Projectiles have colored particle trails (white for pistol, orange for flamethrower, cyan for ice rifle, blue for water gun)
- Impact sparks appear where projectiles hit walls or monsters

- [ ] **Step 4: Commit**

```bash
git add src/entities/projectile.gd src/levels/generated_level.gd
git commit -m "feat: combat VFX — muzzle flash, projectile trails, impact sparks"
```

---

### Task 6: Monster Visual Overhaul

**Files:**
- Modify: `src/entities/monster.gd`

- [ ] **Step 1: Replace monster.gd with dark emissive body, glowing eyes, size variation, and hit flash**

Replace `src/entities/monster.gd` with:

```gdscript
class_name MonsterEntity
extends CharacterBody3D

var ecs_entity: Entity
var _body_material: StandardMaterial3D
var _base_emission_energy: float = 1.0

func _ready():
    ecs_entity = Entity.new()
    ecs_entity.name = "ECSEntity"
    add_child(ecs_entity)

    if ECS.world:
        ECS.world.add_entity(ecs_entity)

    ecs_entity.add_component(C_Health.new())
    ecs_entity.add_component(C_Velocity.new())
    ecs_entity.add_component(C_Conditions.new())
    ecs_entity.add_component(C_MonsterAI.new())
    ecs_entity.add_component(C_ActorTag.new())

    var tag := ecs_entity.get_component(C_ActorTag) as C_ActorTag
    tag.actor_type = C_ActorTag.ActorType.MONSTER
    tag.team = 1

    _setup_visuals()

func _setup_visuals() -> void:
    var accent = NeonPalette.random_color()

    # Find existing MeshInstance3D child (from the .tscn scene)
    var mesh_node: MeshInstance3D = null
    for child in get_children():
        if child is MeshInstance3D:
            mesh_node = child
            break

    # Apply dark emissive material to body
    if mesh_node:
        _body_material = StandardMaterial3D.new()
        _body_material.albedo_color = Color(0.08, 0.08, 0.1)
        _body_material.emission_enabled = true
        _body_material.emission = accent
        _body_material.emission_energy_multiplier = _base_emission_energy
        mesh_node.material_override = _body_material

    # Add glowing eyes
    _add_eye(Vector3(-0.12, 1.3, -0.41), accent)
    _add_eye(Vector3(0.12, 1.3, -0.41), accent)

    # Random size variation (visual only)
    var scale_factor = randf_range(0.8, 1.2)
    scale = Vector3(scale_factor, scale_factor, scale_factor)

func _add_eye(offset: Vector3, _accent: Color) -> void:
    var eye = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.08, 0.08, 0.02)
    eye.mesh = mesh
    eye.position = offset

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color.BLACK
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.1, 0.1)
    mat.emission_energy_multiplier = 3.0
    eye.material_override = mat

    add_child(eye)

func flash_hit() -> void:
    if _body_material:
        _body_material.emission_energy_multiplier = 5.0
        var tween = create_tween()
        tween.tween_property(_body_material, "emission_energy_multiplier", _base_emission_energy, 0.1)

func get_component(component_class) -> Component:
    return ecs_entity.get_component(component_class)

func _physics_process(delta: float) -> void:
    var vel_comp := ecs_entity.get_component(C_Velocity) as C_Velocity

    if not is_on_floor():
        velocity.y -= Config.gravity * delta

    velocity.x = vel_comp.direction.x * vel_comp.speed
    velocity.z = vel_comp.direction.z * vel_comp.speed

    move_and_slide()
```

- [ ] **Step 2: Call flash_hit() from S_Damage when a monster takes damage**

In `src/systems/s_damage.gd`, add a flash call after applying damage. In `apply_damage()`, after `health.current_health = maxi(health.current_health, 0)` add:

```gdscript
    # Visual hit flash on monsters
    var parent = target_entity.get_parent()
    if parent is MonsterEntity:
        parent.flash_hit()
```

- [ ] **Step 3: Visual test**

Run: `Play Solo`. Verify:
- Monsters are dark with neon-colored glow
- Two red glowing eyes visible on each monster
- Monsters have slightly different sizes
- Shooting a monster causes a brief bright flash on its body

- [ ] **Step 4: Commit**

```bash
git add src/entities/monster.gd src/systems/s_damage.gd
git commit -m "feat: neon monster appearance — emissive body, eyes, size variation, hit flash"
```

---

### Task 7: Monster Health Bars

**Files:**
- Modify: `src/entities/monster.gd`

- [ ] **Step 1: Add health bar setup and update to MonsterEntity**

In `src/entities/monster.gd`, add these three member variables at the top of the class (after the existing `var _base_emission_energy` line):

```gdscript
var _health_bar_node: Node3D
var _health_bar_fg: MeshInstance3D
var _health_bar_visible := false
```

Then add these two methods at the end of the file (after the `_physics_process` method):

```gdscript

func _setup_health_bar() -> void:
    _health_bar_node = Node3D.new()
    _health_bar_node.position = Vector3(0, 1.2, 0)
    _health_bar_node.visible = false
    add_child(_health_bar_node)

    # Background bar (dark gray)
    var bg = MeshInstance3D.new()
    var bg_mesh = BoxMesh.new()
    bg_mesh.size = Vector3(1.0, 0.05, 0.02)
    bg.mesh = bg_mesh
    var bg_mat = StandardMaterial3D.new()
    bg_mat.albedo_color = Color(0.15, 0.15, 0.15)
    bg.material_override = bg_mat
    _health_bar_node.add_child(bg)

    # Foreground bar (green, scales with HP)
    _health_bar_fg = MeshInstance3D.new()
    var fg_mesh = BoxMesh.new()
    fg_mesh.size = Vector3(1.0, 0.05, 0.02)
    _health_bar_fg.mesh = fg_mesh
    _health_bar_fg.position = Vector3(0, 0, 0.01)
    var fg_mat = StandardMaterial3D.new()
    fg_mat.albedo_color = Color(0.0, 1.0, 0.3)
    fg_mat.emission_enabled = true
    fg_mat.emission = Color(0.0, 1.0, 0.3)
    fg_mat.emission_energy_multiplier = 1.5
    _health_bar_fg.material_override = fg_mat
    _health_bar_node.add_child(_health_bar_fg)

func _process(_delta: float) -> void:
    if not _health_bar_node:
        return
    var health := ecs_entity.get_component(C_Health) as C_Health
    if not health:
        return

    # Show only when damaged
    var should_show = health.current_health < health.max_health and health.current_health > 0
    if should_show != _health_bar_visible:
        _health_bar_visible = should_show
        _health_bar_node.visible = should_show

    if not _health_bar_visible:
        return

    # Update bar width and color based on HP ratio
    var ratio = float(health.current_health) / float(health.max_health)
    _health_bar_fg.scale.x = ratio
    _health_bar_fg.position.x = -(1.0 - ratio) * 0.5

    # Color: green at full → red at low
    var bar_color = Color(1.0 - ratio, ratio, 0.1)
    var fg_mat = _health_bar_fg.material_override as StandardMaterial3D
    fg_mat.albedo_color = bar_color
    fg_mat.emission = bar_color

    # Billboard: face camera
    var camera = get_viewport().get_camera_3d()
    if camera:
        _health_bar_node.look_at(camera.global_position)
```

- [ ] **Step 2: Call _setup_health_bar() from _ready()**

In `src/entities/monster.gd`, at the end of `_ready()`, add:

```gdscript
    _setup_health_bar()
```

- [ ] **Step 3: Visual test**

Run: `Play Solo`. Shoot a monster. Verify:
- Health bar appears above the monster only after taking damage
- Bar shrinks from left as HP decreases
- Bar color transitions from green to red
- Bar always faces the camera

- [ ] **Step 4: Commit**

```bash
git add src/entities/monster.gd
git commit -m "feat: add billboard health bars above monsters"
```

---

### Task 8: HUD Damage Flash

**Files:**
- Modify: `src/ui/hud.tscn`
- Modify: `src/ui/hud.gd`

- [ ] **Step 1: Add DamageFlash ColorRect to hud.tscn**

Append to the end of `src/ui/hud.tscn`:

```
[node name="DamageFlash" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
color = Color(1, 0, 0, 0)
```

- [ ] **Step 2: Update hud.gd to track health and trigger flash**

Replace `src/ui/hud.gd` with:

```gdscript
extends Control

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var peers_label: Label = $MarginContainer/VBoxContainer/PeersLabel
@onready var weapon_label: Label = $MarginContainer/VBoxContainer/WeaponLabel
@onready var god_mode_check: CheckBox = $MarginContainer/VBoxContainer/GodModeCheck
@onready var damage_flash: ColorRect = $DamageFlash

var _prev_health: int = -1

func _ready() -> void:
	god_mode_check.button_pressed = Config.god_mode
	god_mode_check.toggled.connect(func(on: bool): Config.god_mode = on)

func _process(_delta: float) -> void:
	var peer_count = Net.peers.size() + 1
	peers_label.text = "Players: %d" % peer_count

	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player is PlayerEntity:
			var health = player.get_component(C_Health)
			if health:
				health_label.text = "HP: %d/%d" % [health.current_health, health.max_health]
				# Damage flash detection
				if _prev_health >= 0 and health.current_health < _prev_health:
					_trigger_damage_flash()
				_prev_health = health.current_health
			var weapon = player.get_component(C_Weapon)
			if weapon:
				var elem_text = weapon.element if weapon.element != "" else "none"
				weapon_label.text = "Weapon: %s [%s]" % [_get_weapon_name(weapon), elem_text]
				break

func _trigger_damage_flash() -> void:
	damage_flash.color = Color(1.0, 0.0, 0.0, 0.3)
	var tween = create_tween()
	tween.tween_property(damage_flash, "color:a", 0.0, 0.15)

func _get_weapon_name(weapon: C_Weapon) -> String:
	for preset in Config.weapon_presets:
		if preset.damage == weapon.damage and preset.element == weapon.element:
			return preset.name
	return "Custom"
```

- [ ] **Step 3: Visual test**

Run: `Play Solo`. Uncheck God Mode. Let a monster hit you. Verify:
- Brief red flash overlays the screen when taking damage
- Flash fades out quickly (0.15s)
- Flash does not interfere with clicking UI elements

- [ ] **Step 4: Commit**

```bash
git add src/ui/hud.gd src/ui/hud.tscn
git commit -m "feat: add HUD damage flash overlay"
```

---

### Task 9: Floating Kill Text

**Files:**
- Create: `src/effects/floating_text.gd`
- Modify: `src/systems/s_death.gd`

- [ ] **Step 1: Create FloatingText class**

```gdscript
class_name FloatingText
extends Label3D

func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	modulate = Color(0.2, 1.0, 0.4, 1.0)
	outline_modulate = Color.BLACK
	outline_size = 8
	font_size = 32
	pixel_size = 0.01

func show_text(pos: Vector3, value: String) -> void:
	global_position = pos + Vector3(0, 1.5, 0)
	text = value
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + 1.0, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(queue_free)
```

- [ ] **Step 2: Spawn floating text on monster death in S_Death**

Replace `src/systems/s_death.gd` with:

```gdscript
class_name S_Death
extends System

signal actor_died(entity: Entity)

func query() -> QueryBuilder:
    return q.with_all([C_Health])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var health := entity.get_component(C_Health) as C_Health
        if health.current_health <= 0:
            var parent = entity.get_parent()
            print("[S_Death] Entity died: %s (parent: %s)" % [entity.name, parent.name if parent else "none"])

            # Floating kill text for monsters
            if parent is MonsterEntity and is_instance_valid(parent):
                var ft = FloatingText.new()
                parent.get_tree().current_scene.add_child(ft)
                ft.show_text(parent.global_position, "+10")

            actor_died.emit(entity)
            if ECS.world:
                ECS.world.remove_entity(entity)
            if is_instance_valid(parent):
                parent.queue_free()
```

- [ ] **Step 3: Visual test**

Run: `Play Solo`. Uncheck God Mode on the monster side (monsters can still die). Shoot a monster until it dies. Verify:
- Green "+10" text appears at death location
- Text floats upward and fades over 0.8s
- Text always faces camera (billboard)

- [ ] **Step 4: Commit**

```bash
git add src/effects/floating_text.gd src/systems/s_death.gd
git commit -m "feat: floating kill text on monster death"
```

---

### Task 10: Final Visual Test & Push

- [ ] **Step 1: Full playtest**

Run: `Play Solo`. Walk around the entire level. Verify all visual elements work together:
- Dark neon dungeon atmosphere with colored fog
- Glowing edge strips and room floor glow
- Colored pool lighting
- Monster glow, eyes, size variation
- Shooting: muzzle flash, trails, impact sparks
- Monster hit flash, health bars appearing when damaged
- Damage flash on HUD when hit (disable God Mode)
- Kill text floating up on monster death

- [ ] **Step 2: Push all changes**

```bash
git push
```

This triggers the GitHub Pages deployment. Verify the web build at https://zholobov.github.io/rogue1-prototype/ once the action completes.
