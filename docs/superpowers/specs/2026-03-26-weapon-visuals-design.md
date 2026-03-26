# Weapon Visuals — Design Spec

## Goal

Add visible weapon models throughout the game: first-person viewmodels in the player's hands, third-person weapon attachments on monsters (and future remote players), and weapon silhouette icons in the HUD panel. Also enable monsters to spawn with ranged weapons.

## Scope

- First-person viewmodel for local player (4 weapons)
- Third-person world model for monsters and remote players
- HUD weapon panel icons (replace text with silhouettes)
- Monster weapon spawning with ranged behavior
- Theme-aware materials (element glow, theme colors)

Not covered: weapon pickup/drop, custom weapon creation, weapon animations beyond recoil/switch.

---

## 1. WeaponModelFactory

### Purpose

Static factory that builds weapon meshes from geometric primitives (`BoxMesh`, `CylinderMesh`, `SphereMesh`). Each weapon is 14-18 `MeshInstance3D` children composed into a recognizable shape. Materials use `StandardMaterial3D` with element-colored emission on accent pieces.

### Class: `WeaponModelFactory` (static methods, no instance state)

File: `src/effects/weapon_model_factory.gd` (4-space indentation)

### API

```gdscript
# Full-detail model for first-person view (14-18 primitives)
static func create_viewmodel(weapon_index: int, element: String) -> Node3D

# Simplified model for third-person attachment (6-8 primitives)
static func create_world_model(weapon_index: int, element: String) -> Node3D

# 2D silhouette for HUD panel (4-6 ColorRect children)
static func create_hud_icon(weapon_index: int, element: String) -> Control
```

### Weapon Shapes (Viewmodel Detail)

**Pistol (index 0):** Barrel (box) + front/rear sights (small boxes) + slide body (box) with panel lines (thin dark boxes) + ejection port (box) + grip (box, brown) with texture lines + trigger guard (box outline) + trigger (small box) + screws (tiny spheres). ~14 primitives. No element glow (standard gray).

**Flamethrower (index 1):** Wide barrel (box) with 3 ring segments (thin boxes) + muzzle heat glow (emissive box) + body (box) with fire accent strip (emissive thin box) + panel line + fuel tank (ellipsoid via scaled sphere) with inner ring + connector pipe (box) + igniter (small box) + grip with lines + indicator light (emissive sphere). ~16 primitives. Fire element: orange emission on accent strip, muzzle, indicator.

**Ice Rifle (index 2):** Long thin barrel (box) with 3 rings + muzzle glow (emissive sphere) + receiver body (box) with ice accent strip (emissive thin box) + panel line + scope body (box) with front/rear lens glow (emissive spheres) + stock upper/lower (boxes) + grip with lines + trigger guard + trigger + mag well. ~18 primitives. Ice element: cyan emission on accent strip, muzzle, scope lenses.

**Water Gun (index 3):** Stubby wide barrel (box) with 2 rings + nozzle tip (box) with glow (emissive sphere) + body (box) with water accent strip (emissive thin box) + panel line + water tank (scaled sphere) with cap (box) + water level indicator (emissive sphere) + connector (box) + chunky grip with 3 texture lines + trigger guard + pump trigger. ~18 primitives. Water element: blue emission on accent strip, nozzle, water indicator.

### World Model (Simplified)

Same silhouette but fewer primitives: barrel + body + grip + element accent. No panel lines, screws, or interior detail. 6-8 primitives. Scaled to 60% of viewmodel size.

### Materials

- **Base metal:** `ThemeManager.active_theme.wall_albedo` lightened by 20%, roughness 0.7
- **Dark metal:** base darkened by 30% (panel lines, barrel rings)
- **Grip:** brown `Color(0.27, 0.2, 0.13)`, roughness 0.9
- **Element accent:** emission color from `ThemeData.get_element_color(element)`, emission energy 2.0, pulsing between 1.0-2.0 via sine wave
- **No element:** accent pieces use base metal color, no emission

Materials are created once per factory call. Theme changes require re-creating the weapon model (handled by `S_WeaponVisual`).

---

## 2. C_WeaponVisual Component

File: `src/components/c_weapon_visual.gd` (4-space indentation)

```gdscript
class_name C_WeaponVisual
extends Component

@export var weapon_index: int = -1       # -1 = no visible weapon
@export var element: String = ""
@export var show_viewmodel: bool = false  # true only for local player
```

Added to:
- **Player entities** — always. `show_viewmodel = true` for local player, `false` for remote.
- **Monster entities** — only when armed (based on `monster_weapon_chance` roll or boss).

When `weapon_index` changes (detected by `S_WeaponVisual`), the old mesh is destroyed and a new one is spawned.

---

## 3. S_WeaponVisual System

File: `src/systems/s_weapon_visual.gd` (4-space indentation)

### Query

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_WeaponVisual])
```

### Behavior

Each frame, for each entity with `C_WeaponVisual`:

1. **Check for weapon change:** Compare `C_WeaponVisual.weapon_index` against a cached `_last_index` dictionary. If changed, destroy old mesh node, create new one from factory.

2. **Viewmodel (local player, `show_viewmodel == true`):**
   - Attach to `Camera3D` child of the player's `CharacterBody3D`
   - Local position: `Vector3(0.35, -0.35, -0.6)` (bottom-right of view)
   - Local rotation: `Vector3(0, -5, 0)` degrees (slight inward angle)
   - Idle sway: offset position by `sin(time * 2.0) * 0.003` on X and Y

3. **World model (monsters, remote players, `show_viewmodel == false`):**
   - Attach to `WeaponMount` Marker3D if it exists on the entity's parent node
   - Fallback position: `Vector3(0.4, 0.3, -0.3)` relative to body if no mount point
   - Scale: `Vector3(0.6, 0.6, 0.6)`

4. **Fire animation:** When `C_Weapon.is_firing` and cooldown just reset (detect via cooldown transition), play recoil tween on viewmodel:
   - Kick: translate Z +0.05, rotate X +3 degrees over 0.05s
   - Return: translate/rotate back over 0.1s
   - Uses `create_tween()` on the weapon mesh node

5. **Weapon switch animation:** When weapon_index changes on a viewmodel entity:
   - Lower: translate Y -0.3 over 0.15s
   - Swap mesh (destroy old, create new)
   - Raise: translate Y from -0.3 to 0 over 0.15s

6. **Element pulse:** For elemental weapons, tween accent material emission energy between 1.0 and 2.0 using sine wave (not a Tween — just set in process).

### Registration

Registered in `generated_level.gd` alongside other systems. Needs to run after `S_Weapon` (so it can detect fire events).

---

## 4. First-Person Viewmodel Integration

### Player.gd Changes

In `_equip_weapon(index)`, update `C_WeaponVisual`:

```gdscript
var wv = ecs_entity.get_component(C_WeaponVisual)
if wv:
    wv.weapon_index = index
    wv.element = weapon.element
```

In `setup(peer_id, is_local)`, set `show_viewmodel`:

```gdscript
var wv = ecs_entity.get_component(C_WeaponVisual)
if wv:
    wv.show_viewmodel = is_local
```

### Projectile Spawn Point

Currently projectiles spawn at `camera.global_position + (-camera.basis.z * 1.0)`. With the viewmodel, the muzzle position is known. Update `generated_level.gd` to optionally read the muzzle position from the viewmodel's `MuzzlePoint` Marker3D child (if it exists), falling back to the camera offset calculation.

Each weapon model includes a `MuzzlePoint` Marker3D at the barrel tip. The factory places it at the correct position for each weapon shape.

---

## 5. HUD Weapon Panel Icons

### Changes to hud.gd

Replace the weapon name/element labels with a weapon icon + text layout:

**Current:** `[slot indicators]` + `weapon name` + `element text`

**New:** `[weapon icon]` + `weapon name + element` + `[slot indicators]`

The weapon icon is a `Control` node returned by `WeaponModelFactory.create_hud_icon()`. It contains 4-6 `ColorRect` children arranged to form the weapon silhouette. Size: ~64x48 pixels.

When `_update_weapon()` detects a weapon change, destroy the old icon and create a new one. The icon's accent ColorRects use the element color.

---

## 6. Monster Weapon Spawning

### GameConfig Additions

```gdscript
var monster_weapon_chance: float = 0.0         # 0.0-1.0
var monster_weapon_presets: Array[int] = [0, 1, 2, 3]
var monster_ranged_cooldown: float = 3.0
var monster_ranged_damage: int = 8
```

### Spawn Logic (generated_level.gd)

In `_spawn_monsters()`, after creating a monster, roll `randf() < Config.monster_weapon_chance`. If true:

1. Pick a random weapon index from `Config.monster_weapon_presets`
2. Get the weapon preset from `Config.weapon_presets[index]`
3. Add `C_Weapon` with the preset's stats
4. Add `C_WeaponVisual` with `weapon_index = index`, `element = preset.element`, `show_viewmodel = false`
5. Add `C_BossAI` with `ranged_cooldown = Config.monster_ranged_cooldown`, `projectile_damage = Config.monster_ranged_damage`
6. Set `C_MonsterAI.attack_range = 15.0` (so they shoot from distance instead of melee)

### Boss Integration

`setup_as_boss()` already adds `C_BossAI`. Additionally add `C_WeaponVisual` with `weapon_index = 0` (pistol shape) and the boss's element. The boss weapon visual is purely cosmetic — the boss's actual projectile stats come from `C_BossAI`.

### Monster Scene Changes

Add `WeaponMount` Marker3D to all 4 theme monster scenes:

| Scene | Mount Position |
|---|---|
| `themes/neon/monster_basic.tscn` | `Vector3(0.5, 0.4, -0.3)` — right side of box body |
| `themes/neon/monster_boss.tscn` | `Vector3(0.7, 0.6, -0.4)` — right side, higher for larger body |
| `themes/stone/monster_basic.tscn` | `Vector3(0.7, 0.2, -0.3)` — at right arm tip |
| `themes/stone/monster_boss.tscn` | `Vector3(0.9, 0.3, -0.4)` — at right arm tip, wider |

---

## 7. New Files

| File | Responsibility |
|---|---|
| `src/effects/weapon_model_factory.gd` | Static factory: viewmodel, world model, HUD icon creation |
| `src/components/c_weapon_visual.gd` | Component: tracks which weapon model to display |
| `src/systems/s_weapon_visual.gd` | System: spawns/updates weapon meshes, animations |

## 8. Modified Files

| File | Changes |
|---|---|
| `src/entities/player.gd` | Add C_WeaponVisual, update in _equip_weapon() and setup() |
| `src/entities/monster.gd` | Add C_WeaponVisual in setup_as_boss() |
| `src/levels/generated_level.gd` | Register S_WeaponVisual, arm monsters on spawn, muzzle point for projectiles |
| `src/config/game_config.gd` | Add monster_weapon_chance, monster_weapon_presets, monster_ranged_cooldown, monster_ranged_damage |
| `src/ui/hud.gd` | Replace weapon text with icon from factory |
| `themes/neon/monster_basic.tscn` | Add WeaponMount Marker3D |
| `themes/neon/monster_boss.tscn` | Add WeaponMount Marker3D |
| `themes/stone/monster_basic.tscn` | Add WeaponMount Marker3D |
| `themes/stone/monster_boss.tscn` | Add WeaponMount Marker3D |
