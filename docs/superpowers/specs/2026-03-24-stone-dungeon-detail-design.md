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
- **Stone protrusions**: 2-4 small boxes per visible wall face, jutting out 0.05-0.15 units at random positions. Slightly shifted albedo (+-0.03) from base wall color.
- **Wall trim**: thin horizontal box at floor-wall and ceiling-wall junctions
- **Damage spots**: ~20% chance per wall segment — a corner recess (darker box overlaid to simulate a missing chunk)

Only wall faces adjacent to walkable tiles get protrusions and trim (no detail on wall-to-wall interior faces).

### Floors

Each floor tile becomes a slab grid:

- **Sub-tile slabs**: floor divided into 2x2 sub-tiles with thin mortar gaps (0.02-0.03 unit gaps)
- **Height variation**: individual slabs offset vertically by +-0.01-0.03 units (subtle unevenness)
- **Cracked slabs**: ~10% chance a slab splits into 2 pieces with a visible gap

Collision shape remains the original single flat box covering the full tile.

### Ceilings

- **Cross beams**: box meshes running perpendicular to corridor direction (or in a grid pattern in rooms), spaced every 2-3 tiles
- **Recessed panels**: ceiling surface between beams is slightly higher than beam bottom, creating visual depth

## Props & Decoration

### Torches (replace floating OmniLight3D)

- **Wall bracket**: small box + angled box arm mounted to wall face
- **Torch body**: vertical cylinder on top of bracket
- **Flame**: small box with emissive orange material; optional subtle Y-offset tween for flicker
- **OmniLight3D**: attached at flame position, warm color, optional energy tween for flicker
- **Placement**: at existing light positions (every `point_light_spacing` tiles along walls). Mounted on nearest wall face.

### Pillars (room decoration)

- **Base**: wider cylinder (radius ~0.2, height ~0.15)
- **Shaft**: tall cylinder (radius ~0.12, floor to ceiling)
- **Capital**: wider cylinder at top matching base proportions
- **Placement**: room corners where wall meets open space, ~20% chance per eligible corner. No collision.

### Rubble (wall-edge scatter)

- **Composition**: 3-6 small boxes and spheres of varied size (0.05-0.15 units), clustered together
- **Material**: slightly darker than floor albedo
- **Placement**: along wall-adjacent floor tiles, ~15% chance per eligible tile. No collision.

### Functional Props (room interiors)

- **Barrels**: cylinder body + thin cylinder rim at top
- **Crates**: box with thin cross-strip boxes on one face
- **Chains**: vertical series of small elongated boxes hanging from ceiling
- **Placement**: 1-3 per room, randomly positioned avoiding spawn points. No collision.

## Textures & Materials

### New Patterns in TextureFactory

Add to `_generate_image()`:

- **`flagstone`**: large irregular rectangular slabs with visible mortar lines. Stone ~(0.45, 0.4, 0.35), mortar ~(0.15, 0.12, 0.1).
- **`cobblestone`**: smaller rounded stones packed together. Used for corridor floors.
- **`ashlar`**: large rectangular cut stone blocks with thin mortar. Used for walls.
- **`slabs`**: wide rectangular panels with thin gaps. Used for ceilings.

### Stone Theme Texture Updates

```
floor_pattern = { type: "image_gen", pattern: "flagstone", ... }    # rooms
corridor_floor_pattern = { type: "image_gen", pattern: "cobblestone", ... }  # corridors
wall_pattern = { type: "image_gen", pattern: "ashlar", ... }
ceiling_pattern = { type: "image_gen", pattern: "slabs", ... }
```

Note: `corridor_floor_pattern` and `ceiling_pattern` are new ThemeData properties.

### Higher Contrast

All texture patterns use high color contrast between surface and mortar/gaps. Current stone theme bricks have ~0.1 difference; target ~0.2-0.3 difference.

### UV Scaling

Materials set `uv1_scale` based on mesh dimensions so texture patterns maintain consistent world-space size regardless of mesh scale. Target: one texture repeat per ~2 meters.

### Material Variation

- Per-tile roughness variation: +-0.05 randomized
- Stone protrusions: albedo shifted +-0.03 from base wall color
- Rubble: albedo shifted -0.05 from floor

## ThemeData Changes

New optional properties (with defaults that preserve current behavior for other themes):

```
corridor_floor_pattern: Dictionary = {}
ceiling_pattern: Dictionary = {}
prop_density: float = 1.0          # multiplier for all prop chances
torch_flicker: bool = true
ceiling_beam_spacing: int = 2      # tiles between ceiling beams
pillar_chance: float = 0.2
rubble_chance: float = 0.15
room_prop_count: Vector2i = Vector2i(1, 3)  # min/max props per room
```

## Files Changed

- `src/effects/texture_factory.gd` — Add flagstone, cobblestone, ashlar, slabs generators
- `src/generation/level_builder.gd` — Composite surfaces, prop placement, torch replacement, UV scaling
- `src/themes/theme_data.gd` — New properties for corridor/ceiling textures, prop density
- `themes/stone/stone_theme.gd` — Update texture params, set prop properties
- `test/unit/test_theming.gd` — Tests for new texture patterns and ThemeData properties

## Out of Scope

- Neon theme changes
- Imported 3D assets
- Physics/collision on props
- Sound effects for environment
- Level generation algorithm changes
