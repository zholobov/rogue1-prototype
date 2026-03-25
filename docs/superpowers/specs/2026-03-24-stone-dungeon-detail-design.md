# Stone Dungeon Visual Detail — Design Spec

## Goal

Make the Stone Dungeon theme feel like a physical place rather than an abstract grid. Replace flat box geometry with composite surfaces and props, upgrade procedural textures with higher contrast and more variety, and add environmental decoration (torches, rubble, pillars, barrels).

## Constraints

- All geometry is procedural GDScript using Godot primitive meshes (no imported assets)
- Multi-mesh compositions: torches with brackets, pillars with base/capital, etc.
- Stone-theme-only. Neon theme stays untouched.
- Level generation grid logic unchanged (same rooms, corridors, spawn points)
- Props are visual-only (no collision)
- Floor and wall collision shapes stay simple (existing BoxShape3D)
- Performance: prop/detail density tunable per theme via ThemeData properties
- GL Compatibility renderer

## Surface Geometry

### Walls

Each wall tile becomes a composite instead of a single box:

- **Base wall box**: main geometry, slightly inset from tile edge
- **Stone protrusions**: 2-4 small boxes per visible wall face, jutting out 0.05-0.15 units at random positions. Constrained to Y range 0.3 to WALL_HEIGHT-0.3 to avoid clipping with floor slabs and ceiling beams. Slightly shifted albedo (+-0.03) from base wall color.
- **Wall trim**: thin horizontal box at floor-wall and ceiling-wall junctions. Replaces the current emissive accent edge strips for themes with `accent_use_palette = false` (stone theme sets this to false). Neon theme keeps accent strips via `accent_use_palette = true`.
- **Damage spots**: ~20% chance per wall segment — a corner recess (darker box overlaid to simulate a missing chunk)

Only wall faces adjacent to walkable tiles get protrusions and trim (no detail on wall-to-wall interior faces).

### Floors

Each floor tile becomes a slab grid:

- **Sub-tile slabs**: floor divided into 2x2 sub-tiles with thin mortar gaps (0.02-0.03 unit gaps)
- **Height variation**: individual slabs offset vertically by +-0.01-0.03 units (subtle unevenness)
- **Cracked slabs**: ~10% chance a slab splits into 2 pieces along a random axis (X or Z). Gap width 0.03 units. Both halves remain coplanar (same Y offset as the original slab).

Collision shape remains the original single flat box covering the full tile.

### Ceilings

- **Cross beams**: box meshes running along the X axis, spaced every `ceiling_beam_spacing` tiles in the Z direction. In rooms, a second set runs along Z to form a grid pattern.
- **Recessed panels**: ceiling surface between beams is 0.1 units higher than beam bottom, creating visual depth.

## Props & Decoration

### Torches (replace floating OmniLight3D)

Torch placement uses a dedicated wall-adjacent pass instead of the current grid-modulo approach:

1. Iterate walkable tiles. For each tile adjacent to a wall, mark it as a torch candidate.
2. From candidates, select every `point_light_spacing`-th tile (measured along the wall run).
3. Mount the torch on the wall face adjacent to that tile.

Composition:
- **Wall bracket**: small box (0.1 x 0.05 x 0.1) + angled box arm
- **Torch body**: vertical cylinder (radius 0.03, height 0.2) on top of bracket
- **Flame**: small box (0.06 x 0.08 x 0.06) with emissive orange material; optional subtle Y-offset tween for flicker (when `torch_flicker` is true)
- **OmniLight3D**: attached at flame position, warm color, optional energy tween for flicker

For themes without torch props (neon), the existing grid-modulo light placement remains as the default path. The torch path activates when `prop_density > 0.0`.

### Pillars (room decoration)

- **Base**: cylinder (radius 0.2, height 0.15)
- **Shaft**: cylinder (radius 0.12, height WALL_HEIGHT - 0.3)
- **Capital**: cylinder (radius 0.2, height 0.15) at top
- **Placement**: room corners where wall meets open space, `pillar_chance` per eligible corner (multiplied by `prop_density`). No collision.

### Rubble (wall-edge scatter)

- **Composition**: 3-6 small boxes and spheres of varied size (0.05-0.15 units), clustered together
- **Material**: floor albedo shifted -0.05 in all channels
- **Placement**: along wall-adjacent floor tiles, `rubble_chance` per eligible tile (multiplied by `prop_density`). No collision.

### Functional Props (room interiors)

- **Barrels**: cylinder body (radius 0.15, height 0.4) + thin cylinder rim (radius 0.16, height 0.02) at top
- **Crates**: box (0.3 x 0.3 x 0.3) with thin cross-strip boxes (0.02 thick) on one face
- **Chains**: 5-8 small elongated boxes (0.03 x 0.06 x 0.03) spaced 0.08 apart vertically, hanging from ceiling. Total length 0.4-0.65 units.
- **Placement**: `room_prop_min` to `room_prop_max` per room, randomly positioned avoiding spawn points (minimum 1.0 unit distance). No collision.

## Textures & Materials

### New Patterns in TextureFactory

Add to `_generate_image()`:

- **`flagstone`**: large irregular rectangular slabs with visible mortar lines. Stone ~(0.45, 0.4, 0.35), mortar ~(0.15, 0.12, 0.1).
- **`cobblestone`**: smaller rounded stones packed together. Used for corridor floors.
- **`ashlar`**: large rectangular cut stone blocks with thin mortar. Used for walls.
- **`slabs`**: wide rectangular panels with thin gaps. Used for ceilings.

### TextureFactory.generate_for_theme Updates

Update `generate_for_theme()` to also read `corridor_floor_pattern` and `ceiling_pattern` from ThemeData, producing cache entries `"corridor_floor"` and `"ceiling"` respectively. `LevelBuilder._init()` reads these from cache alongside existing `"floor"` and `"wall"` entries.

### Stone Theme Texture Updates

```
floor_pattern = { type: "image_gen", pattern: "flagstone", ... }    # rooms
corridor_floor_pattern = { type: "image_gen", pattern: "cobblestone", ... }  # corridors
wall_pattern = { type: "image_gen", pattern: "ashlar", ... }
ceiling_pattern = { type: "image_gen", pattern: "slabs", ... }
```

### Higher Contrast

All texture patterns use high color contrast between surface and mortar/gaps. Current stone theme bricks have ~0.1 difference; target ~0.2-0.3 difference.

### UV Scaling

Materials set `uv1_scale` (a Vector3 in Godot 4) based on mesh dimensions to maintain consistent world-space texture size. Formula: `uv1_scale = Vector3(mesh_width / 2.0, mesh_height / 2.0, 1.0)` — targeting one texture repeat per ~2 meters. For walls: width = tile_size, height = WALL_HEIGHT, so `uv1_scale = Vector3(tile_size / 2.0, WALL_HEIGHT / 2.0, 1.0)`. For floors: both axes = tile_size.

### Material Variation

- Per-tile roughness variation: +-0.05 randomized
- Stone protrusions: albedo shifted +-0.03 from base wall color
- Rubble: albedo shifted -0.05 from floor

## ThemeData Changes

New optional properties (with defaults that preserve current behavior for other themes):

```
corridor_floor_pattern: Dictionary = {}
ceiling_pattern: Dictionary = {}
prop_density: float = 0.0             # 0.0 = no props (default), 1.0 = full density
torch_flicker: bool = true
ceiling_beam_spacing: int = 2         # tiles between ceiling beams
pillar_chance: float = 0.2            # base chance, multiplied by prop_density
rubble_chance: float = 0.15           # base chance, multiplied by prop_density
room_prop_min: int = 1                # minimum props per room
room_prop_max: int = 3                # maximum props per room
```

`prop_density` is a global multiplier applied to all per-element chances: `effective_chance = base_chance * prop_density`. At 0.0 (default), no props spawn — preserving current behavior for neon and any future themes that don't set it. Stone theme sets `prop_density = 1.0`.

### Accent Strip Behavior

The existing `_add_edge_strips` behavior is controlled by `accent_use_palette`:
- `true` (neon): glowing emissive edge strips as before
- `false` (stone): replaced by non-emissive wall trim boxes matching stone material

Stone theme changes `accent_use_palette` from `true` to `false`.

## Files Changed

- `src/effects/texture_factory.gd` — Add flagstone, cobblestone, ashlar, slabs generators; update `generate_for_theme()` to handle corridor_floor and ceiling patterns
- `src/generation/level_builder.gd` — Composite surfaces, prop placement, torch replacement, UV scaling, accent strip / wall trim branching
- `src/themes/theme_data.gd` — New properties for corridor/ceiling textures, prop density, room prop counts
- `themes/stone/stone_theme.gd` — Update texture params, set prop properties, set accent_use_palette = false
- `test/unit/test_theming.gd` — Tests for new texture patterns and ThemeData properties

## Out of Scope

- Neon theme changes
- Imported 3D assets
- Physics/collision on props
- Sound effects for environment
- Level generation algorithm changes
