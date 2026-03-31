# Multiplayer Design Spec

## Overview

Add working co-op multiplayer (with friendly fire) to the roguelite FPS prototype. Players connect via WebRTC peer-to-peer in a star topology, with one player acting as the authoritative host. A lightweight signaling server on Synology (behind Cloudflare tunnel) handles connection setup only — all game traffic flows directly between players.

## Architecture

### Network Topology: Star (Hub-and-Spoke)

- **Host** (peer 1) = lobby creator. Connects to all clients. Relays game traffic.
- **Clients** (peers 2–N) connect only to the host. No direct client-to-client connections.
- **Max players**: 10.
- **Transport**: WebRTC data channels (reliable for RPCs, unreliable for state sync).

Connections scale linearly: `n-1` total (host has `n-1` connections, each client has 1).

### Authority Model

| Domain | Authority | Rationale |
|--------|-----------|-----------|
| Player movement/rotation | Client (own player) | Responsive input, no wait for host |
| Weapon firing | Client initiates → host spawns projectile | Host controls projectile lifecycle |
| Projectiles (movement, collision) | Host | Consistent hit detection, friendly fire |
| Damage calculation | Host | Single source of truth for HP |
| Monster AI | Host | One simulation, no desync |
| Monster health/death | Host | Consistent kill tracking, loot |
| Conditions/elements | Host | Host applies and ticks, broadcasts changes |
| Run progression | Host | State transitions, level generation |
| Upgrades/shop | Each player picks own, host validates | Per-player progression |

### Sync Method: Hybrid (MultiplayerSynchronizer + RPC)

**MultiplayerSynchronizer** for continuous state:
- Player position, rotation (client-authoritative per player)
- Monster position, rotation, animation state (host-authoritative)
- Projectile position (host-authoritative)
- Player/monster health (host-authoritative)

**RPC** for discrete events:
- Weapon fire (client → host: position, direction, element, weapon stats)
- Damage dealt (host → all: target entity, amount, element)
- Entity death (host → all: entity ID, death type)
- Dash/AOE activation (client → host/all: position, direction)
- Condition applied/removed (host → all: target, condition type, duration)
- Level data (host → all: serialized grid, spawn points, monster placements)
- Run state transitions (host → all: new state + associated data)
- Upgrade/shop selections (client → host: chosen upgrade/purchase)
- Monster spawn (handled by MultiplayerSpawner)
- Projectile spawn (handled by MultiplayerSpawner)

**Tick rate**: Configurable at runtime, default 20/sec.

## Signaling Server

### Migration from fly.io to Synology

Replace `signaling_server/` contents. Remove `fly.toml`. Keep the existing WebSocket signaling protocol (join, offer, answer, candidate, peer_connected, peer_disconnected).

Changes to `server.js`:
- Default port: 3000 (matching Synology/Cloudflare setup).
- Add HTTP health-check endpoint alongside WebSocket (Cloudflare tunnel monitoring).
- Attach `WebSocket.Server` to the HTTP server instead of standalone.
- Enforce star topology: only relay SDP between host (first peer in lobby) and new clients. Non-host peers never receive each other's connection info.

Dockerfile:
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY server.js ./
EXPOSE 3000
CMD ["node", "server.js"]
```

Deployment:
```bash
cd signaling_server
docker build -t gameserver .
docker rm -f gameserver
docker run -d --name gameserver -p 3000:3000 gameserver
```

Client-side: `signaling_url` defaults to `wss://server.zholobov.org`, override to `ws://localhost:3000` for local dev.

## ECS System Changes

Each system's multiplayer behavior:

| System | Runs On | Sync Method | Change Required |
|--------|---------|-------------|-----------------|
| S_PlayerInput | Local client only | MultiplayerSynchronizer | Already checks `is_local`. No change to logic. Add synchronizer for position/rotation. |
| S_Movement | All clients (own player) | MultiplayerSynchronizer | No logic change. Player CharacterBody3D position auto-synced. |
| S_Weapon | Client fires → RPC to host | RPC | Client sends fire RPC. Host spawns authoritative projectile via MultiplayerSpawner. |
| S_Projectile | Host only | MultiplayerSynchronizer | Add host-only guard. Host moves projectiles, detects collisions. Clients render synced positions. |
| S_Damage | Host only | RPC | Add host-only guard. Host calculates damage, broadcasts damage RPC to all. |
| S_Death | Host only | RPC | Add host-only guard. Host detects health <= 0, broadcasts death event. |
| S_MonsterAI | Host only | MultiplayerSynchronizer | Add host-only guard. Monster positions synced to clients. |
| S_BossAI | Host only | MultiplayerSynchronizer | Same as S_MonsterAI. Boss attacks broadcast as RPCs. |
| S_Dash | Local client → RPC to all | RPC | Client activates locally, sends RPC for VFX on other clients. |
| S_AoEBlast | Client → RPC to host | RPC | Client sends activation + position. Host calculates hits (including friendly fire), broadcasts damage. |
| S_Conditions | Host only | RPC | Host applies/ticks conditions, broadcasts changes for VFX. |
| S_Lifesteal | Host only | (via health sync) | Host calculates heal on kill, updates health. |
| S_HpRegen | Host only | MultiplayerSynchronizer | Host ticks regen. Health synced as property. |
| S_Lifetime | Host only | (via MultiplayerSpawner) | Host removes expired entities. Auto-cleanup on clients. |
| S_WeaponVisual | All clients | — | Pure visual. Each client renders based on synced C_WeaponVisual state. |

The main code change pattern: systems that are host-only add an early return if the current peer is not the host (`if multiplayer.get_unique_id() != 1: return`). System logic itself stays the same.

## Entity Lifecycle

### Player

1. Client joins via signaling → WebRTC connection to host established.
2. Host creates PlayerEntity for the new peer under a MultiplayerSpawner node.
3. MultiplayerSpawner auto-replicates the scene on all clients.
4. `set_multiplayer_authority(peer_id)` gives the owning client authority over their player.
5. MultiplayerSynchronizer syncs position/rotation continuously.
6. On disconnect: host removes entity, MultiplayerSpawner auto-removes on all clients.

### Monster

1. Host spawns MonsterEntity under MultiplayerSpawner. Scene replicates to all clients.
2. `multiplayer_authority = 1` (host owns all monsters).
3. MultiplayerSynchronizer syncs position, rotation, animation state, health.
4. Host runs AI, detects attacks, calculates damage.
5. On death: host broadcasts death RPC (for VFX/loot), removes entity. Auto-cleanup on clients.

### Projectile

1. Client sends fire RPC to host (position, direction, element, weapon stats).
2. Client spawns a local-only predicted projectile for instant visual feedback.
3. Host creates authoritative ProjectileEntity under MultiplayerSpawner. Replicated to all clients.
4. Client removes predicted projectile when authoritative one arrives.
5. Host runs S_Projectile: moves projectile, detects collisions (monsters AND players for friendly fire).
6. On hit: host applies damage, broadcasts damage RPC, removes projectile.
7. On expire: S_Lifetime on host removes entity. Auto-cleanup on clients.

## Run Progression

RunManager runs on host only. All state transitions are host-initiated and broadcast via RPC.

| State | Multiplayer Behavior |
|-------|---------------------|
| LOBBY | Players connect via signaling. Host sees player list. Host starts run → RPC to all. |
| MAP | Host picks map node, broadcasts choice (node index, modifier, seed, biome) to all. All clients apply same config. |
| LEVEL / BOSS | Host generates level, serializes level data (grid, spawn points, monster placements), sends to all clients. Clients build level from data. Host spawns monsters/players via MultiplayerSpawner. |
| REWARD | Host generates upgrade options, sends to all. Each player picks own upgrade via RPC. Host waits for all players, then advances. |
| SHOP | Each player has own currency, shops independently. Host waits for all to finish, then advances to MAP. |
| VICTORY | Host broadcasts victory. All clients show victory screen with shared stats. |
| GAME OVER | Triggered when ALL players are dead. Host tracks alive count. Last death → game over RPC to all. |

### Player Death in Co-op

Dead players spectate (camera follows a living teammate). Run continues until all players are dead. Keeps everyone engaged.

### Disconnected Player During Reward/Shop

Host skips waiting for disconnected players and advances when remaining players are ready.

## NetworkManager Changes

| Current (Mesh) | New (Star) |
|-----------------|------------|
| All peers create WebRTC connections to all others | Clients connect only to host (peer 1) |
| Signaling relays SDP between all peer pairs | Signaling relays SDP only between host and each client |
| Every peer sends state to every other peer | Clients send to host, host relays to all |
| `signaling_url` = `ws://localhost:9090` | `signaling_url` = `wss://server.zholobov.org` (configurable) |
| Peer 1 assigned to first joiner | Peer 1 = lobby creator (host), enforced by signaling server |

## Connection Handling

| Scenario | Behavior |
|----------|----------|
| Client disconnects mid-level | Host removes player entity, broadcasts removal. Remaining players continue. |
| Host disconnects | Game ends for all. Clients show "Host disconnected" → return to main menu. |
| Join mid-run | Not supported. Players join during LOBBY only. Lobby sealed on run start. |
| Reconnect after disconnect | Not supported. Disconnected player removed permanently. Rejoin next run. |
| Solo mode | `is_solo` flag skips networking. Host runs everything locally. Zero networking overhead. |

## Interpolation & Smoothing

- **Remote players**: MultiplayerSynchronizer provides built-in interpolation. No custom code needed.
- **Monsters**: Same as remote players — host-owned, interpolated on clients.
- **Projectiles**: Basic interpolation. Client-side predicted projectile hides latency for the shooter.

## Out of Scope (Prototype)

- **Host migration** — if host drops, game ends.
- **Mid-run join / reconnect** — lobby only.
- **Server-side validation / anti-cheat** — trusting clients (co-op, not competitive).
- **Rollback / server reconciliation** — overkill for co-op PvE.
- **NAT traversal TURN relay** — rely on STUN. If WebRTC can't connect, players can't play together.

## Godot Nodes Used

- **MultiplayerSpawner**: Added to level scene. Configured with spawn paths for PlayerEntity, MonsterEntity, ProjectileEntity. Auto-replicates spawns/removals across all clients.
- **MultiplayerSynchronizer**: One per entity. Configured with properties to sync (position, rotation, health, animation state). Authority matches entity's `multiplayer_authority`.
