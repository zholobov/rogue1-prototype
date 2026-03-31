# Architecture Review — 2026-03-26

## TL;DR

The codebase is a well-structured prototype with strong foundations in ECS discipline, theming, and procedural generation. **The biggest risk to maintainability is `level_builder.gd` at 1,200+ lines** — it's the single file that must be edited for any new wall style, light source, or prop type. The config auto-discovery system and in-game editor are genuine playtesting superpowers. Mixed indentation (48 files use spaces, 10 use tabs) creates friction in every diff. Three test files are broken (calling a non-existent `setup_defaults()` method). `god_mode` defaults to `true` which will be accidentally shipped.

**Extensibility score: 7/10** — adding themes, systems, and UI screens is easy. Adding weapons is harder (6+ files). The generation pipeline is the bottleneck — all visual variety goes through one mega-file.

---

## 1. Project Structure

### Layout (Good)

```
src/
  components/     13 files — pure data, ECS-correct
  systems/        15 files — mostly focused, 2 misclassified (see below)
  entities/       3 files  — Player, Monster, Projectile
  levels/         2 files  — TestLevel (dead), GeneratedLevel
  generation/     4 files  — WFC + LevelGenerator + LevelBuilder + TileRules
  themes/         3 files  — ThemeData, ThemeGroup, ThemeManager
  effects/        5 files  — VFX, textures, floating numbers, weapon models
  ui/             17 files — all screens and HUD widgets
  run/            5 files  — RunManager, RunMap, RunStats, MetaSave, UpgradeData
  config/         3 files  — GameConfig, ElementRegistry, ConfigSectionBuilder
  events/         1 file   — DamageEvents
  networking/     2 files  — NetworkManager, SignalingClient
themes/           — 3 theme implementations (neon, stone, folk) with 17 monster .tscn scenes
test/unit/        16 test files
```

### Issues

- `src/themes/` (contracts) vs `themes/` (implementations) — confusing split, new devs look in two places
- `test_level.gd` — dead code, never referenced
- `s_projectile.gd` — dead code, never registered with ECS

---

## 2. Architecture Patterns

### ECS (GECS) — Strong

Components are **100% pure data**. Systems are mostly single-responsibility and small (16-28 lines typical). Adding a new system costs 1 file + 1 line in `generated_level.gd`. This is the best part of the architecture.

### ECS Issues

| Problem | Files | Impact |
|---------|-------|--------|
| `S_Damage` is a static utility, not a real system | `s_damage.gd` | Misleading architecture — has `process()` that does nothing |
| `S_Lifesteal` is event-driven, not query-driven | `s_lifesteal.gd` | Registered as system but never iterates entities |
| `S_Projectile` is dead code | `s_projectile.gd` | Never registered, projectile uses own `_physics_process` |
| `S_WeaponVisual` + `S_HpRegen` accumulate stale entity keys | Both | No cleanup on entity destruction, slow memory leak |
| Systems reach back to Godot nodes via `get_parent() is MonsterEntity` | 5 systems | Couples ECS to concrete class hierarchy |

### Movement Split

Velocity is set by `S_PlayerInput` → `C_Velocity`, then read by `PlayerEntity._physics_process()` for `move_and_slide()`. This works but depends on Godot's node processing order being stable. Same pattern for monsters via `S_MonsterAI` → `C_Velocity` → `MonsterEntity._physics_process()`.

### Autoloads — Clean

8 autoloads, each with a clear role. No god objects. Dependency direction is clean (systems → autoloads, not autoloads → each other). One fragile ordering dependency: `Elements._ready()` calls `ThemeManager.active_theme` — works only because `ThemeManager` is registered first in `project.godot`.

---

## 3. File Size Hotspots

| File | Lines | Assessment |
|------|-------|------------|
| `level_builder.gd` | ~1,230 | **Critical** — should split wall/prop/light builders into separate files |
| `hud.gd` | ~647 | Borderline — 9 sub-widgets in one file |
| `folk_theme.gd` | ~447 | Acceptable — data-only, expected size for 3 biomes |
| `weapon_model_factory.gd` | ~409 | Acceptable — mechanical, repetitive by design |
| `monster.gd` | ~270 | Health bar UI (80 lines) should be extracted |
| `generated_level.gd` | ~296 | Fine |

---

## 4. Code Quality

### Strengths

- Config auto-discovery via `@export_range` + reflection — eliminates manual UI sync
- Theme system with `ThemeGroup` → `ThemeData` hierarchy — clean data-driven design
- VFX material caching — proper fix for shader compilation spikes
- Per-frame player position caching in `S_MonsterAI` — eliminates O(n²) tree scans
- Damage number rate-limiting — smart accumulation per spatial bucket

### Problems

| Issue | Location | Severity |
|-------|----------|----------|
| Mixed indentation: 48 files use spaces, 10 use tabs | Project-wide | Medium |
| `god_mode` defaults to `true` | `game_config.gd:44` | High (will ship as god mode) |
| Kill reward calculated in 2 places independently | `run_manager.gd:92`, `s_death.gd:22` | Medium |
| 10+ debug `print()` statements in production code | `generated_level.gd` | Low |
| `UpgradeData._pool` is static mutable state | `upgrade_data.gd:12` | Low (test contamination) |
| `MetaSave` silently ignores save/load failures | `meta_save.gd` | Low |
| Duplicate `_find_in_group()` function | `level_generator.gd`, `generated_level.gd` | Low |

---

## 5. Extensibility Assessment

| Task | Difficulty | Files to Touch | Friction Point |
|------|-----------|----------------|----------------|
| Add new theme/biome | Low | 1 factory + scenes + 1 line in theme_manager | Verbose (447-line factory for 3 biomes) |
| Add new system | Very Low | 1 new file + 1 line in generated_level | None |
| Add new UI screen | Low | 1 new file + main.gd + RunManager state | Clean pattern |
| Add new monster type | Low | 1 .tscn + register in ThemeData | Limited to 3 variants (basic/v1/v2) |
| Add new weapon | Medium-High | **6+ files**: config, factory (3 funcs), crosshair, project.godot | No weapon registry abstraction |
| Add new wall style | Medium | level_builder.gd (1,200 lines) + ThemeData | Mega-file bottleneck |
| Add new modifier | Medium | run_manager.gd hardcoded switch | No modifier data abstraction |

### Key Bottleneck

`level_builder.gd` is the funnel for ALL visual variety. Every new wall style, light source, prop type, floor style, or ceiling beam style requires editing this one file. Splitting it into `WallBuilder`, `PropBuilder`, `LightBuilder` strategy classes dispatched by `wall_style` would dramatically improve extensibility.

---

## 6. Technical Debt

### Dead Code
- `s_projectile.gd` — never registered
- `test_level.gd` / `test_level.tscn` — never referenced
- `C_DamageDealer.hit_actors` field — declared, never used

### Broken Tests
- `test_level_builder.gd:8`, `test_tile_rules.gd:7`, `test_wfc_solver.gd:8` call `rules.setup_defaults()` which **does not exist**. These tests would fail at runtime.

### Missing Abstractions
- **Weapon Registry** — weapon data scattered across 6+ files
- **Modifier Data** — modifier effects hardcoded in `run_manager.gd`
- **Wall/Prop/Light Builders** — all inline in `level_builder.gd`

### Hardcoded Constants
- Monster variant roll: `0.25`, `0.5` in `generated_level.gd`
- Boss health: `500 + (250 * loop)` in `monster.gd`
- Shop heal cost: `50 + (25 * loop)` in `shop_screen.gd`

---

## 7. Testing

### Coverage Gaps

**Tested well:** Components, WFC solver, tile rules, theme data structure, weapon factory, config defaults.

**Not tested at all:**
- `S_Damage.apply_damage()` — the most critical game function
- `RunManager` state transitions
- `S_MonsterAI` behavior
- `MetaSave` round-trip
- HUD data binding
- Network flow

### Broken Tests
3 test files call `setup_defaults()` which was renamed/removed during refactoring. These tests are silently broken.

### No CI
No `.github/workflows/` or equivalent. Tests can only be run manually via GUT.

---

## 8. Recommendations (Prioritized)

### Immediate (before next feature)
1. **Fix 3 broken test files** — update `setup_defaults()` → `setup_profile("normal")`
2. **Set `god_mode = false`** as default
3. **Remove dead code**: `s_projectile.gd`, `test_level.gd`
4. **Remove debug prints** from `generated_level.gd`

### Short-term (next sprint)
5. **Split `level_builder.gd`** into `WallStyleBuilder`, `PropBuilder`, `LightSourceBuilder`
6. **Standardize indentation** to tabs (Godot convention)
7. **Extract health bar** from `MonsterEntity` into a system or separate node
8. **Add tests for `S_Damage.apply_damage()`**

### Medium-term (next milestone)
9. **Create Weapon Registry** — `WeaponDefinition` resource with mesh, crosshair, stats, icon
10. **Create Modifier Registry** — `ModifierData` resource instead of hardcoded switch
11. **Auto-discover themes** from filesystem instead of hardcoding in `_load_themes()`
12. **Add CI** with GUT test runner

### Long-term (architecture evolution)
13. **Replace pixel-by-pixel texture generation** with GPU compute or pre-baked resources
14. **Consolidate kill reward calculation** to single source of truth
15. **Add entity cleanup callbacks** to `S_WeaponVisual` and `S_HpRegen`
