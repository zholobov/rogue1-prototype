# Game Loop & Progression — Design Spec

## Goal

Add a complete roguelite game loop: branching map, level progression, upgrades, shop, boss fights, victory/death screens, and persistent meta-progression.

## Scope

This spec covers **solo mode only**. Multiplayer synchronization of run state, upgrade picks, and shop purchases is deferred to a future spec. The existing multiplayer lobby and networking code remain unchanged but are not integrated with the run loop.

## Architecture

New **RunManager** autoload singleton owns all run state and drives transitions via signals. Main.gd listens to signals to swap scenes/UI. RunManager never touches nodes directly.

---

## 1. RunManager & State Machine

### States

| State | Description |
|-------|-------------|
| LOBBY | Waiting to start, show meta-upgrades |
| MAP | Branching map, player picks next level |
| LEVEL | Playing a generated level |
| REWARD | Pick 1 of 3 random upgrades (after every level) |
| SHOP | Spend currency on upgrades/healing (every N levels) |
| BOSS | Boss level |
| VICTORY | Beat the boss, option to continue or end |
| GAME_OVER | Death — stats + meta-currency earned |

### Run State

```
current_depth: int          # current position on the map (0-indexed)
boss_depth: int             # configurable via GameConfig, default 4
currency: int               # earned from kills, spent in shop
meta_currency_earned: int   # meta-currency earned this run (10% of currency)
active_upgrades: Array[UpgradeData]
stats: RunStats             # kills, damage_dealt, time, levels_cleared, loop
map: RunMap                 # branching map data
loop: int                   # 0 = first, 1+ = post-boss harder loops
```

### Transitions

```
LOBBY → MAP → LEVEL → REWARD → [SHOP every 2 levels] → MAP → ... → BOSS → VICTORY
                                                                         ↓
VICTORY → MAP (loop+1, harder) OR → GAME_OVER (collect meta-currency)
Any LEVEL/BOSS state → GAME_OVER (on player death)
```

### Signals

- `state_changed(new_state: int)` — Main.gd listens to swap scenes/UI
- `run_started()` — reset run state, generate map
- `run_ended(stats: RunStats)` — trigger meta-currency save
- `currency_changed(amount: int)` — UI updates
- `kill_registered(entity: Entity)` — fired when a monster dies, for stats/currency tracking

### RunStats

```
kills: int = 0
damage_dealt: int = 0
time_elapsed: float = 0.0
levels_cleared: int = 0
loop: int = 0
took_damage_this_level: bool = false   # reset per level, set by S_Damage
total_currency_earned: int = 0
```

---

## 2. Branching Map

### Data Structure

**RunMap**: Array of layers (depth 0 to boss_depth).

**MapNode**:
```
level_seed: int
modifier: String        # "normal", "dense", "large", "dark", "horde"
connections: Array[int] # indices into next layer's nodes
visited: bool
```

### Generation Rules

- On run start, generate full map upfront
- Each layer has 2-3 MapNode entries (randomized)
- Final layer is always 1 boss node
- Each node connects to 1-2 nodes in the next layer
- Every node in each layer must be reachable from at least one node in the previous layer (no dead ends)
- Each node gets a random seed and a weighted-random modifier

### Modifiers

| Modifier | Effect |
|----------|--------|
| normal | No changes |
| dense | 2x monster count |
| large | 16x16 grid (instead of 12x12) |
| dark | Reduced OmniLight range (halved) |
| horde | 3x monster count, monsters have 50% HP |

### Map UI

- 2D screen: nodes as buttons in columns (one column per depth)
- Lines drawn between connected nodes
- Visited nodes highlighted, current depth's choices selectable
- Modifier label shown on each node
- Player clicks a node to begin that level

---

## 3. Upgrades

### UpgradeData Resource

```
name: String
description: String
category: String        # "stat", "weapon", "defensive", "special"
rarity: String          # "common", "rare", "epic"
property: String        # which stat to modify
value: float            # amount
icon: String            # for display (text-based for prototype)
cost: int               # shop price (0 = reward-only)
```

### Upgrade Pool

**Stat boosts (common):**
- +20 max HP
- +15% move speed
- +10% damage

**Weapon (common/rare):**
- +20% fire rate
- +25% projectile speed
- Add fire/ice/water element to non-elemental weapon

**Defensive (common/rare):**
- +2 HP regen per second
- -15% damage taken
- -30% condition duration

**Special abilities (rare/epic):**
- Dash — short burst of speed, 3s cooldown
- AoE blast — damage in radius around player, 8s cooldown
- Lifesteal — heal 10% of killed monster's max HP

### Rarity Weights

- Loop 0: common 70%, rare 25%, epic 5%
- Loop 1+: common 50%, rare 35%, epic 15%

### Stacking

Upgrades stack additively. Two "+20 max HP" = +40 max HP. Two "+10% damage" = +20% damage. Two "-30% condition duration" = -60% (i.e. `condition_duration_mult = 0.4`). The reduction is tracked as an additive sum, then converted: `condition_duration_mult = 1.0 - total_reduction`.

---

## 4. Reward Screen

- Shown after every level clear (including boss)
- Displays 3 random upgrades from the pool
- Player picks 1; other 2 discarded
- Upgrade immediately applied to run state
- Simple UI: 3 panels side by side with name, description, rarity color

---

## 5. Shop Screen

- Shown when `current_depth > 0 && current_depth % shop_frequency == 0` (i.e. after levels 2, 4, 6... with default shop_frequency=2)
- 4-5 upgrades for sale at currency prices
- "Heal to full" option — costs 50 currency (scales with loop)
- "Reroll" button — costs 25 currency, increases by 25 each use per shop visit
- Prices: common 30, rare 60, epic 120 (scale 1.5x per loop)
- Player can buy multiple or skip ("Continue" button)

---

## 6. Currency

### Run Currency

- Per kill: base 10 (scales with monster HP: `kill_reward = max(10, monster_max_hp / 10)`)
- Level clear bonus: +50
- No-damage bonus: +30 (if `RunStats.took_damage_this_level == false`; flag set by S_Damage when player takes damage)

### Meta-Currency

- At run end: `meta_currency_earned = total_currency_earned * 0.1` (floored)
- Persisted to save file

---

## 7. Victory Condition & Boss

### Level Completion

- GeneratedLevel tracks `monsters_remaining: int` (set at spawn time)
- GeneratedLevel stores a reference to the S_Death system instance when creating it (like existing `weapon_system` pattern)
- Connects to `S_Death.actor_died` signal to decrement `monsters_remaining`
- When `monsters_remaining == 0` → emit `level_cleared` signal
- RunManager listens to `level_cleared` → transition to REWARD

### Boss Level

- WFC generation with overridden tile weights: room=10.0, corridor=0.1, wall=0.5, empty=0.01 (forces large open area; empty near-zero but nonzero to avoid division issues in WFCSolver)
- Single boss entity spawned (no regular monsters)
- Boss stats (base, scale with loop):
  - HP: 500 (+250 per loop)
  - Damage: 20 (+10 per loop)
  - Move speed: 4.0
  - Detection range: 30.0
  - Attack range: 3.0
  - Attack cooldown: 0.8s
- Boss visual: 2x scaled monster mesh, red-tinted material
- Boss has ranged attack: fires projectiles at player every 2s (alternates with melee)
- On boss death → VICTORY state

### Loop Scaling (loop 1+)

- Monster HP: +50% per loop
- Monster damage: +25% per loop
- Upgrade rarity odds improve (see Section 3)

---

## 8. Game Over & Victory Screens

### Game Over Screen

Shown when player HP reaches 0 (and god mode is off).

Displays:
- Levels cleared
- Monsters killed
- Damage dealt
- Time survived
- Loop reached
- Upgrades collected (list)
- Meta-currency earned this run

Button: "Return to Lobby"

### Victory Screen

Shown when boss is defeated.

Displays:
- Same stats as game over
- "Boss Defeated!" header

Buttons:
- "Continue" — start loop+1 with current upgrades, generate new map
- "End Run" — collect meta-currency, return to lobby

---

## 9. Meta-Progression

### Save File

`user://meta_save.json`:
```json
{
  "meta_currency": 500,
  "best_loop": 2,
  "best_depth": 4,
  "total_kills": 347,
  "unlocks": {
    "hp_1": true,
    "hp_2": false,
    "damage_1": true
  }
}
```

### Permanent Upgrades (Lobby)

| Upgrade | Cost | Stackable | Effect |
|---------|------|-----------|--------|
| Tough I/II/III | 100/200/400 | 3x | +10 starting max HP each |
| Strong I/II/III | 100/200/400 | 3x | +5% starting damage each |
| Head Start I/II/III | 150/300/600 | 3x | Start run with 1/2/3 random upgrades |
| Arsenal | 500 | 1x | Unlock 5th weapon slot (requires new `weapon_5` input action on key 5, and a 5th weapon preset in Config) |

### Lobby Integration

- Meta-currency balance shown on lobby screen
- "Upgrades" button opens permanent upgrade list
- Best run stats displayed (loop + depth)

---

## 10. New Components

### C_PlayerStats

Derived modifier component added to player entity at level start. Recalculated when upgrades change.

```
max_health_bonus: int = 0
damage_mult: float = 1.0
speed_mult: float = 1.0
damage_reduction: float = 0.0
hp_regen: float = 0.0
condition_duration_mult: float = 1.0
```

### C_Dash (added when upgrade acquired)

```
cooldown: float = 3.0
cooldown_remaining: float = 0.0
dash_speed: float = 20.0
dash_duration: float = 0.15
```

### C_AoEBlast (added when upgrade acquired)

```
cooldown: float = 8.0
cooldown_remaining: float = 0.0
damage: int = 30
radius: float = 5.0
```

### C_Lifesteal (added when upgrade acquired)

```
percent: float = 0.1  # heal 10% of kill's max HP
```

### C_BossAI (extends or replaces C_MonsterAI for boss)

```
ranged_cooldown: float = 2.0
ranged_cooldown_remaining: float = 0.0
projectile_damage: int = 15
projectile_speed: float = 20.0
```

---

## 11. New Systems

- **S_HpRegen** — ticks HP regen from C_PlayerStats.hp_regen, adds to C_Health each frame
- **S_Dash** — handles `dash` input action (Shift key), cooldown, applies velocity burst for dash_duration
- **S_AoEBlast** — handles `aoe_blast` input action (Q key), cooldown, deals damage to all monsters within radius
- **S_Lifesteal** — listens to S_Death.actor_died, if killer has C_Lifesteal, heals by percent of victim's max HP
- **S_BossAI** — boss attack patterns: alternates melee (via C_MonsterAI) and ranged (fires projectile every ranged_cooldown)

### Integration Points for C_PlayerStats

C_PlayerStats modifiers are read on-demand by existing systems rather than applied by a dedicated system:

- **S_Damage.apply_damage()** — reads `target.C_PlayerStats.damage_reduction` to reduce incoming damage; reads `attacker.C_PlayerStats.damage_mult` (passed as parameter) to scale outgoing damage. Also sets `RunManager.stats.took_damage_this_level = true` when player takes damage.
- **S_PlayerInput** — reads `C_PlayerStats.speed_mult` and multiplies into `C_Velocity.speed` when setting movement velocity
- **S_Conditions** — reads `C_PlayerStats.condition_duration_mult` and applies when adding new conditions
- **Player.gd** — on level start, reads `RunManager.active_upgrades` and recalculates `C_PlayerStats` fields. Also sets `C_Health.max_health = Config.player_max_health + C_PlayerStats.max_health_bonus`

### Input Actions (add to project.godot)

- `dash` — Shift key
- `aoe_blast` — Q key

---

## 12. Modified Existing Files

- **Main.gd** — listen to RunManager.state_changed, swap scenes/UI accordingly
- **GeneratedLevel.gd** — accept seed/modifier from RunManager (RunManager sets Config values before level instantiation: `Config.level_seed`, `Config.level_grid_width`, `Config.level_grid_height`, `Config.monsters_per_room`; modifier "dark" sets a new `Config.light_range_mult`), track monsters_remaining, emit level_cleared
- **GameConfig** — add `boss_depth: int = 4`, `shop_frequency: int = 2`, `kill_reward_base: int = 10`, `meta_currency_rate: float = 0.1`, `light_range_mult: float = 1.0` settings
- **S_Damage** — read C_PlayerStats.damage_mult for outgoing damage, C_PlayerStats.damage_reduction for incoming, set RunStats.took_damage_this_level
- **S_Death** — emit signal with entity info (including C_Health.max_health for currency calculation)
- **S_PlayerInput** — read C_PlayerStats.speed_mult when setting velocity
- **S_Conditions** — read C_PlayerStats.condition_duration_mult when adding conditions
- **Player.gd** — add C_PlayerStats component, apply upgrades on level start
- **LobbyUI** — add meta-currency display and permanent upgrades button

---

## 13. New UI Scenes

- **MapScreen** (src/ui/map_screen.tscn) — branching map with node buttons
- **RewardScreen** (src/ui/reward_screen.tscn) — 3 upgrade panels
- **ShopScreen** (src/ui/shop_screen.tscn) — upgrade shop with buy/heal/reroll
- **GameOverScreen** (src/ui/game_over_screen.tscn) — stats + return to lobby
- **VictoryScreen** (src/ui/victory_screen.tscn) — stats + continue/end buttons
- **MetaUpgradesScreen** (src/ui/meta_upgrades_screen.tscn) — permanent upgrade shop in lobby
