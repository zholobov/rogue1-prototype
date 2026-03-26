# Russian Folk Tales Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a three-biome "Russian Folk Tales" theme with distinctive wall geometry, 3 monster types per biome, open sky support, and full visual identity for Dark Forest, Golden Palace, and Winter Realm.

**Architecture:** ThemeData gains `has_ceiling`, `sky_config`, `wall_style` properties. LevelBuilder gets 3 new wall geometry builders dispatched by wall_style. GeneratedLevel sets up ProceduralSkyMaterial for open-sky biomes and supports monster variant spawning. Folk theme factory creates 3 ThemeData biomes wrapped in a ThemeGroup. 13 monster .tscn scenes built from geometric primitives.

**Tech Stack:** Godot 4.6, GDScript, GECS ECS framework, GUT for tests

**Spec:** `docs/superpowers/specs/2026-03-26-russian-folk-tales-theme-design.md`

**Indentation rules:**
- TABS: `level_builder.gd`
- 4-SPACES: all new files, `theme_data.gd`, `theme_manager.gd`, `generated_level.gd`

---

## File Structure

### New Files (14)

| File | Responsibility |
|------|---------------|
| `themes/folk/folk_theme.gd` | Factory: creates 3 biomes, returns ThemeGroup |
| `themes/folk/leshy_basic.tscn` | Dark Forest — Leshy (tree spirit) |
| `themes/folk/kikimora_basic.tscn` | Dark Forest — Kikimora (swamp hag) |
| `themes/folk/vodyanoy_basic.tscn` | Dark Forest — Vodyanoy (water toad) |
| `themes/folk/leshy_boss.tscn` | Dark Forest boss |
| `themes/folk/zmey_basic.tscn` | Golden Palace — Zmey (dragon) |
| `themes/folk/koschei_basic.tscn` | Golden Palace — Koschei (deathless) |
| `themes/folk/strazh_basic.tscn` | Golden Palace — Strazh (guard) |
| `themes/folk/zmey_boss.tscn` | Golden Palace boss |
| `themes/folk/morozko_basic.tscn` | Winter Realm — Morozko (frost spirit) |
| `themes/folk/snegurochka_basic.tscn` | Winter Realm — Snegurochka (ice maiden) |
| `themes/folk/medved_basic.tscn` | Winter Realm — Medved (ice bear) |
| `themes/folk/morozko_boss.tscn` | Winter Realm boss |
| `test/unit/test_folk_theme.gd` | GUT tests |

### Modified Files (4)

| File | Changes |
|------|---------|
| `src/themes/theme_data.gd` | Add `has_ceiling`, `sky_config`, `wall_style` |
| `src/themes/theme_manager.gd` | Register folk theme group |
| `src/generation/level_builder.gd` | Ceiling gate + 3 wall style builders |
| `src/levels/generated_level.gd` | Sky setup + monster variant spawning |

---

## Task 1: ThemeData New Properties

**Files:**
- Modify: `src/themes/theme_data.gd`
- Create: `test/unit/test_folk_theme.gd`

- [ ] **Step 1: Add properties to ThemeData**

In `src/themes/theme_data.gd` (4-spaces), add in the Props section (after `room_prop_max`):

```gdscript
@export var has_ceiling: bool = true
@export var wall_style: String = "default"
@export var sky_config: Dictionary = {}
```

- [ ] **Step 2: Create test file**

Create `test/unit/test_folk_theme.gd`:

```gdscript
extends GutTest

func test_theme_data_has_ceiling_default():
    var t = ThemeData.new()
    assert_true(t.has_ceiling)
    assert_eq(t.wall_style, "default")
    assert_eq(t.sky_config.size(), 0)
```

- [ ] **Step 3: Commit**

```bash
git add src/themes/theme_data.gd test/unit/test_folk_theme.gd
git commit -m "feat: add has_ceiling, wall_style, sky_config to ThemeData"
```

---

## Task 2: LevelBuilder — Ceiling Gate + Wall Style Dispatch

**Files:**
- Modify: `src/generation/level_builder.gd`

- [ ] **Step 1: Gate ceiling creation**

In `level_builder.gd` (TABS), find `_add_ceiling(root, world_pos, tile_size, is_room)` call (line 75) and wrap:

```gdscript
			if ThemeManager.active_theme.has_ceiling:
				_add_ceiling(root, world_pos, tile_size, is_room)
```

Also gate ceiling beams (line ~101):

```gdscript
	if ThemeManager.active_theme.has_ceiling and ThemeManager.active_theme.prop_density > 0.0 and beam_spacing > 0:
```

- [ ] **Step 2: Add wall style dispatch**

In `_add_wall_block()`, before the existing mesh creation, add a style check. Replace the wall block function to dispatch:

At the start of `_add_wall_block()`, add:

```gdscript
	var style = ThemeManager.active_theme.wall_style
	if style != "default":
		_add_styled_wall(parent, pos, tile_size, grid, x, y, width, height, style)
		return
```

- [ ] **Step 3: Add `_add_styled_wall` and three wall builders**

Add after `_add_wall_detail`:

```gdscript
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
	var theme = ThemeManager.active_theme
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
	var ice_mat = StandardMaterial3D.new()
	ice_mat.albedo_color = theme.wall_albedo
	ice_mat.roughness = 0.2
	var snow_mat = StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.85, 0.88, 0.92)
	snow_mat.roughness = 0.8
	# Snow mounds (2-3 at base)
	for i in range(rng.randi_range(2, 3)):
		var mound = MeshInstance3D.new()
		var mound_mesh = BoxMesh.new()
		var mound_h = rng.randf_range(0.3, 0.8)
		mound_mesh.size = Vector3(tile_size * rng.randf_range(0.3, 0.5), mound_h, tile_size * rng.randf_range(0.3, 0.5))
		mound.mesh = mound_mesh
		mound.material_override = snow_mat
		mound.position = Vector3(cx + rng.randf_range(-0.5, 0.5), mound_h / 2.0, cz + rng.randf_range(-0.5, 0.5))
		parent.add_child(mound)
	# Ice crystals (2-3 tall angular shapes)
	for i in range(rng.randi_range(2, 3)):
		var crystal = MeshInstance3D.new()
		var crystal_mesh = BoxMesh.new()
		var crystal_h = rng.randf_range(1.5, WALL_HEIGHT)
		crystal_mesh.size = Vector3(rng.randf_range(0.15, 0.35), crystal_h, rng.randf_range(0.15, 0.35))
		crystal.mesh = crystal_mesh
		crystal.material_override = ice_mat
		crystal.position = Vector3(cx + rng.randf_range(-0.6, 0.6), crystal_h / 2.0, cz + rng.randf_range(-0.6, 0.6))
		crystal.rotation_degrees.y = rng.randf_range(-20, 20)
		crystal.rotation_degrees.z = rng.randf_range(-8, 8)
		parent.add_child(crystal)
	# Frost sparkle
	if rng.randf() < 0.6:
		var sparkle = MeshInstance3D.new()
		var spark_mesh = SphereMesh.new()
		spark_mesh.radius = 0.04
		spark_mesh.height = 0.08
		sparkle.mesh = spark_mesh
		var frost_mat = StandardMaterial3D.new()
		frost_mat.albedo_color = Color(0.7, 0.85, 1.0)
		frost_mat.emission_enabled = true
		frost_mat.emission = Color(0.7, 0.88, 1.0)
		frost_mat.emission_energy_multiplier = 2.0
		sparkle.material_override = frost_mat
		sparkle.position = Vector3(cx + rng.randf_range(-0.5, 0.5), rng.randf_range(1.0, 2.5), cz + rng.randf_range(-0.3, 0.3))
		parent.add_child(sparkle)
	# Icicles from top (2)
	for i in range(2):
		var icicle = MeshInstance3D.new()
		var icicle_mesh = CylinderMesh.new()
		icicle_mesh.top_radius = 0.02
		icicle_mesh.bottom_radius = 0.06
		icicle_mesh.height = rng.randf_range(0.3, 0.6)
		icicle.mesh = icicle_mesh
		icicle.material_override = ice_mat
		icicle.position = Vector3(cx + rng.randf_range(-0.5, 0.5), WALL_HEIGHT - icicle_mesh.height / 2.0, cz + rng.randf_range(-0.5, 0.5))
		parent.add_child(icicle)
```

- [ ] **Step 4: Commit**

```bash
git add src/generation/level_builder.gd
git commit -m "feat: add ceiling gate + forest/palace/ice wall geometry builders"
```

---

## Task 3: GeneratedLevel — Sky Setup + Monster Variant Spawning

**Files:**
- Modify: `src/levels/generated_level.gd`

- [ ] **Step 1: Add ProceduralSkyMaterial setup**

In `generated_level.gd` (4-spaces), after the WorldEnvironment is added to the scene (after `add_child(world_env)`, around line 34), add:

```gdscript
    # Open sky for biomes without ceiling
    if not theme.has_ceiling and theme.sky_config.size() > 0:
        var sky_cfg = theme.sky_config
        var sky_mat = ProceduralSkyMaterial.new()
        sky_mat.sky_top_color = sky_cfg.get("sky_top_color", Color(0.05, 0.05, 0.1))
        sky_mat.sky_horizon_color = sky_cfg.get("sky_horizon_color", Color(0.1, 0.15, 0.2))
        sky_mat.ground_bottom_color = sky_cfg.get("ground_bottom_color", Color(0.02, 0.02, 0.02))
        sky_mat.ground_horizon_color = sky_cfg.get("ground_horizon_color", Color(0.1, 0.1, 0.1))
        sky_mat.sun_angle_max = sky_cfg.get("sun_angle_max", 30.0)
        sky_mat.sun_curve = 0.1
        var sky = Sky.new()
        sky.sky_material = sky_mat
        env.sky = sky
        env.background_mode = Environment.BG_SKY

- [ ] **Step 2: Add monster variant spawning**

In `_spawn_monsters()`, replace the line that instantiates `MonsterScene` with variant selection:

Find `var monster = MonsterScene.instantiate()` and replace with:

```gdscript
            var monster_scene_to_use = MonsterScene
            if theme.monster_scenes.size() > 2:
                var roll = randf()
                if roll < 0.5 and theme.monster_scenes.has("basic"):
                    monster_scene_to_use = theme.monster_scenes["basic"].instantiate().get_script()
                    # Actually use scene directly:
                    pass
                # Simpler approach: pick scene, instantiate
                var variant_roll = randf()
                var scene_key = "basic"
                if variant_roll < 0.25 and theme.monster_scenes.has("variant2"):
                    scene_key = "variant2"
                elif variant_roll < 0.5 and theme.monster_scenes.has("variant1"):
                    scene_key = "variant1"
                elif theme.monster_scenes.has("basic"):
                    scene_key = "basic"
                # Override monster visual — the MonsterEntity handles scene override via ThemeManager
                # We need to tell the monster which variant to use
```

Actually, the existing system already uses `ThemeManager.get_monster_scene("basic")` inside `monster.gd:_setup_visuals()`. For variant monsters, we need a different approach. The simplest: set a property on the monster entity telling it which scene key to use.

Simpler approach: override at the `_setup_visuals` level. In `monster.gd`, `_setup_visuals()` calls `ThemeManager.get_monster_scene("basic")`. Add a `visual_variant: String` property to MonsterEntity and use it in `_setup_visuals()`.

In `src/entities/monster.gd`, add at the top:

```gdscript
var visual_variant: String = "basic"
```

In `_setup_visuals()`, change:
```gdscript
var scene_override := ThemeManager.get_monster_scene("basic")
```
to:
```gdscript
var scene_override := ThemeManager.get_monster_scene(visual_variant)
```

In `generated_level.gd:_spawn_monsters()`, after `var monster = MonsterScene.instantiate()`, add before `add_child(monster)`:

```gdscript
            # Pick monster variant
            var variant_roll = randf()
            if variant_roll < 0.25 and theme.monster_scenes.has("variant2"):
                monster.visual_variant = "variant2"
            elif variant_roll < 0.5 and theme.monster_scenes.has("variant1"):
                monster.visual_variant = "variant1"
```

- [ ] **Step 3: Commit**

```bash
git add src/levels/generated_level.gd src/entities/monster.gd
git commit -m "feat: add open sky support and monster variant spawning"
```

---

## Task 4: Dark Forest Biome — Monster Scenes

**Files:**
- Create: `themes/folk/leshy_basic.tscn`
- Create: `themes/folk/kikimora_basic.tscn`
- Create: `themes/folk/vodyanoy_basic.tscn`
- Create: `themes/folk/leshy_boss.tscn`

Create all 4 Dark Forest monster scenes. Each is a `.tscn` file following the same structure as existing monster scenes (BodyMesh, EyeMesh, HealthBarAnchor, WeaponMount).

Read the spec section 8a-8d for exact primitive counts and descriptions. Read existing `themes/neon/monster_basic.tscn` for the `.tscn` format reference.

Each scene must have:
- Root `Node3D` with descriptive name
- `BodyMesh` MeshInstance3D (main body — materials set at runtime by monster.gd)
- `EyeMesh` MeshInstance3D (eyes — materials set at runtime)
- Additional detail meshes (arms, legs, patches, etc.)
- `HealthBarAnchor` Marker3D at appropriate height
- `WeaponMount` Marker3D at hand/arm position

Material colors in .tscn files are defaults — `monster.gd:_setup_visuals()` overrides BodyMesh and EyeMesh materials at runtime from ThemeData.

- [ ] **Step 1: Create all 4 Dark Forest scenes**

Build each scene programmatically or as .tscn text. Use the spec dimensions and primitive descriptions.

- [ ] **Step 2: Commit**

```bash
git add themes/folk/leshy_basic.tscn themes/folk/kikimora_basic.tscn themes/folk/vodyanoy_basic.tscn themes/folk/leshy_boss.tscn
git commit -m "feat: add Dark Forest monster scenes — Leshy, Kikimora, Vodyanoy, boss"
```

---

## Task 5: Golden Palace Biome — Monster Scenes

**Files:**
- Create: `themes/folk/zmey_basic.tscn`
- Create: `themes/folk/koschei_basic.tscn`
- Create: `themes/folk/strazh_basic.tscn`
- Create: `themes/folk/zmey_boss.tscn`

Same pattern as Task 4. Read spec sections 8e-8h.

- [ ] **Step 1: Create all 4 Golden Palace scenes**

- [ ] **Step 2: Commit**

```bash
git add themes/folk/zmey_basic.tscn themes/folk/koschei_basic.tscn themes/folk/strazh_basic.tscn themes/folk/zmey_boss.tscn
git commit -m "feat: add Golden Palace monster scenes — Zmey, Koschei, Strazh, boss"
```

---

## Task 6: Winter Realm Biome — Monster Scenes

**Files:**
- Create: `themes/folk/morozko_basic.tscn`
- Create: `themes/folk/snegurochka_basic.tscn`
- Create: `themes/folk/medved_basic.tscn`
- Create: `themes/folk/morozko_boss.tscn`

Same pattern as Task 4. Read spec sections 8i-8l.

- [ ] **Step 1: Create all 4 Winter Realm scenes**

- [ ] **Step 2: Commit**

```bash
git add themes/folk/morozko_basic.tscn themes/folk/snegurochka_basic.tscn themes/folk/medved_basic.tscn themes/folk/morozko_boss.tscn
git commit -m "feat: add Winter Realm monster scenes — Morozko, Snegurochka, Medved, boss"
```

---

## Task 7: Folk Theme Factory + Registration

**Files:**
- Create: `themes/folk/folk_theme.gd`
- Modify: `src/themes/theme_manager.gd`

- [ ] **Step 1: Create folk_theme.gd**

Create `themes/folk/folk_theme.gd` with a factory class that creates all 3 biomes. Read the spec sections 5, 6, 7 for exact color values. The factory returns a ThemeGroup (not a single ThemeData).

```gdscript
class_name FolkTheme

static func create_group() -> ThemeGroup:
    var group = ThemeGroup.new()
    group.group_name = "Russian Folk Tales"
    group.description = "Three biomes from Russian mythology"
    group.biomes = [_create_dark_forest(), _create_golden_palace(), _create_winter_realm()]
    return group

static func _create_dark_forest() -> ThemeData:
    var t = ThemeData.new()
    t.theme_name = "Russian Folk Tales"
    t.biome_name = "Dark Forest"
    t.description = "Baba Yaga's enchanted forest"
    t.has_ceiling = false
    t.wall_style = "forest_thicket"
    t.sky_config = {
        "sky_top_color": Color(0.02, 0.05, 0.02),
        "sky_horizon_color": Color(0.05, 0.1, 0.05),
        "ground_bottom_color": Color(0.02, 0.03, 0.01),
        "ground_horizon_color": Color(0.04, 0.06, 0.03),
        "sun_angle_max": 15.0,
        "sun_energy": 0.1,
    }
    # ... set all 71 ThemeData properties from spec section 5 ...
    # Load monster scenes
    t.monster_scenes = {
        "basic": load("res://themes/folk/leshy_basic.tscn"),
        "variant1": load("res://themes/folk/kikimora_basic.tscn"),
        "variant2": load("res://themes/folk/vodyanoy_basic.tscn"),
        "boss": load("res://themes/folk/leshy_boss.tscn"),
    }
    return t

static func _create_golden_palace() -> ThemeData:
    # ... set all properties from spec section 6 ...
    # t.has_ceiling = true, t.wall_style = "palace_ornate"

static func _create_winter_realm() -> ThemeData:
    # ... set all properties from spec section 7 ...
    # t.has_ceiling = false, t.wall_style = "ice_crystal"
```

The implementer must read spec sections 5, 6, 7 and set EVERY property. Use `NeonTheme.create()` and `StoneTheme.create()` as reference for the pattern.

- [ ] **Step 2: Register in ThemeManager**

In `src/themes/theme_manager.gd` (4-spaces), in `_load_themes()`, add after the stone group:

```gdscript
    var folk_group = FolkTheme.create_group()
    available_groups.append(folk_group)
```

- [ ] **Step 3: Commit**

```bash
git add themes/folk/folk_theme.gd src/themes/theme_manager.gd
git commit -m "feat: add Russian Folk Tales theme — 3 biomes registered in ThemeManager"
```

---

## Task 8: Tests + Smoke Verification

**Files:**
- Modify: `test/unit/test_folk_theme.gd`

- [ ] **Step 1: Add tests**

Append to `test/unit/test_folk_theme.gd`:

```gdscript
func test_folk_theme_group_exists():
    var found = false
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            found = true
            assert_eq(group.biomes.size(), 3)
    assert_true(found, "Folk Tales group should be registered")

func test_folk_biomes_have_names():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_eq(group.biomes[0].biome_name, "Dark Forest")
            assert_eq(group.biomes[1].biome_name, "Golden Palace")
            assert_eq(group.biomes[2].biome_name, "Winter Realm")

func test_dark_forest_has_no_ceiling():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_false(group.biomes[0].has_ceiling)
            assert_eq(group.biomes[0].wall_style, "forest_thicket")

func test_golden_palace_has_ceiling():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_true(group.biomes[1].has_ceiling)
            assert_eq(group.biomes[1].wall_style, "palace_ornate")

func test_winter_realm_has_no_ceiling():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_false(group.biomes[2].has_ceiling)
            assert_eq(group.biomes[2].wall_style, "ice_crystal")

func test_folk_biomes_have_monster_scenes():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            for biome in group.biomes:
                assert_true(biome.monster_scenes.has("basic"), "%s needs basic" % biome.biome_name)
                assert_true(biome.monster_scenes.has("variant1"), "%s needs variant1" % biome.biome_name)
                assert_true(biome.monster_scenes.has("variant2"), "%s needs variant2" % biome.biome_name)
                assert_true(biome.monster_scenes.has("boss"), "%s needs boss" % biome.biome_name)

func test_folk_biomes_have_sky_config():
    for group in ThemeManager.available_groups:
        if group.group_name == "Russian Folk Tales":
            assert_true(group.biomes[0].sky_config.size() > 0, "Dark Forest needs sky_config")
            assert_eq(group.biomes[1].sky_config.size(), 0, "Golden Palace has ceiling, no sky")
            assert_true(group.biomes[2].sky_config.size() > 0, "Winter Realm needs sky_config")
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/zholobov/src/gd-rogue1-prototype && /Applications/Godot.app/Contents/MacOS/Godot --headless --script addons/gut/gut_cmdln.gd -gdir=test/unit -gtest=test_folk_theme.gd
```

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_folk_theme.gd
git commit -m "test: add Russian Folk Tales theme integration tests"
```
