# Rogue1 Prototype — Game Specification

## Overview

A modern 3D first-person roguelite prototype built in Godot 4. Designed for rapid iteration and playtesting — nearly every parameter and mechanic is configurable at runtime. Inspired by Gunfire Reborn and similar titles.

## Players

- 1–4 players per session (singleplayer or coop)
- Bot support for empty slots
- One player acts as authoritative host

## Core Loop

```
Hub → Select Character → Run (N levels) → Inter-level → Boss Level → Rewards → Hub
```

1. **Hub** — persistent space containing unlocked characters, global upgrades, unlockables
2. **Character Select** — player picks a character from the hub roster
3. **Run** — sequence of small levels, each with goals (initially: kill all monsters)
4. **Inter-level** — between levels, players upgrade/shop/prepare
5. **Boss Level** — final level with a stronger boss encounter
6. **Rewards** — earned on run completion, used for global character upgrades and hub unlocks

All run parameters (level count, difficulty curve, reward amounts) are configurable.

## Actors

All players and monsters are "actors" sharing the same system. Actors have:
- Health, stats, elemental affinities
- Conditions (status effects with duration)
- Weapons, spells, and skills

## Elemental System

Core combat differentiator. Combinatorial condition system where elements interact.

### Elements

Applied via weapons, spells, skills, and environment. Examples: fire, ice, water, oil. The set of elements is configurable.

### Conditions

- Applied to actors with a configurable duration
- Can combine: wet + freeze → frozen (immobilized), oily + fire → burning
- Stacking/refresh behavior (reset, extend, intensify) is a **runtime-configurable option** for playtesting
- Non-elemental damage and conditions also exist

### Environment Interactions

- Environment objects and surfaces carry/produce elements (water puddles, oil barrels)
- Biomes have elemental affinity (desert = hot, swamp = wet)
- Destructible objects release elements (broken oil barrel → oil puddle)
- Environment reacts to elements (fireball on oil puddle → burning puddle)
- Actors entering affected environment gain conditions (step in burning oil → burning + oily)

## Procedural Generation

Everything is generated. Pre-designed content is optional, not required.

### Level Generation

- Primary generator: **Wave Function Collapse** operating on rules/constraints
- WFC generates geometry natively without requiring pre-made content
- Pre-made chunks can optionally be fed to the generator as input
- Generator system is swappable — multiple generator implementations can coexist
- Deterministic via **seed** — same seed produces same output for reproducible runs and daily challenges

### Visual Generation

- Textures and visual assets are procedurally generated or minimalistic
- No dependency on hand-made art for v1
- The game must look acceptable with fully generated graphics

### Other Generation

Monsters, items, upgrades, and run structure are all generated (details TBD).

## Architecture

### ECS

Game logic uses **GECS** (GDScript ECS framework). Entities are Godot Nodes, Components are Resources, Systems are autoloaded scripts. Chosen for:
- Rapid add/remove/change of game mechanics
- Clean separation of data and behavior
- Pure GDScript — works in web exports

### Networking

**WebRTC** peer-to-peer via `WebRTCMultiplayerPeer`.

| Component | Implementation | Cost |
|-----------|---------------|------|
| Game traffic | WebRTC P2P (mesh, up to 4 players) | Free |
| Signaling | Node.js server on fly.io ([gd-webrtc-signalling](https://github.com/Faless/gd-webrtc-signalling)) | fly.io free tier |
| NAT traversal (STUN) | Google public STUN servers | Free |
| Relay fallback (TURN) | Open Relay or Cloudflare Calls free tier | Free |

- One player is the authoritative host
- fly.io server only handles room/lobby creation and connection setup — idle during gameplay
- Network layer is abstracted via Godot's `MultiplayerPeer` interface — transport is swappable without changing game code

### Migration Path

- Browser: WebRTC (built-in to browser + Godot web export)
- Desktop: WebRTC via `webrtc-native` GDExtension (same code)
- Steam (future): swap to GodotSteam `MultiplayerPeer` — one-line change
- ENet (future): swap to `ENetMultiplayerPeer` for direct/LAN play

### Rendering

- Web exports use Compatibility renderer (WebGL 2.0)
- Desktop can use Forward+ or Compatibility
- Visual fidelity constrained by procedural/minimalistic art direction, not renderer

## Configurability

This is a prototype for playtesting. The following principle applies everywhere:

> If in doubt whether something should be a variable or hardcoded — make it a variable.

Runtime-configurable parameters include (but are not limited to):
- Element definitions and interaction rules
- Condition durations, stacking behavior, combination results
- Run structure (level count, difficulty scaling)
- Generation parameters (seeds, WFC rules, chunk usage)
- Actor stats, weapon properties, skill values
- Reward and progression rates

## Future (v2+)

- Partial level destructibility / visual damage on hit
- Additional network backends
- Expanded art generation pipeline
