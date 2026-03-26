# Russian Folk Tales Theme — Design Spec

## Goal

Create a three-biome theme inspired by Russian folk tales: Dark Forest (Baba Yaga), Golden Palace (Bylina), and Winter Realm (Skazka). Each biome has distinct colors, materials, monsters, and atmosphere. Forest and Winter have open sky (ProceduralSkyMaterial, no ceiling). Golden Palace has ceiling. Monsters and level geometry are triple-detail (~25-40 primitives per monster, rich wall/floor/prop composition).

## Scope

- 3 biome ThemeData definitions with full 71-property configurations
- 6 monster scenes (basic + boss per biome)
- ThemeData gains `has_ceiling: bool` and `sky_config: Dictionary`
- LevelBuilder modified to skip ceiling and add sky when `has_ceiling == false`
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

---

## 2. LevelBuilder Changes

In `build()`, wrap ceiling creation in a check:

```gdscript
if ThemeManager.active_theme.has_ceiling:
    _add_ceiling(...)
```

No other changes needed — walls, floors, lights, props all work as before.

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

All monsters use triple detail (~25-40 primitives). Each scene has required nodes: `BodyMesh`, `EyeMesh`, `HealthBarAnchor`, `WeaponMount`.

### 8a. Leshy Basic (~25 primitives)

```
LeshyBasic (Node3D)
├── BodyMesh (BoxMesh 0.7×1.4×0.6) — bark green
├── HeadMesh (BoxMesh 0.45×0.35×0.4) — at y=0.85
├── BarkLine1-4 (BoxMesh thin strips on body) — dark texture lines
├── ArmUpperLeft (BoxMesh 0.3×0.12×0.1, angled) — branch
├── ArmLowerLeft (BoxMesh 0.25×0.1×0.08, angled) — branch tip
├── ArmUpperRight + ArmLowerRight — mirrored
├── LegLeft (BoxMesh 0.15×0.35×0.12) — root
├── LegRight — mirrored
├── EyeMesh (SphereMesh r=0.06 at y=0.9) — firebird orange emission
├── EyeRight (SphereMesh r=0.06)
├── MossPatch1-3 (BoxMesh thin emissive green patches on body)
├── Knot1-4 (SphereMesh r=0.04 on trunk) — gnarled bumps
├── HealthBarAnchor (Marker3D at y=1.2)
└── WeaponMount (Marker3D at 0.6, 0.5, -0.5)
```

### 8b. Leshy Boss (~35 primitives)

Same as basic plus:
- 4 antler branches (angled boxes on head)
- Glowing chest cavity (emissive green box inset)
- 2 extra root tendrils (trailing boxes)
- HealthBarAnchor at y=1.8
- WeaponMount at 0.8, 0.6, -0.6

### 8c. Zmey Basic (~28 primitives)

```
ZmeyBasic (Node3D)
├── BodyMesh (BoxMesh 1.0×0.9×0.8) — bronze
├── ArmorPlate1-4 (BoxMesh thin horizontal strips) — dark bronze
├── HeadMesh (BoxMesh 0.4×0.35×0.45) — at y=0.6, z=-0.3
├── JawMesh (BoxMesh 0.3×0.1×0.2) — extends forward from head
├── HornLeft (CylinderMesh r=0.05, h=0.2, angled)
├── HornRight — mirrored
├── ShieldArmLeft (BoxMesh 0.3×0.35×0.08) — flat shield
├── ForearmLeft (BoxMesh 0.1×0.25×0.1) — behind shield
├── ShieldArmRight + ForearmRight — mirrored
├── LegLeft (BoxMesh 0.18×0.3×0.15) — armored leg
├── LegRight — mirrored
├── LegStrip1-2 (BoxMesh dark strips on legs) — armor detail
├── TailSeg1 (BoxMesh 0.15×0.12×0.2) — tail
├── TailSeg2 (BoxMesh 0.1×0.08×0.15) — tail tip
├── EyeMesh (SphereMesh r=0.06) — warrior red emission
├── EyeRight (SphereMesh r=0.06)
├── Rivet1-6 (SphereMesh r=0.025, gold emissive) — joint details
├── HealthBarAnchor (Marker3D at y=1.1)
└── WeaponMount (Marker3D at 0.7, 0.4, -0.5)
```

### 8d. Zmey Boss (~40 primitives)

Three-headed dragon. Same structure plus:
- 2 extra heads (HeadMesh2, HeadMesh3) offset left/right
- 6 total horns, 6 total eyes
- Glowing gold belly plate (emissive box inset)
- Wing-like arm plates (wider shields)
- Spiked tail tip (2 angled boxes)
- HealthBarAnchor at y=1.7
- WeaponMount at 0.9, 0.5, -0.6

### 8e. Morozko Basic (~26 primitives)

```
MorozkoBasic (Node3D)
├── BodyMesh (BoxMesh 0.8×1.2×0.7) — ice blue
├── FacetLine1-4 (BoxMesh thin diagonal strips) — crystal crack pattern
├── HeadMesh (BoxMesh 0.35×0.35×0.35, rotated 45° on Y) — diamond shape
├── CrownSpike1-3 (CylinderMesh r=0.03, h=0.2) — ice crown
├── ArmUpperLeft (BoxMesh 0.25×0.12×0.08, sharp angle) — ice shard
├── ArmLowerLeft (BoxMesh 0.2×0.1×0.06) — shard tip
├── ArmUpperRight + ArmLowerRight — mirrored
├── LegLeft (BoxMesh 0.14×0.35×0.12) — deep blue
├── LegRight — mirrored
├── EyeMesh (SphereMesh r=0.06) — folk red emission (4.0)
├── EyeRight (SphereMesh r=0.06)
├── FrostOrb1-3 (SphereMesh r=0.03, frost-white emissive) — orbiting aura
├── ShoulderCrystal1-2 (BoxMesh small, rotated) — shoulder decoration
├── HealthBarAnchor (Marker3D at y=1.3)
└── WeaponMount (Marker3D at 0.6, 0.4, -0.5)
```

### 8f. Morozko Boss (~38 primitives)

Same structure plus:
- Full ice crown (6 spike cylinders)
- Cape (large thin box behind body, deep blue + frost edge emission)
- Ice gauntlets (larger arm boxes with shard extensions)
- Floating ice shards (2-3 small rotated boxes)
- Chest rune (emissive folk-red box inset — contrast piece)
- HealthBarAnchor at y=1.8
- WeaponMount at 0.8, 0.5, -0.6

---

## 9. New Files

| File | Responsibility |
|---|---|
| `themes/folk/folk_theme.gd` | Factory: creates 3 ThemeData biomes, returns ThemeGroup |
| `themes/folk/leshy_basic.tscn` | Dark Forest basic monster scene |
| `themes/folk/leshy_boss.tscn` | Dark Forest boss monster scene |
| `themes/folk/zmey_basic.tscn` | Golden Palace basic monster scene |
| `themes/folk/zmey_boss.tscn` | Golden Palace boss monster scene |
| `themes/folk/morozko_basic.tscn` | Winter Realm basic monster scene |
| `themes/folk/morozko_boss.tscn` | Winter Realm boss monster scene |

## 10. Modified Files

| File | Changes |
|---|---|
| `src/themes/theme_data.gd` | Add `has_ceiling: bool = true`, `sky_config: Dictionary = {}` |
| `src/themes/theme_manager.gd` | Register folk theme group in `_load_themes()` |
| `src/generation/level_builder.gd` | Skip ceiling when `has_ceiling == false` |
| `src/levels/generated_level.gd` | Set up ProceduralSkyMaterial for open-sky biomes |
