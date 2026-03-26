# Russian Folk Tales Theme — Design Spec

## Goal

Create a three-biome theme inspired by Russian folk tales: Dark Forest (Baba Yaga), Golden Palace (Bylina), and Winter Realm (Skazka). Each biome has distinct colors, materials, monsters, atmosphere, and **distinctive wall geometry built from primitives**. Forest and Winter have open sky (ProceduralSkyMaterial, no ceiling). Golden Palace has ceiling. Monsters are triple-detail (~25-40 primitives). Each biome has **3 monster types** (basic + 2 variants) plus a boss.

## Scope

- 3 biome ThemeData definitions with full property configurations
- 18 monster scenes (3 basic types + boss per biome = 4 per biome × 3 biomes)
- ThemeData gains `has_ceiling: bool`, `sky_config: Dictionary`, `wall_style: String`
- LevelBuilder modified to skip ceiling and use biome-specific wall geometry
- GeneratedLevel modified to set up ProceduralSkyMaterial for open-sky biomes
- Theme factory file + registration in ThemeManager

Not covered: new texture patterns (use existing flagstone/cobblestone/ashlar/slabs), new gameplay mechanics.

---

## 1. ThemeData New Properties

### `has_ceiling: bool = true`

When `false`, LevelBuilder skips `_add_ceiling()` calls. Existing themes default to `true`.

### `sky_config: Dictionary = {}`

ProceduralSkyMaterial parameters used when `has_ceiling == false`:

```gdscript
{
    "sky_top_color": Color,
    "sky_horizon_color": Color,
    "ground_bottom_color": Color,
    "ground_horizon_color": Color,
    "sun_angle_max": float,   # degrees
    "sun_energy": float,
}
```

Empty dict = no sky (use existing background_color). Only read by GeneratedLevel when `has_ceiling == false`.

### `wall_style: String = "default"`

Controls which wall geometry builder to use. Options:
- `"default"` — flat box walls (existing behavior, used by Neon/Stone)
- `"forest_thicket"` — dense tree trunk cylinders + branch crossbeams + knots + moss + root tangles
- `"palace_ornate"` — log wall base + pilaster columns with capitals + gold trim + recessed panels + ornament spheres + baseboard
- `"ice_crystal"` — snow hill base (irregular stacked boxes) + crystal ice spires (tall angular rotated boxes) + frost spheres + icicles

### `monster_scenes: Dictionary`

Expanded from 2 entries to 4:
```gdscript
{
    "basic": PackedScene,    # primary monster type (most common)
    "variant1": PackedScene, # second monster type
    "variant2": PackedScene, # third monster type
    "boss": PackedScene,
}
```

Monster spawning in `generated_level.gd` randomly picks from "basic", "variant1", "variant2" for each spawn (weighted: 50% basic, 25% variant1, 25% variant2). For themes with only "basic" and "boss" (Neon, Stone), the fallback is 100% basic.

---

## 2. LevelBuilder Changes

### Ceiling

In `build()`, wrap ceiling creation in a check:

```gdscript
if ThemeManager.active_theme.has_ceiling:
    _add_ceiling(...)
```

### Wall Geometry

Replace `_add_wall_block()` dispatch based on `wall_style`:

```gdscript
match ThemeManager.active_theme.wall_style:
    "forest_thicket": _add_forest_wall(root, x, y, tile_size)
    "palace_ornate": _add_palace_wall(root, x, y, tile_size)
    "ice_crystal": _add_ice_wall(root, x, y, tile_size)
    _: _add_wall_block(root, x, y, tile_size)  # existing default
```

**`_add_forest_wall()` (~12-16 primitives per wall tile):**
- 2-3 vertical CylinderMesh "trunks" (varying radius 0.15-0.25, full wall height), bark brown material
- 1-2 horizontal BoxMesh "branch crossbeams" between trunks, angled slightly
- 1-2 SphereMesh "knots" on trunk surfaces (r=0.06-0.1)
- 1-2 small BoxMesh "moss patches" with green emission on trunks
- 1 flat BoxMesh "root tangle" at base (wide, low, dark brown)

**`_add_palace_wall()` (~18-24 primitives per wall tile):**
- 1 base wall BoxMesh (full tile width × wall height)
- 4-5 thin BoxMesh "horizontal log lines" across wall face
- 1-2 BoxMesh "pilaster columns" (narrow, full height) at tile edges
- 1-2 BoxMesh "column capitals" (wider box at top of each pilaster)
- 1-2 BoxMesh "gold trim strips" (thin, gold emissive material) below capitals
- 1 recessed BoxMesh "ornamental panel" (slightly inset from wall face)
- 1 SphereMesh "gold ornament" (gold emissive) centered in panel
- 1 BoxMesh "baseboard" at bottom with gold accent strip

**`_add_ice_wall()` (~14-20 primitives per wall tile):**
- 2-3 BoxMesh "snow mounds" at base (varying heights 0.3-0.8, wide, white material, low roughness)
- 2-3 tall BoxMesh "ice crystals" (narrow, tall, slightly rotated, ice blue material, low roughness 0.2)
- 1-2 SphereMesh "frost sparkles" (tiny, frost-white emission) on crystal surfaces
- 2-3 CylinderMesh "icicles" hanging from top edge (thin, tapered via scale, translucent blue)

All wall builders receive the same parameters (root node, grid x/y, tile_size) and use `ThemeManager.active_theme` for material colors. Existing themes use `wall_style = "default"` and are completely unchanged.

---

## 3. GeneratedLevel Changes

In `_ready()`, after creating the WorldEnvironment, check for open sky:

```gdscript
if not ThemeManager.active_theme.has_ceiling and ThemeManager.active_theme.sky_config.size() > 0:
    var sky_cfg = ThemeManager.active_theme.sky_config
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
    var sun = DirectionalLight3D.new()
    sun.light_energy = sky_cfg.get("sun_energy", 0.2)
    sun.light_color = sky_cfg.get("sky_horizon_color", Color.WHITE)
    sun.rotation_degrees = Vector3(-30, 45, 0)
    level_root.add_child(sun)
```

---

## 4. Shared Theme Properties

All 3 biomes share these values:

**Element colors:**
```gdscript
{"": Color.WHITE, "fire": Color(1.0, 0.5, 0.1), "ice": Color(0.0, 0.8, 1.0), "water": Color(0.0, 0.5, 1.0), "oil": Color(0.2, 0.15, 0.05)}
```

**Rarity colors:**
```gdscript
{"common": Color(0.85, 0.8, 0.7), "rare": Color(0.8, 0.15, 0.1), "epic": Color(0.9, 0.75, 0.2)}
```

**UI (same for all 3 biomes):**
- `ui_background_color`: `Color(0.1, 0.07, 0.04)`
- `ui_panel_color`: `Color(0.15, 0.1, 0.06)`
- `ui_text_color`: `Color(0.9, 0.82, 0.65)`
- `ui_accent_color`: `Color(0.85, 0.65, 0.2)`
- `ui_damage_flash_color`: `Color(0.8, 0.0, 0.0, 0.3)`
- `ui_crosshair_color`: `Color(0.9, 0.8, 0.6)`
- `ui_minimap_room`: `Color(0.6, 0.55, 0.45)`
- `ui_minimap_wall`: `Color(0.2, 0.15, 0.1)`
- `ui_kill_feed_color`: `Color(0.85, 0.65, 0.2)`

---

## 5. Biome 1: Dark Forest (Baba Yaga)

### Palette
- `primary`: `Color(0.2, 0.5, 0.2)` — moss green
- `secondary`: `Color(0.4, 0.2, 0.55)` — mystic purple
- `tertiary`: `Color(0.35, 0.25, 0.15)` — bark brown
- `highlight`: `Color(1.0, 0.4, 0.2)` — firebird orange
- `danger`: `Color(0.3, 0.8, 0.1)` — poison green

### Environment
- `background_color`: `Color(0.02, 0.04, 0.02)`
- `ambient_color`: `Color(0.1, 0.15, 0.08)`
- `ambient_energy`: `0.15`
- `fog_color`: `Color(0.05, 0.08, 0.04)`
- `fog_density`: `0.03`
- `fog_depth_begin`: `2.0`
- `fog_depth_end`: `20.0`
- `directional_light_color`: `Color(0.2, 0.3, 0.15)`
- `directional_light_energy`: `0.3`
- `point_light_color`: `Color(0.3, 0.5, 0.2)`
- `point_light_energy`: `2.0`
- `point_light_range_mult`: `1.2`
- `point_light_attenuation`: `2.5`
- `point_light_spacing`: `3`

### Sky
- `has_ceiling`: `false`
- `sky_config`:
  - `sky_top_color`: `Color(0.02, 0.05, 0.02)`
  - `sky_horizon_color`: `Color(0.05, 0.1, 0.05)`
  - `ground_bottom_color`: `Color(0.02, 0.03, 0.01)`
  - `ground_horizon_color`: `Color(0.04, 0.06, 0.03)`
  - `sun_angle_max`: `15.0`
  - `sun_energy`: `0.1`

### Level Materials
- `floor_albedo`: `Color(0.15, 0.25, 0.12)` — mossy dark green
- `floor_roughness`: `0.85`
- `corridor_floor_albedo`: `Color(0.12, 0.2, 0.1)`
- `corridor_floor_roughness`: `0.9`
- `wall_albedo`: `Color(0.25, 0.18, 0.1)` — bark brown
- `wall_roughness`: `0.9`
- `ceiling_albedo`: `Color(0.1, 0.1, 0.08)` — (unused, no ceiling)
- `ceiling_roughness`: `0.9`
- `accent_emission_energy`: `1.5`
- `accent_use_palette`: `true`

### Textures
- `floor_pattern`: `{"type": "image_gen", "pattern": "cobblestone", "color1": Color(0.15, 0.25, 0.12), "color2": Color(0.08, 0.12, 0.06), "width": 256, "height": 256}`
- `corridor_floor_pattern`: `{"type": "image_gen", "pattern": "cobblestone", "color1": Color(0.12, 0.2, 0.1), "color2": Color(0.06, 0.1, 0.05), "width": 256, "height": 256}`
- `wall_pattern`: `{"type": "image_gen", "pattern": "ashlar", "color1": Color(0.25, 0.18, 0.1), "color2": Color(0.15, 0.1, 0.05), "width": 256, "height": 256}`
- `ceiling_pattern`: `{}`
- `monster_skin`: `{"type": "noise", "noise_type": "simplex", "frequency": 0.15, "octaves": 3, "width": 128, "height": 128}`

### Props
- `prop_density`: `0.5`
- `torch_flicker`: `true`
- `ceiling_beam_spacing`: `4` — (unused, no ceiling, but set for compat)
- `pillar_chance`: `0.3`
- `rubble_chance`: `0.4`
- `room_prop_min`: `1`
- `room_prop_max`: `3`

### Monsters
- `body_albedo`: `Color(0.2, 0.3, 0.15)` — bark green
- `body_emission`: `Color(0.15, 0.3, 0.1)` — subtle moss glow
- `boss_albedo`: `Color(0.15, 0.25, 0.1)`
- `boss_emission`: `Color(0.2, 0.5, 0.15)` — stronger green glow
- `eye_color`: `Color(1.0, 0.4, 0.2)` — firebird orange

### VFX
- `muzzle_flash_color`: `Color(0.3, 0.8, 0.2)`
- `impact_color`: `Color(0.2, 0.6, 0.15)`
- `death_color`: `Color(0.4, 0.2, 0.55)` — purple burst
- `aoe_blast_color`: `Color(0.3, 0.7, 0.2)`

### Projectile
- `projectile_color`: `Color(0.3, 0.6, 0.2)`
- `projectile_trail_color`: `Color(0.2, 0.5, 0.15)`

### Health Bars
- `health_bar_foreground`: `Color(0.2, 0.7, 0.15)`
- `health_bar_background`: `Color(0.1, 0.1, 0.08)`
- `health_bar_low_color`: `Color(0.8, 0.2, 0.1)`

---

## 6. Biome 2: Golden Palace (Bylina)

### Palette
- `primary`: `Color(0.85, 0.65, 0.2)` — bright gold
- `secondary`: `Color(0.3, 0.2, 0.1)` — dark wood
- `tertiary`: `Color(0.9, 0.85, 0.75)` — birch white
- `highlight`: `Color(0.8, 0.13, 0.0)` — warrior red
- `danger`: `Color(0.7, 0.1, 0.1)` — blood red

### Environment
- `background_color`: `Color(0.06, 0.04, 0.02)`
- `ambient_color`: `Color(0.2, 0.15, 0.08)`
- `ambient_energy`: `0.2`
- `fog_color`: `Color(0.1, 0.07, 0.03)`
- `fog_density`: `0.015`
- `fog_depth_begin`: `4.0`
- `fog_depth_end`: `35.0`
- `directional_light_color`: `Color(0.4, 0.3, 0.15)`
- `directional_light_energy`: `0.4`
- `point_light_color`: `Color(1.0, 0.75, 0.35)`
- `point_light_energy`: `3.0`
- `point_light_range_mult`: `1.5`
- `point_light_attenuation`: `2.0`
- `point_light_spacing`: `2`

### Sky
- `has_ceiling`: `true`
- `sky_config`: `{}`

### Level Materials
- `floor_albedo`: `Color(0.35, 0.25, 0.12)` — dark wood plank
- `floor_roughness`: `0.9`
- `corridor_floor_albedo`: `Color(0.3, 0.2, 0.1)`
- `corridor_floor_roughness`: `0.9`
- `wall_albedo`: `Color(0.22, 0.15, 0.08)` — dark log wall
- `wall_roughness`: `0.9`
- `ceiling_albedo`: `Color(0.28, 0.2, 0.1)` — wooden ceiling
- `ceiling_roughness`: `0.85`
- `accent_emission_energy`: `2.5`
- `accent_use_palette`: `true`

### Textures
- `floor_pattern`: `{"type": "image_gen", "pattern": "flagstone", "color1": Color(0.35, 0.25, 0.12), "color2": Color(0.2, 0.14, 0.07), "width": 256, "height": 256}`
- `corridor_floor_pattern`: `{"type": "image_gen", "pattern": "flagstone", "color1": Color(0.3, 0.2, 0.1), "color2": Color(0.18, 0.12, 0.06), "width": 256, "height": 256}`
- `wall_pattern`: `{"type": "image_gen", "pattern": "ashlar", "color1": Color(0.22, 0.15, 0.08), "color2": Color(0.14, 0.1, 0.05), "width": 256, "height": 256}`
- `ceiling_pattern`: `{"type": "image_gen", "pattern": "slabs", "color1": Color(0.28, 0.2, 0.1), "color2": Color(0.18, 0.12, 0.06), "width": 256, "height": 256}`
- `monster_skin`: `{"type": "noise", "noise_type": "cellular", "frequency": 0.1, "octaves": 2, "width": 128, "height": 128}`

### Props
- `prop_density`: `0.5`
- `torch_flicker`: `true`
- `ceiling_beam_spacing`: `3`
- `pillar_chance`: `0.35`
- `rubble_chance`: `0.2`
- `room_prop_min`: `1`
- `room_prop_max`: `3`

### Monsters
- `body_albedo`: `Color(0.55, 0.3, 0.08)` — bronze
- `body_emission`: `Color(0.4, 0.25, 0.05)` — warm bronze glow
- `boss_albedo`: `Color(0.45, 0.25, 0.06)`
- `boss_emission`: `Color(0.6, 0.35, 0.1)` — bright bronze glow
- `eye_color`: `Color(0.8, 0.13, 0.0)` — warrior red

### VFX
- `muzzle_flash_color`: `Color(1.0, 0.7, 0.2)`
- `impact_color`: `Color(0.9, 0.6, 0.15)`
- `death_color`: `Color(0.8, 0.13, 0.0)` — red burst
- `aoe_blast_color`: `Color(1.0, 0.75, 0.25)`

### Projectile
- `projectile_color`: `Color(0.9, 0.65, 0.15)`
- `projectile_trail_color`: `Color(0.8, 0.5, 0.1)`

### Health Bars
- `health_bar_foreground`: `Color(0.85, 0.65, 0.2)`
- `health_bar_background`: `Color(0.12, 0.08, 0.04)`
- `health_bar_low_color`: `Color(0.8, 0.15, 0.05)`

---

## 7. Biome 3: Winter Realm (Skazka)

### Palette
- `primary`: `Color(0.27, 0.53, 0.8)` — ice blue
- `secondary`: `Color(0.85, 0.9, 0.95)` — frost white
- `tertiary`: `Color(0.15, 0.2, 0.4)` — deep blue
- `highlight`: `Color(0.8, 0.0, 0.0)` — folk red
- `danger`: `Color(0.4, 0.6, 1.0)` — frostbite blue

### Environment
- `background_color`: `Color(0.03, 0.03, 0.08)`
- `ambient_color`: `Color(0.15, 0.18, 0.25)`
- `ambient_energy`: `0.25`
- `fog_color`: `Color(0.12, 0.15, 0.22)`
- `fog_density`: `0.008`
- `fog_depth_begin`: `8.0`
- `fog_depth_end`: `50.0`
- `directional_light_color`: `Color(0.4, 0.5, 0.7)`
- `directional_light_energy`: `0.5`
- `point_light_color`: `Color(0.5, 0.65, 0.9)`
- `point_light_energy`: `2.5`
- `point_light_range_mult`: `1.8`
- `point_light_attenuation`: `1.5`
- `point_light_spacing`: `2`

### Sky
- `has_ceiling`: `false`
- `sky_config`:
  - `sky_top_color`: `Color(0.05, 0.05, 0.15)`
  - `sky_horizon_color`: `Color(0.3, 0.4, 0.6)`
  - `ground_bottom_color`: `Color(0.05, 0.05, 0.08)`
  - `ground_horizon_color`: `Color(0.2, 0.25, 0.35)`
  - `sun_angle_max`: `10.0`
  - `sun_energy`: `0.3`

### Level Materials
- `floor_albedo`: `Color(0.3, 0.35, 0.42)` — frozen stone
- `floor_roughness`: `0.3` — icy sheen
- `corridor_floor_albedo`: `Color(0.25, 0.3, 0.38)`
- `corridor_floor_roughness`: `0.25`
- `wall_albedo`: `Color(0.35, 0.4, 0.5)` — frost-covered stone
- `wall_roughness`: `0.35`
- `ceiling_albedo`: `Color(0.3, 0.35, 0.42)` — (unused, no ceiling)
- `ceiling_roughness`: `0.3`
- `accent_emission_energy`: `2.0`
- `accent_use_palette`: `false` — use frost white accents, not palette colors

### Textures
- `floor_pattern`: `{"type": "image_gen", "pattern": "cobblestone", "color1": Color(0.3, 0.35, 0.42), "color2": Color(0.2, 0.25, 0.32), "width": 256, "height": 256}`
- `corridor_floor_pattern`: `{"type": "image_gen", "pattern": "cobblestone", "color1": Color(0.25, 0.3, 0.38), "color2": Color(0.18, 0.22, 0.3), "width": 256, "height": 256}`
- `wall_pattern`: `{"type": "image_gen", "pattern": "ashlar", "color1": Color(0.35, 0.4, 0.5), "color2": Color(0.25, 0.3, 0.4), "width": 256, "height": 256}`
- `ceiling_pattern`: `{}`
- `monster_skin`: `{"type": "noise", "noise_type": "simplex", "frequency": 0.2, "octaves": 4, "width": 128, "height": 128}`

### Props
- `prop_density`: `0.35`
- `torch_flicker`: `false` — steady frozen light
- `ceiling_beam_spacing`: `4` — (unused, no ceiling)
- `pillar_chance`: `0.25`
- `rubble_chance`: `0.3`
- `room_prop_min`: `1`
- `room_prop_max`: `2`

### Monsters
- `body_albedo`: `Color(0.25, 0.35, 0.55)` — ice blue
- `body_emission`: `Color(0.2, 0.35, 0.6)` — cold glow
- `boss_albedo`: `Color(0.2, 0.3, 0.5)`
- `boss_emission`: `Color(0.3, 0.5, 0.8)` — bright ice glow
- `eye_color`: `Color(0.8, 0.0, 0.0)` — folk red

### VFX
- `muzzle_flash_color`: `Color(0.5, 0.7, 1.0)`
- `impact_color`: `Color(0.4, 0.6, 0.9)`
- `death_color`: `Color(0.8, 0.0, 0.0)` — red burst on blue
- `aoe_blast_color`: `Color(0.5, 0.7, 1.0)`

### Projectile
- `projectile_color`: `Color(0.4, 0.6, 0.9)`
- `projectile_trail_color`: `Color(0.3, 0.5, 0.8)`

### Health Bars
- `health_bar_foreground`: `Color(0.27, 0.53, 0.8)`
- `health_bar_background`: `Color(0.1, 0.1, 0.15)`
- `health_bar_low_color`: `Color(0.8, 0.15, 0.1)`

---

## 8. Monster Scene Structures

All monsters use triple detail (~20-40 primitives). Each scene has required nodes: `BodyMesh`, `EyeMesh`, `HealthBarAnchor`, `WeaponMount`. Each biome has 3 monster types (basic, variant1, variant2) plus a boss.

### Dark Forest Monsters

**8a. Leshy — Tree Spirit (basic, ~25 primitives):** Trunk body (tall box 0.7×1.4×0.6, bark green). Head box on top with bark line strips. Branch arms (2 angled boxes per arm). Root legs (2 tapered boxes). 2 firebird orange eye spheres. 3 moss patch emissive boxes on body. 4 knot spheres on trunk. HealthBarAnchor y=1.2, WeaponMount (0.6, 0.5, -0.5).

**8b. Kikimora — Swamp Hag (variant1, ~20 primitives):** Low wide ellipsoid body (box 0.9×0.6×0.7, dark swamp green). 4 spindly leg-arms (thin angled boxes, 2 per side at different angles). 2 short legs. Large bulging eye spheres (firebird orange, r=0.08). Hunched posture (body angled forward). Fast + low profile. HealthBarAnchor y=0.8, WeaponMount (0.5, 0.3, -0.4).

**8c. Vodyanoy — Water Toad (variant2, ~22 primitives):** Bulky squat body (wide box 1.1×0.8×0.9, dark teal-green). Broad flat head on top. 2 large bulging eye spheres sitting on top of head. Wide flat arms (stubby boxes). Thick legs. Belly stripe (lighter color box). Wart bumps (4-5 small spheres). Tanky + slow. HealthBarAnchor y=1.0, WeaponMount (0.6, 0.3, -0.5).

**8d. Leshy Boss (~35 primitives):** Same as Leshy basic plus: 4 antler branches (angled boxes on head), glowing chest cavity (emissive green box inset), 2 extra root tendrils. HealthBarAnchor y=1.8, WeaponMount (0.8, 0.6, -0.6).

### Golden Palace Monsters

**8e. Zmey — Armored Dragon (basic, ~28 primitives):** Wide armored body (box 1.0×0.9×0.8, bronze). 4 armor plate strips (dark horizontal boxes). Head box with jaw extension. 2 horn cylinders. Shield arms (flat wide boxes) + forearm boxes. Armored legs with strips. 2-segment tail. 2 warrior red eye spheres. 6 gold rivet spheres at joints. HealthBarAnchor y=1.1, WeaponMount (0.7, 0.4, -0.5).

**8f. Koschei — The Deathless (variant1, ~24 primitives):** Thin skeletal body (narrow box 0.4×1.3×0.3, bone-brown). Small head box with gold crown (box on top). 3 rib strips across torso. Thin long arms (single boxes). Thin legs. Glowing gold chest gem (emissive sphere). 2 warrior red eyes. Cape box behind body (dark, thin). Ranged caster type. HealthBarAnchor y=1.2, WeaponMount (0.5, 0.6, -0.4).

**8g. Strazh — Palace Guard (variant2, ~22 primitives):** Stocky armored body (box 0.8×1.0×0.6, dark wood-brown). Helmet head (box with wider top rim). Large shield on left (tall flat box with gold circle ornament). Sword on right (thin tall box, metallic). Armored legs. 2 warrior red eyes under helmet visor. Gold belt accent. HealthBarAnchor y=1.1, WeaponMount (0.7, 0.5, -0.5).

**8h. Zmey Boss — Three-Headed Dragon (~40 primitives):** Same as Zmey basic plus: 2 extra heads (3 total, offset left/right), 6 horns, 6 eyes. Glowing gold belly plate. Wing-like wider arm plates. Spiked tail tip (2 angled boxes). HealthBarAnchor y=1.7, WeaponMount (0.9, 0.5, -0.6).

### Winter Realm Monsters

**8i. Morozko — Frost Spirit (basic, ~26 primitives):** Angular crystal body (box 0.8×1.2×0.7, ice blue, low roughness). 4 diagonal facet line boxes (crystal crack pattern). Diamond head (box rotated 45° on Y). 3 crown spike cylinders. Angular shard arms (2 boxes per arm). Tapered legs (deep blue). 2 folk red eye spheres (high emission 4.0). 3 frost orb spheres. 2 shoulder crystal boxes. HealthBarAnchor y=1.3, WeaponMount (0.6, 0.4, -0.5).

**8j. Snegurochka — Ice Maiden (variant1, ~22 primitives):** Tall slender body (box 0.5×1.3×0.4, pale ice blue). Rounded head (ellipsoid box). Ice veil details (thin boxes on head sides). Graceful arms with ice orb spheres in hands (frost-white emission). Slender legs. 2 folk red eyes. Frost particle spheres near body. Ranged ice type. HealthBarAnchor y=1.2, WeaponMount (0.5, 0.5, -0.4).

**8k. Medved — Ice Bear (variant2, ~26 primitives):** Massive wide body (box 1.2×0.9×1.0, blue-grey). Broad head with rounded ears (2 small spheres). 2 frost armor plate strips across back. Thick powerful legs (4 wide boxes). Icicle claws (4 thin cylinders on front legs, ice blue). 2 folk red eyes. Heavy tank type. HealthBarAnchor y=1.1, WeaponMount (0.7, 0.3, -0.6).

**8l. Morozko Boss (~38 primitives):** Same as Morozko basic plus: full ice crown (6 spike cylinders), cape (large thin box, deep blue + frost edge emission), ice gauntlets, floating ice shards (2-3 rotated boxes), chest rune (emissive folk-red box inset). HealthBarAnchor y=1.8, WeaponMount (0.8, 0.5, -0.6).

---

## 9. New Files

| File | Responsibility |
|---|---|
| `themes/folk/folk_theme.gd` | Factory: creates 3 ThemeData biomes, registers as ThemeGroup |
| `themes/folk/leshy_basic.tscn` | Dark Forest — Leshy (tree spirit) |
| `themes/folk/kikimora_basic.tscn` | Dark Forest — Kikimora (swamp hag) |
| `themes/folk/vodyanoy_basic.tscn` | Dark Forest — Vodyanoy (water toad) |
| `themes/folk/leshy_boss.tscn` | Dark Forest boss |
| `themes/folk/zmey_basic.tscn` | Golden Palace — Zmey (dragon) |
| `themes/folk/koschei_basic.tscn` | Golden Palace — Koschei (deathless) |
| `themes/folk/strazh_basic.tscn` | Golden Palace — Strazh (guard) |
| `themes/folk/zmey_boss.tscn` | Golden Palace boss (three-headed) |
| `themes/folk/morozko_basic.tscn` | Winter Realm — Morozko (frost spirit) |
| `themes/folk/snegurochka_basic.tscn` | Winter Realm — Snegurochka (ice maiden) |
| `themes/folk/medved_basic.tscn` | Winter Realm — Medved (ice bear) |
| `themes/folk/morozko_boss.tscn` | Winter Realm boss |

## 10. Modified Files

| File | Changes |
|---|---|
| `src/themes/theme_data.gd` | Add `has_ceiling: bool`, `sky_config: Dictionary`, `wall_style: String` |
| `src/themes/theme_manager.gd` | Register folk theme group in `_load_themes()` |
| `src/generation/level_builder.gd` | Skip ceiling when `has_ceiling == false`; wall style dispatch to forest/palace/ice builders |
| `src/levels/generated_level.gd` | ProceduralSkyMaterial for open-sky biomes; monster variant spawning (basic/variant1/variant2) |
