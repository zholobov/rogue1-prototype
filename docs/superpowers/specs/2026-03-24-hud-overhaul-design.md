# HUD Overhaul — Design Spec

## Goal

Replace the plain-text HUD with a themed, game-quality UI. Add crosshair, styled health bar, weapon panel, ability cooldown indicators, floating damage numbers, kill feed, boss health bar, and minimap. All visual elements adapt to the active theme via ThemeData.

## Constraints

- All UI built with Godot Control nodes (no imported assets)
- Theme-adaptive: every color, panel background, and text color sourced from ThemeData
- HUD re-themes on `theme_changed` signal
- Performance: minimap updates at low frequency (not every frame)
- GL Compatibility renderer
- Existing HUD file (`src/ui/hud.gd`, `src/ui/hud.tscn`) is replaced, not patched
- The existing GodMode CheckBox is intentionally removed from the HUD (god mode is toggled via `Config.god_mode` in code/debug console only)

## Screen Layout

```
+--------------------------------------------------+
|  [Minimap]              [Boss HP Bar]  [Kill Feed]|
|  120x120                 40% width      top-right |
|  top-left                top-center     3-4 lines |
|                                                    |
|                                                    |
|                    [Crosshair]                     |
|                   weapon-specific                  |
|                  [Damage Numbers]                  |
|                   float upward                     |
|                                                    |
|  [Health Bar]    [Abilities]      [Weapon Panel]  |
|  bottom-left     bottom-center    bottom-right    |
+--------------------------------------------------+
```

## HUD Elements

### Crosshair (weapon-specific reticles)

Each weapon type has a distinct reticle shape, built from Control nodes (ColorRect). Element color applied as modulate tint — base shapes are white/neutral, `get_element_color()` tints them.

Crosshair selection is keyed on the weapon preset index (matching `Config.weapon_presets` array order):
- **Index 0 — Pistol**: Classic crosshair — center dot + 4 lines with gap. No element tint (neutral).
- **Index 1 — Flamethrower**: Concentric circles — wide outer ring (spray cone), tight inner ring, center dot. Fire orange tint.
- **Index 2 — Ice Rifle**: Sniper-style — thin full-length cross lines with center gap, tiny dot, diagonal corner ticks. Ice cyan tint.
- **Index 3 — Water Gun**: Scatter pattern — center dot with 6 spray dots at random-ish positions, dashed outer circle. Water blue tint.

`CrosshairManager` is a child Control node of the HUD. It stores the current weapon index and rebuilds the reticle when the index changes. The HUD polls the player's `C_Weapon.element` each frame and maps it to the preset index via `Config.weapon_presets` lookup. This avoids needing a new signal — weapon switching is infrequent enough that polling is fine.

### Health Bar

- Bottom-left, ~200px wide
- Background bar uses `health_bar_background` (reuses existing ThemeData property)
- Fill bar uses `health_bar_foreground`, lerps to `health_bar_low_color` as HP drops (reuses existing ThemeData properties — same colors for player and monster health bars)
- Numeric overlay centered on bar: "75 / 100"
- Text uses `ui_text_color`
- Label "HEALTH" above bar uses `ui_text_color` at reduced opacity

### Weapon Info Panel

- Bottom-right, ~200px wide
- Panel background uses `ui_panel_color` with border from `ui_accent_color`
- Shows 4 slot indicators (numbered 1-4), active slot highlighted with `ui_accent_color`
- Weapon name + element text
- Updates on weapon switch (keys 1-4)

### Ability Cooldown Indicators

- Bottom-center, 3 circular indicators side by side
- Each is a custom `Control` subclass that draws a circle via `_draw()` using `draw_arc()` for the border ring and `draw_circle()` for the fill. No textures or shaders needed.
- States:
  - Ready: `ui_accent_color` border, "READY" label below in `health_bar_foreground`
  - On cooldown: dim border (`ui_panel_color`), arc fill sweeps clockwise showing progress, countdown text below
  - Active (lifesteal): `highlight` color border, "ON" text
- Labels: DASH, AOE, LIFE
- Reads from `C_Dash`, `C_AoEBlast`, `C_Lifesteal` components on the player entity

### Floating Damage Numbers

Extends the existing `FloatingText` class (`src/effects/floating_text.gd`) which already provides billboard rendering, float-up animation (1 unit over 0.8s), and fade-out. Changes:

- Override `modulate` to use `ThemeManager.active_theme.get_element_color(element)` instead of the hardcoded `health_bar_foreground`
- Add random X offset (±0.3) via `global_position.x += randf_range(-0.3, 0.3)` in `show_text()`
- `DamageNumberFactory` is a static helper (like `VfxFactory`) that creates a `FloatingText`, sets the element color, and calls `show_text()`
- Triggered from `S_Damage.apply_damage()` — the single damage entry point. Add `DamageEvents.damage_dealt.emit(target_position, actual_damage, element)` at the end of `apply_damage()`, after damage is applied. The `target_position` is obtained from `target_entity.get_parent().global_position` (the CharacterBody3D parent).

### Kill Feed

- Top-right corner, up to 4 visible entries
- Each entry: Label node with text in `ui_kill_feed_color`, fades out after 3 seconds
- New entries push older ones up
- Triggered by existing `actor_died` signal in `S_Death`
- Format: "Defeated Enemy" for basic monsters, "Defeated Boss" for entities with `C_BossAI`. (No per-monster-type names — prototype simplicity.)

### Boss Health Bar

- Top-center, ~40% screen width, only visible during boss fights
- Boss name label above bar in `ui_accent_color`
- Bar fill: `health_bar_foreground` → `health_bar_low_color` gradient as HP drops
- Background: `health_bar_background`
- Hidden by default. `generated_level.gd` calls `hud.show_boss_bar(boss_entity)` after spawning the boss in `_spawn_boss()`. The HUD stores the reference and reads `C_Health` each frame. When health reaches 0, the bar hides.

### Minimap

- Top-left, 120x120px, semi-transparent background (`ui_background_color` at ~0.7 alpha)
- Custom `Control` subclass using `_draw()` with `draw_rect()` calls — no SubViewport
- `generated_level.gd` passes `level_data` to the HUD after instantiation: `hud.setup_minimap(level_data)`. The minimap reads `level_data.grid` (2D array of tile name strings) and `level_data.width`/`level_data.height`.
- Tile type mapping (string values from TileRules):
  - `"room"`, `"spawn"` → `ui_minimap_room` fill
  - `"corridor"` → `ui_minimap_room` darkened by 0.03 per channel
  - `"wall"` → `ui_minimap_wall` fill
  - `"empty"` → not drawn (transparent)
- Player dot: `health_bar_foreground` color, updates position each frame by reading player `global_position` and mapping to grid coordinates
- Monster dots: `health_bar_low_color`, iterates `"monsters"` group each update
- Redraws via `queue_redraw()` at ~10 FPS using a Timer, not every `_process` frame

## ThemeData Changes

New properties with defaults that preserve current behavior:

```
# --- HUD ---
@export_group("HUD")
@export var ui_crosshair_color: Color = Color(1.0, 1.0, 1.0)
@export var ui_minimap_room: Color = Color(0.15, 0.15, 0.2)
@export var ui_minimap_wall: Color = Color(0.3, 0.3, 0.4)
@export var ui_kill_feed_color: Color = Color(1.0, 1.0, 1.0)
```

The existing `health_bar_foreground`, `health_bar_background`, and `health_bar_low_color` properties are reused for the player health bar and boss health bar (same colors as monster health bars — consistent visual language). No new `ui_bar_*` properties are added.

The existing `ui_background_color`, `ui_panel_color`, `ui_text_color`, `ui_accent_color` are already defined on both themes and get wired into HUD panels. No changes needed to their values.

Stone theme adds:
```
ui_crosshair_color = Color(0.9, 0.85, 0.7)
ui_minimap_room = Color(0.2, 0.18, 0.15)
ui_minimap_wall = Color(0.4, 0.35, 0.3)
ui_kill_feed_color = Color(0.9, 0.75, 0.4)
```

Neon theme adds:
```
ui_crosshair_color = Color(1.0, 1.0, 1.0)
ui_minimap_room = Color(0.1, 0.1, 0.2)
ui_minimap_wall = Color(0.2, 0.3, 0.5)
ui_kill_feed_color = Color(0.0, 0.83, 1.0)
```

## Damage Events

`S_Damage.apply_damage()` is the single entry point for all damage in the game. A `damage_dealt` signal is added to a new `DamageEvents` autoload singleton:

```
signal damage_dealt(position: Vector3, amount: int, element: String)
```

At the end of `S_Damage.apply_damage()`, after damage is applied:
```gdscript
var parent_body = target_entity.get_parent()
if parent_body and DamageEvents:
    DamageEvents.damage_dealt.emit(parent_body.global_position, actual_damage, element)
```

The HUD (`generated_level.gd`) connects to `DamageEvents.damage_dealt` and spawns `FloatingText` via `DamageNumberFactory`.

## Files Changed

- `src/themes/theme_data.gd` — New HUD properties (4 new: crosshair_color, minimap_room, minimap_wall, kill_feed_color)
- `themes/stone/stone_theme.gd` — Stone HUD color overrides
- `themes/neon/neon_theme.gd` — Neon HUD color overrides
- `src/ui/hud.gd` — Complete rewrite: styled panels, health bar, weapon panel, abilities, kill feed, boss bar
- `src/ui/hud.tscn` — New scene tree with proper layout containers
- `src/ui/crosshair.gd` (new) — CrosshairManager with per-weapon reticles via Control nodes
- `src/ui/minimap.gd` (new) — Minimap rendering via custom `_draw()` from tile grid
- `src/ui/ability_indicator.gd` (new) — Custom Control for circular cooldown display via `_draw()`
- `src/effects/damage_number_factory.gd` (new) — Static helper wrapping FloatingText with element colors
- `src/effects/floating_text.gd` — Add element color parameter and random X offset
- `src/events/damage_events.gd` (new) — Autoload singleton for damage signal
- `src/systems/s_damage.gd` — Emit `DamageEvents.damage_dealt` at end of `apply_damage()`
- `src/levels/generated_level.gd` — Pass `level_data` to minimap, boss entity to boss bar, connect damage signal
- `project.godot` — Register `DamageEvents` as autoload
- `test/unit/test_theming.gd` — Tests for new ThemeData properties

## Out of Scope

- First-person weapon viewmodel (separate project)
- Ammo system (infinite ammo stays)
- HUD animations/transitions beyond fade
- Settings menu / HUD customization
- Fog-of-war on minimap
- Per-monster-type names in kill feed
