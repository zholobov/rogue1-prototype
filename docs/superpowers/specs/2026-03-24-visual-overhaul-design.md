# Visual Overhaul — Neon Dungeon Design Spec

## Goal

Transform the flat-colored prototype into a moody neon dungeon aesthetic using StandardMaterial3D emission and GPUParticles3D. No custom shaders. GL Compatibility renderer.

## Scope

Visual-only changes. No gameplay modifications. Touches LevelBuilder, monster/projectile entities, HUD, and GeneratedLevel.

---

## 1. Level Geometry & Materials

### Base Materials (modify existing LevelBuilder materials)

- **Floor**: albedo near-black `Color(0.05, 0.05, 0.08)`, slight roughness 0.9
- **Walls**: albedo dark gray `Color(0.08, 0.08, 0.1)`, roughness 0.85
- **Ceiling**: albedo near-black `Color(0.03, 0.03, 0.05)`, roughness 0.95

### Emissive Edge Strips

- Thin BoxMesh strips (width 0.05, height 0.02) placed along wall-floor and wall-ceiling seams
- Material: albedo black, emission enabled, emission color randomized per-tile from palette: cyan `#00d4ff`, magenta `#ff00aa`, purple `#aa44ff`, teal `#00ffaa`
- Emission energy: 2.0-3.0 (randomized slightly for variation)
- Placement logic: when placing a walkable tile (room or corridor), check 4 cardinal neighbors. For each neighbor that is a wall, place a floor-level strip along that edge of the walkable tile, and a ceiling-level strip at the same edge. Use `tile_name` from the grid (`"room"` vs `"corridor"`) to distinguish tile types.

### Floor Glow Overlay

- For room tiles only (check `tile_name == "room"`): a second flat BoxMesh (same size as floor, offset Y+0.01) with an emissive material
- Material: albedo transparent black, emission color matching room's palette color, emission energy 0.3 (subtle)
- Creates a faint glow on room floors that distinguishes them from darker corridors
- Implementation: StandardMaterial3D with low emission energy, no texture needed

### Tile Color Variation

- Room tiles: slightly warmer base (floor `Color(0.06, 0.05, 0.08)`)
- Corridor tiles: slightly cooler base (floor `Color(0.04, 0.05, 0.07)`)
- Each tile gets a random neon accent color from the palette (used for its edge strips and floor overlay)

---

## 2. Lighting & Atmosphere

### OmniLights (modify existing LevelBuilder light placement)

- Replace white lights with colored neon lights
- Color cycle from palette: cyan, magenta, purple, warm orange `#ff8800`
- Reduce range: `Config.level_tile_size * 1.5` (was `* 2.0`)
- Increase placement density: every 2x2 tiles (was 3x3)
- Energy: 0.8 (was 1.0) — dimmer individual lights, more of them
- Attenuation: 2.0 (sharper falloff for defined pools of light)

### DirectionalLight3D

- Reduce energy to 0.1 (was 1.0) — neon lights should dominate
- Color: cool blue-white `Color(0.6, 0.65, 0.8)`

### WorldEnvironment (modify existing in GeneratedLevel)

- Background: near-black `Color(0.02, 0.02, 0.04)`
- Ambient light: very low energy 0.1, color dark blue `Color(0.1, 0.1, 0.2)`
- Fog enabled: depth fog (exponential density). Do NOT use volumetric fog (Forward+ only).
  - `env.fog_enabled = true`
  - Fog color: dark blue `Color(0.02, 0.02, 0.06)`
  - Fog density: 0.02 (subtle, adds depth)
  - Fog sky affect: 0.0

### Modifier Support (deferred)

Deferred: depends on game-loop-progression spec. Do not implement `Config.light_range_mult` reads until that spec lands. The OmniLight range is hardcoded to `Config.level_tile_size * 1.5` for now.

---

## 3. Combat Effects

### Muzzle Flash

- GPUParticles3D spawned at camera position when firing
- 4-6 particles, lifetime 0.05s, one-shot
- Material: emissive white/yellow, billboard mode
- Size: 0.1-0.2, fade out over lifetime
- Created by GeneratedLevel's projectile spawn handler (where projectile_requested is connected)

### Projectile Trail

- GPUParticles3D attached to each projectile entity as a child
- Continuous emission, 10-15 particles/sec
- Lifetime: 0.3s (short trail)
- Material: emissive, color matches weapon element
  - none: white `#ffffff`
  - fire: orange-red `#ff4400`
  - ice: cyan `#00ddff`
  - water: blue `#0066ff`
- Size: 0.05, shrink over lifetime
- Gravity: 0 (follows projectile path)

### Impact Particles

- GPUParticles3D spawned at collision point
- 8-12 particles, one-shot, lifetime 0.2s
- Material: emissive, color matches weapon element (same palette as trail)
- Direction: hemisphere opposite to projectile travel direction (approximation; no collision normal available from Area3D.body_entered)
- Initial velocity: 3-5 (spark burst)
- Size: 0.03-0.06

### Implementation

- New helper: `src/effects/vfx_factory.gd` — static methods to create particle nodes
  - `create_muzzle_flash(position: Vector3, color: Color) -> GPUParticles3D`
  - `create_trail(element: String) -> GPUParticles3D`
  - `create_impact(position: Vector3, direction: Vector3, element: String) -> GPUParticles3D`
- Muzzle flash and impact are one-shot; connect `GPUParticles3D.finished` signal to `queue_free` (one-shot does not auto-free)
- Trail is parented to projectile node, freed with it

---

## 4. Monster Appearance

### Body Material

- Dark base: albedo `Color(0.08, 0.08, 0.1)`
- Emission enabled: random neon color from palette, energy 1.0
- Creates a subtle glow on the monster body

### Emissive Eyes

- Two small BoxMesh instances (0.08 x 0.08 x 0.02) positioned on front face of monster mesh
- Material: emissive red `Color(1.0, 0.1, 0.1)`, energy 3.0
- Positioned at Y offset +0.5 from center (upper area of 1.6-height body), X offset ±0.12

### Size Variation

- Random scale factor 0.8-1.2 applied to entire MonsterEntity on spawn
- Stored as a property, doesn't affect gameplay stats (just visual)

### Hit Flash

- On taking damage: temporarily boost emission energy to 5.0 for 0.1s, then restore
- Implementation: MonsterEntity stores reference to body material, `flash()` method uses a Timer or tween

---

## 5. Player Feedback

### Damage Flash

- ColorRect overlay added to HUD scene, covering full screen
- Color: `Color(1.0, 0.0, 0.0, 0.3)` — semi-transparent red
- Default: hidden (modulate.a = 0)
- On player taking damage: set alpha to 0.3, tween to 0 over 0.15s
- HUD.gd watches player health each frame, detects decrease to trigger flash

### Monster Health Bars

- Billboard Sprite3D or SubViewport above each monster
- Simple approach: a Sprite3D with a dynamically generated texture (colored bar)
- Simpler approach for prototype: Label3D showing "HP: X" — functional but ugly
- **Chosen**: Small Node3D with two BoxMesh children (background bar + foreground bar)
  - Background: dark gray, width 1.0, height 0.05
  - Foreground: green→red gradient based on HP%, width scales with HP ratio
  - Positioned Y+1.2 above monster (above the body mesh)
  - Billboard: health bar Node3D uses `look_at(camera.global_position)` in MonsterEntity._process(). Do NOT use material billboard mode on BoxMesh bars (causes distortion).
  - Only visible when monster HP < max (don't clutter screen for undamaged monsters)

### Kill Currency Text

- Floating "+10" text at monster death position
- Label3D, billboard mode, emissive green text
- Animate: rise Y +1.0 over 0.8s, fade out
- Auto-free after animation
- Created by S_Death or GeneratedLevel on monster kill

---

## 6. New Files

- `src/effects/vfx_factory.gd` — static factory for particle effects (muzzle flash, trail, impact)
- `src/effects/floating_text.gd` — floating damage/currency text

## 7. Modified Files

- **LevelBuilder** (`src/generation/level_builder.gd`) — dark materials, emissive edge strips, colored OmniLights, denser light placement, floor glow overlay for rooms
- **GeneratedLevel** (`src/levels/generated_level.gd`) — darker WorldEnvironment, fog, dimmer directional light, muzzle flash on projectile spawn
- **MonsterEntity** (`src/entities/monster.gd`) — dark emissive body material, glowing eyes, size variation, hit flash method
- **ProjectileEntity** (`src/entities/projectile.gd`) — attach trail particles on spawn
- **HUD** (`src/ui/hud.gd` + `hud.tscn`) — damage flash overlay ColorRect
- **S_Death** (`src/systems/s_death.gd`) — spawn floating currency text on monster kill

## 8. Neon Color Palette

```
CYAN:    Color(0.0, 0.83, 1.0)    #00d4ff
MAGENTA: Color(1.0, 0.0, 0.67)    #ff00aa
PURPLE:  Color(0.67, 0.27, 1.0)   #aa44ff
TEAL:    Color(0.0, 1.0, 0.67)    #00ffaa
ORANGE:  Color(1.0, 0.53, 0.0)    #ff8800
```

Used for: edge strips, OmniLight colors, monster body glow. Randomized per-tile / per-monster from this palette.
