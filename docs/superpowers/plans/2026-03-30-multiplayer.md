# Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add working co-op multiplayer (with friendly fire) to the roguelite FPS prototype — up to 10 players, host-authoritative, P2P WebRTC.

**Architecture:** Star authority model on WebRTC mesh transport. The host (peer 1) is authoritative for monsters, damage, death, conditions, and run progression. Clients are authoritative for their own movement. Godot's `MultiplayerSynchronizer` handles continuous state sync (position, rotation, health); `@rpc` handles discrete events (fire, damage, death). WebRTC mesh is kept at the transport level for compatibility with Godot's multiplayer nodes. The signaling server on Synology (behind Cloudflare tunnel at `wss://server.zholobov.org`) handles connection setup only.

**Tech Stack:** Godot 4.x (GDScript), GECS (ECS addon), Node.js + ws (signaling server), Docker, WebRTC

**Spec:** `docs/superpowers/specs/2026-03-30-multiplayer-design.md`

---

### Task 1: Migrate Signaling Server

**Files:**
- Modify: `signaling_server/server.js`
- Modify: `signaling_server/Dockerfile`
- Modify: `signaling_server/package.json`
- Delete: `signaling_server/fly.toml`

- [ ] **Step 1: Delete fly.toml**

```bash
rm signaling_server/fly.toml
```

- [ ] **Step 2: Update server.js — add HTTP health check, change port to 3000**

Replace `signaling_server/server.js` with:

```javascript
const http = require("http");
const WebSocket = require("ws");

const PORT = process.env.PORT || 3000;

// HTTP health-check for Cloudflare tunnel monitoring
const httpServer = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("ok");
});

const wss = new WebSocket.Server({ server: httpServer });

// lobby_id -> Map<peer_id, WebSocket>
const lobbies = new Map();
let nextPeerId = 1;

wss.on("connection", (ws) => {
  let myPeerId = null;
  let myLobby = null;

  ws.on("message", (data) => {
    let msg;
    try {
      msg = JSON.parse(data);
    } catch {
      return;
    }

    if (msg.type === "join") {
      const lobbyId = msg.lobby || "default";
      myPeerId = nextPeerId++;
      myLobby = lobbyId;

      if (!lobbies.has(lobbyId)) {
        lobbies.set(lobbyId, new Map());
      }
      const lobby = lobbies.get(lobbyId);

      // Notify existing peers about new peer
      for (const [peerId, peerWs] of lobby) {
        send(peerWs, { type: "peer_connected", peer_id: myPeerId });
        send(ws, { type: "peer_connected", peer_id: peerId });
      }

      lobby.set(myPeerId, ws);
      send(ws, { type: "joined", peer_id: myPeerId });
      console.log(`Peer ${myPeerId} joined lobby ${lobbyId} (${lobby.size} peers)`);
      return;
    }

    // Relay messages to target peer
    if (msg.peer_id != null && myLobby) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        const targetWs = lobby.get(msg.peer_id);
        if (targetWs) {
          msg.peer_id = myPeerId; // Replace with sender's ID
          send(targetWs, msg);
        }
      }
    }
  });

  ws.on("close", () => {
    if (myLobby && myPeerId != null) {
      const lobby = lobbies.get(myLobby);
      if (lobby) {
        lobby.delete(myPeerId);
        for (const [, peerWs] of lobby) {
          send(peerWs, { type: "peer_disconnected", peer_id: myPeerId });
        }
        if (lobby.size === 0) {
          lobbies.delete(myLobby);
        }
        console.log(`Peer ${myPeerId} left lobby ${myLobby}`);
      }
    }
  });
});

function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

httpServer.listen(PORT, () => {
  console.log(`Signaling server listening on port ${PORT}`);
});
```

- [ ] **Step 3: Update Dockerfile — expose port 3000**

Replace `signaling_server/Dockerfile` with:

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY server.js ./
EXPOSE 3000
CMD ["node", "server.js"]
```

- [ ] **Step 4: Test locally**

```bash
cd signaling_server && node server.js
```

In another terminal:
```bash
# Test HTTP health check
curl http://localhost:3000
# Expected: "ok"

# Test WebSocket (requires wscat: npm install -g wscat)
wscat -c ws://localhost:3000
> {"type":"join","lobby":"test"}
# Expected: {"type":"joined","peer_id":1}
```

Kill the server after testing.

- [ ] **Step 5: Commit**

```bash
git add signaling_server/
git rm signaling_server/fly.toml
git commit -m "refactor: migrate signaling server to port 3000 with HTTP health check"
```

---

### Task 2: Update Network Config

**Files:**
- Modify: `src/networking/network_manager.gd:10`
- Modify: `src/config/game_config.gd` (max_players line)

- [ ] **Step 1: Update signaling URL default**

In `src/networking/network_manager.gd`, change line 10:

```gdscript
@export var signaling_url: String = "wss://server.zholobov.org"
```

- [ ] **Step 2: Update max_players to 10**

In `src/config/game_config.gd`, change `max_players`:

```gdscript
@export var max_players: int = 10
```

- [ ] **Step 3: Add host helper properties to NetworkManager**

In `src/networking/network_manager.gd`, add after the `my_peer_id` declaration (line 18):

```gdscript
var is_host: bool:
	get: return my_peer_id == 1

var is_active: bool:
	get: return multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 0
```

- [ ] **Step 4: Commit**

```bash
git add src/networking/network_manager.gd src/config/game_config.gd
git commit -m "feat: update signaling URL to server.zholobov.org, max players to 10, add host helpers"
```

---

### Task 3: Add MultiplayerSynchronizer to Player Entity

**Files:**
- Modify: `src/entities/player.gd`

- [ ] **Step 1: Add MultiplayerSynchronizer in _ready()**

In `src/entities/player.gd`, add at the end of `_ready()` (after `add_to_group("players")`):

```gdscript
	# Multiplayer sync: position and rotation
	var sync = MultiplayerSynchronizer.new()
	sync.name = "PlayerSync"
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	sync.replication_config = config
	sync.replication_interval = 1.0 / 20.0  # 20 ticks/sec default
	add_child(sync)
```

- [ ] **Step 2: Update _physics_process to skip remote players**

The current `_physics_process` already returns early for non-local players (line 98-99). Verify this is correct — remote player positions come from the synchronizer, so `move_and_slide()` must NOT run for them. The existing guard is sufficient:

```gdscript
func _physics_process(delta: float) -> void:
	var net_id := get_component(C_NetworkIdentity) as C_NetworkIdentity
	if not net_id.is_local:
		return
	# ... rest unchanged ...
```

No change needed — the guard already exists.

- [ ] **Step 3: Commit**

```bash
git add src/entities/player.gd
git commit -m "feat: add MultiplayerSynchronizer to PlayerEntity for position/rotation sync"
```

---

### Task 4: Add MultiplayerSynchronizer to Monster Entity

**Files:**
- Modify: `src/entities/monster.gd`

- [ ] **Step 1: Add MultiplayerSynchronizer in _ready()**

In `src/entities/monster.gd`, add at the end of `_ready()` (after `add_to_group("monsters")`):

```gdscript
	# Multiplayer sync: position, rotation, health (host-authoritative)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MonsterSync"
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	sync.replication_config = config
	sync.replication_interval = 1.0 / 20.0
	add_child(sync)
```

- [ ] **Step 2: Gate _physics_process for host only**

In `src/entities/monster.gd`, update `_physics_process()` (line 177):

```gdscript
func _physics_process(delta: float) -> void:
	# Only host runs monster physics — clients get position from sync
	if Net.is_active and not Net.is_host:
		return

	var vel_comp := ecs_entity.get_component(C_Velocity) as C_Velocity

	if not is_on_floor():
		velocity.y -= Config.gravity * delta

	velocity.x = vel_comp.direction.x * vel_comp.speed
	velocity.z = vel_comp.direction.z * vel_comp.speed

	move_and_slide()
```

- [ ] **Step 3: Commit**

```bash
git add src/entities/monster.gd
git commit -m "feat: add MultiplayerSynchronizer to MonsterEntity, gate physics to host"
```

---

### Task 5: Add MultiplayerSynchronizer to Projectile Entity

**Files:**
- Modify: `src/entities/projectile.gd`

- [ ] **Step 1: Add MultiplayerSynchronizer and gate physics to host**

In `src/entities/projectile.gd`, add at the end of `_ready()` (after `body_entered.connect(_on_body_entered)`):

```gdscript
	# Multiplayer sync: position (host-authoritative)
	var sync = MultiplayerSynchronizer.new()
	sync.name = "ProjectileSync"
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	sync.replication_config = config
	sync.replication_interval = 1.0 / 20.0
	add_child(sync)
```

- [ ] **Step 2: Gate _physics_process and _on_body_entered to host**

Update `_physics_process()` (line 37):

```gdscript
func _physics_process(delta: float) -> void:
	if Net.is_active and not Net.is_host:
		return
	var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
	position += proj.direction * proj.speed * delta
```

Update `_on_body_entered()` (line 41):

```gdscript
func _on_body_entered(body: Node) -> void:
	# Only host processes collisions
	if Net.is_active and not Net.is_host:
		return

	var proj := ecs_entity.get_component(C_Projectile) as C_Projectile
	# Spawn impact particles at collision point
	var impact = VfxFactory.create_impact(global_position, proj.direction, proj.element)
	get_tree().current_scene.add_child(impact)

	if body is CharacterBody3D and body.has_method("get_component"):
		if body.get_instance_id() != proj.owner_id:
			S_Damage.apply_damage(body.ecs_entity, proj.damage, proj.element)
	queue_free()
```

- [ ] **Step 3: Commit**

```bash
git add src/entities/projectile.gd
git commit -m "feat: add MultiplayerSynchronizer to ProjectileEntity, gate physics/collision to host"
```

---

### Task 6: Add MultiplayerSpawner to Level and Rework Player Spawning

**Files:**
- Modify: `src/levels/generated_level.gd`
- Modify: `src/main.gd`

- [ ] **Step 1: Add container nodes and MultiplayerSpawner in generated_level.gd**

In `src/levels/generated_level.gd`, add new variables after the existing ones (after line 14):

```gdscript
var _player_container: Node3D
var _monster_container: Node3D
var _projectile_container: Node3D
var _player_spawner: MultiplayerSpawner
```

In `_ready()`, add right after the ECS world creation block (after `ECS.world = world`, around line 56):

```gdscript
	# Multiplayer: create entity containers and spawners
	_player_container = Node3D.new()
	_player_container.name = "Players"
	add_child(_player_container)

	_monster_container = Node3D.new()
	_monster_container.name = "Monsters"
	add_child(_monster_container)

	_projectile_container = Node3D.new()
	_projectile_container.name = "Projectiles"
	add_child(_projectile_container)

	_player_spawner = MultiplayerSpawner.new()
	_player_spawner.name = "PlayerSpawner"
	_player_spawner.spawn_path = NodePath("../Players")
	_player_spawner.add_spawnable_scene(PlayerScene.resource_path)
	add_child(_player_spawner)

	var monster_spawner = MultiplayerSpawner.new()
	monster_spawner.name = "MonsterSpawner"
	monster_spawner.spawn_path = NodePath("../Monsters")
	monster_spawner.add_spawnable_scene(MonsterScene.resource_path)
	add_child(monster_spawner)

	var projectile_spawner = MultiplayerSpawner.new()
	projectile_spawner.name = "ProjectileSpawner"
	projectile_spawner.spawn_path = NodePath("../Projectiles")
	projectile_spawner.add_spawnable_scene(ProjectileScene.resource_path)
	add_child(projectile_spawner)
```

Also add `PlayerScene` as a preload at the top of the file (after line 3):

```gdscript
const PlayerScene = preload("res://src/entities/player.tscn")
```

- [ ] **Step 2: Move monster spawning to use container**

In `_spawn_monsters()`, change `add_child(monster)` (line 152) to:

```gdscript
				_monster_container.add_child(monster)
```

In `_spawn_boss()`, change `add_child(boss)` (line 185) to:

```gdscript
	_monster_container.add_child(boss)
```

- [ ] **Step 3: Move projectile spawning to use container**

In `_on_projectile_requested()`, change `add_child(projectile)` (line 215) to:

```gdscript
	_projectile_container.add_child(projectile)
```

In `_on_boss_projectile_requested()`, change `add_child(projectile)` (line 231) to:

```gdscript
	_projectile_container.add_child(projectile)
```

- [ ] **Step 4: Gate monster/projectile spawning to host only**

In `_spawn_monsters()`, add at the top of the method:

```gdscript
func _spawn_monsters() -> void:
	if Net.is_active and not Net.is_host:
		return
	monsters_remaining = 0
	# ... rest unchanged ...
```

In `_spawn_boss()`, add at the top:

```gdscript
func _spawn_boss() -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

In `_on_projectile_requested()`, add at the top:

```gdscript
func _on_projectile_requested(owner_body: Node3D, weapon: C_Weapon) -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

In `_on_boss_projectile_requested()`, add at the top:

```gdscript
func _on_boss_projectile_requested(pos: Vector3, direction: Vector3, damage: int, speed: float, owner_id: int) -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

- [ ] **Step 5: Add a spawn_player method to generated_level.gd**

Add a new public method:

```gdscript
func spawn_player(peer_id: int, is_local: bool) -> void:
	var player = PlayerScene.instantiate()
	player.name = "Player_%d" % peer_id

	var spawn_pos = get_player_spawn()
	player.position = spawn_pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))

	_player_container.add_child(player)
	player.setup(peer_id, is_local)
	player.apply_upgrades()
```

- [ ] **Step 6: Update main.gd to use level's spawn_player**

In `src/main.gd`, replace the `_start_level()` method (lines 97-107):

```gdscript
func _start_level() -> void:
	var level = GeneratedLevel.instantiate()
	add_child(level)
	current_scene = level

	if is_solo:
		level.spawn_player(1, true)
	else:
		level.spawn_player(Net.my_peer_id, true)
		for peer_id in Net.peers:
			level.spawn_player(peer_id, false)
```

Remove the `_spawn_player()` method (lines 109-120) since it's now in `generated_level.gd`.

- [ ] **Step 7: Commit**

```bash
git add src/levels/generated_level.gd src/main.gd
git commit -m "feat: add MultiplayerSpawner containers for players, monsters, projectiles"
```

---

### Task 7: Add Host-Only Guards to ECS Systems

**Files:**
- Modify: `src/systems/s_monster_ai.gd`
- Modify: `src/systems/s_boss_ai.gd`
- Modify: `src/systems/s_conditions.gd`
- Modify: `src/systems/s_lifetime.gd`
- Modify: `src/systems/s_hp_regen.gd`

These systems must only run on the host. Clients receive results via sync.

- [ ] **Step 1: Guard S_MonsterAI**

In `src/systems/s_monster_ai.gd`, add at the top of `process()` (line 11):

```gdscript
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if Net.is_active and not Net.is_host:
		return
	# Cache player positions ONCE per frame
	# ... rest unchanged ...
```

- [ ] **Step 2: Guard S_BossAI**

Read `src/systems/s_boss_ai.gd` and add the same guard at the top of its `process()` method:

```gdscript
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

- [ ] **Step 3: Guard S_Conditions**

In `src/systems/s_conditions.gd`, add at the top of `process()`:

```gdscript
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

- [ ] **Step 4: Guard S_Lifetime**

In `src/systems/s_lifetime.gd`, add at the top of `process()`:

```gdscript
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

- [ ] **Step 5: Guard S_HpRegen**

In `src/systems/s_hp_regen.gd`, add at the top of `process()`:

```gdscript
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

- [ ] **Step 6: Commit**

```bash
git add src/systems/s_monster_ai.gd src/systems/s_boss_ai.gd src/systems/s_conditions.gd src/systems/s_lifetime.gd src/systems/s_hp_regen.gd
git commit -m "feat: add host-only guards to monster AI, conditions, lifetime, hp regen systems"
```

---

### Task 8: Weapon Firing RPC — Client to Host

**Files:**
- Modify: `src/systems/s_weapon.gd`
- Modify: `src/levels/generated_level.gd`

Currently the local client fires and spawns projectiles directly. For multiplayer, the client sends a fire RPC to the host, and the host spawns the authoritative projectile.

- [ ] **Step 1: Add fire RPC to S_Weapon**

In `src/systems/s_weapon.gd`, the system currently emits `projectile_requested` when a local player fires. For multiplayer, the local player should call an RPC on the level to request the host spawn a projectile.

Replace the `process()` method:

```gdscript
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		if not is_instance_valid(entity):
			print("[S_Weapon] Skipping freed entity")
			continue
		var weapon := entity.get_component(C_Weapon) as C_Weapon
		var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity

		# Tick cooldown
		if weapon.cooldown_remaining > 0:
			weapon.cooldown_remaining -= delta

		# Fire if requested and ready
		if weapon.is_firing and weapon.cooldown_remaining <= 0 and net_id.is_local:
			weapon.cooldown_remaining = weapon.fire_rate
			var body = entity.get_parent()
			if body:
				projectile_requested.emit(body, weapon)
			var wv = entity.get_component(C_WeaponVisual)
			if wv:
				wv.just_fired = true
```

This stays the same — the system emits `projectile_requested`. The change is in `generated_level.gd` which handles the signal.

- [ ] **Step 2: Update generated_level.gd to RPC projectile spawning**

In `src/levels/generated_level.gd`, replace `_on_projectile_requested()`:

```gdscript
func _on_projectile_requested(owner_body: Node3D, weapon: C_Weapon) -> void:
	if not is_instance_valid(owner_body) or not owner_body.is_inside_tree():
		return
	var camera = owner_body.get_node_or_null("Camera3D") as Camera3D
	if not camera:
		return
	var muzzle = owner_body.get_node_or_null("Camera3D/WeaponViewmodel/MuzzlePoint")
	var spawn_pos: Vector3
	if muzzle and muzzle.is_inside_tree():
		spawn_pos = muzzle.global_position
	elif camera.is_inside_tree():
		spawn_pos = camera.global_position + (-camera.global_transform.basis.z * 1.0)
	else:
		return
	var direction = -camera.global_transform.basis.z

	if Net.is_active:
		# Send fire request to host
		_request_projectile.rpc_id(1, spawn_pos, direction, weapon.projectile_speed,
			weapon.damage, weapon.element, owner_body.get_instance_id())
	else:
		# Solo mode: spawn directly
		_spawn_projectile(spawn_pos, direction, weapon.projectile_speed,
			weapon.damage, weapon.element, owner_body.get_instance_id())

	# Muzzle flash (local visual, always show)
	var flash = VfxFactory.create_muzzle_flash(spawn_pos)
	add_child(flash)

@rpc("any_peer", "reliable")
func _request_projectile(pos: Vector3, dir: Vector3, speed: float, damage: int, element: String, owner_id: int) -> void:
	# Only host processes fire requests
	if not Net.is_host:
		return
	_spawn_projectile(pos, dir, speed, damage, element, owner_id)

func _spawn_projectile(pos: Vector3, dir: Vector3, speed: float, damage: int, element: String, owner_id: int) -> void:
	var projectile = ProjectileScene.instantiate()
	_projectile_container.add_child(projectile)
	projectile.global_position = pos
	projectile.setup(dir, speed, damage, element, owner_id)
```

- [ ] **Step 3: Update boss projectile spawning similarly**

Replace `_on_boss_projectile_requested()`:

```gdscript
func _on_boss_projectile_requested(pos: Vector3, direction: Vector3, damage: int, speed: float, owner_id: int) -> void:
	if Net.is_active and not Net.is_host:
		return
	_spawn_projectile(pos, direction, speed, damage, "", owner_id)
```

- [ ] **Step 4: Commit**

```bash
git add src/systems/s_weapon.gd src/levels/generated_level.gd
git commit -m "feat: add fire RPC — client requests projectile, host spawns authoritatively"
```

---

### Task 9: Damage, Death & Health Sync

**Files:**
- Modify: `src/systems/s_damage.gd`
- Modify: `src/levels/generated_level.gd`
- Modify: `src/entities/player.gd`

- [ ] **Step 1: Gate S_Damage.apply_damage to host only in multiplayer**

In `src/systems/s_damage.gd`, update `apply_damage()` (line 16):

```gdscript
static func apply_damage(target_entity: Entity, damage: int, element: String) -> void:
	# In multiplayer, only host applies damage
	if Net.is_active and not Net.is_host:
		return

	var health := target_entity.get_component(C_Health) as C_Health
	if not health:
		return
	# ... rest unchanged ...
```

- [ ] **Step 2: Add health sync to player via MultiplayerSynchronizer**

In `src/entities/player.gd`, update the MultiplayerSynchronizer setup in `_ready()` to also sync health. Update the sync config block added in Task 3:

```gdscript
	# Multiplayer sync: position, rotation, health
	var sync = MultiplayerSynchronizer.new()
	sync.name = "PlayerSync"
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	sync.replication_config = config
	sync.replication_interval = 1.0 / 20.0
	add_child(sync)
```

Note: Health is stored on the ECS component (`C_Health`), not on the node directly. Since `MultiplayerSynchronizer` only syncs node properties, we need a different approach for health. Add synced properties to the player node:

```gdscript
var synced_health: int = 100:
	set(val):
		synced_health = val
		if ecs_entity and not _is_local_authority():
			var health := ecs_entity.get_component(C_Health) as C_Health
			if health:
				health.current_health = val

func _is_local_authority() -> bool:
	if not Net.is_active:
		return true
	return Net.is_host
```

And in the sync config, add:

```gdscript
	config.add_property(NodePath(".:synced_health"))
```

Then in `_process()`, the host pushes health to the synced property:

```gdscript
func _process(_delta: float) -> void:
	if not Net.is_active or Net.is_host:
		var health := get_component(C_Health) as C_Health
		if health:
			synced_health = health.current_health
```

- [ ] **Step 3: Add death RPC to generated_level.gd**

In `src/levels/generated_level.gd`, update `_on_actor_died()`:

```gdscript
func _on_actor_died(entity: Entity) -> void:
	# Only host processes deaths
	if Net.is_active and not Net.is_host:
		return

	var tag := entity.get_component(C_ActorTag) as C_ActorTag
	if not tag:
		return

	if tag.actor_type == C_ActorTag.ActorType.MONSTER:
		var health := entity.get_component(C_Health) as C_Health
		if health and RunManager:
			RunManager.register_kill(health.max_health)

		monsters_remaining -= 1

		var boss_ai = entity.get_component(C_BossAI)
		if boss_ai and boss_ai.is_boss:
			print("[GeneratedLevel] Boss defeated!")
			if RunManager:
				RunManager.on_level_cleared()
			return

		if monsters_remaining <= 0 and not _is_boss_level:
			print("[GeneratedLevel] All monsters defeated!")
			if RunManager:
				RunManager.on_level_cleared()

	elif tag.actor_type == C_ActorTag.ActorType.PLAYER:
		if not Config.god_mode and RunManager:
			_on_player_died()
```

Add a player death handler that tracks alive count:

```gdscript
var _alive_players: int = 0

func _on_player_died() -> void:
	_alive_players -= 1
	if _alive_players <= 0 and RunManager:
		RunManager.on_player_died()
```

Initialize `_alive_players` when players are spawned — increment in `spawn_player()`:

```gdscript
func spawn_player(peer_id: int, is_local: bool) -> void:
	_alive_players += 1
	# ... rest unchanged ...
```

- [ ] **Step 4: Commit**

```bash
git add src/systems/s_damage.gd src/systems/s_death.gd src/levels/generated_level.gd src/entities/player.gd
git commit -m "feat: host-only damage/death, health sync via synced property, player death tracking"
```

---

### Task 10: Ability Sync — Dash & AOE Blast

**Files:**
- Modify: `src/systems/s_dash.gd`
- Modify: `src/systems/s_aoe_blast.gd`

- [ ] **Step 1: Read current S_Dash and S_AoEBlast**

Read `src/systems/s_dash.gd` and `src/systems/s_aoe_blast.gd` to understand the current implementation before modifying.

- [ ] **Step 2: Gate AOE blast damage to host**

In `src/systems/s_aoe_blast.gd`, the AOE blast damages monsters. Since damage is host-authoritative, only the host should apply AOE damage. The local player can still trigger the visual effect.

Find the section that applies damage to monsters and wrap it:

```gdscript
		# Only host applies AOE damage
		if not Net.is_active or Net.is_host:
			# ... existing damage loop for monsters in radius ...
```

The visual ring/particles should still spawn on the local client for immediate feedback.

- [ ] **Step 3: Dash needs no authority change**

Dash is purely movement — the client is authoritative for their own movement. The dash modifies `C_Velocity` which drives `move_and_slide()` on the local player. The resulting position syncs via `MultiplayerSynchronizer`. No RPC needed.

The existing `is_local` check in S_Dash already gates it correctly.

- [ ] **Step 4: Commit**

```bash
git add src/systems/s_dash.gd src/systems/s_aoe_blast.gd
git commit -m "feat: gate AOE blast damage to host, dash syncs via position"
```

---

### Task 11: Run Progression Sync

**Files:**
- Modify: `src/run/run_manager.gd`
- Modify: `src/main.gd`
- Modify: `src/levels/generated_level.gd`

This is the most complex task. The host drives all state transitions and broadcasts them to clients.

- [ ] **Step 1: Add state change RPC to main.gd**

In `src/main.gd`, update `_on_state_changed()` to broadcast to clients:

```gdscript
func _on_state_changed(new_state: int) -> void:
	# Host broadcasts state changes to clients
	if Net.is_active and Net.is_host:
		_sync_state_change.rpc(new_state)
	_apply_state_change(new_state)

@rpc("authority", "call_local", "reliable")
func _sync_state_change(new_state: int) -> void:
	# Clients receive state change from host
	_apply_state_change(new_state)

func _apply_state_change(new_state: int) -> void:
	_clear_current()

	match new_state:
		RunManager.State.LOBBY:
			_show_lobby()
		RunManager.State.MAP:
			_show_map()
		RunManager.State.LEVEL, RunManager.State.BOSS:
			_start_level()
		RunManager.State.REWARD:
			_show_reward()
		RunManager.State.SHOP:
			_show_shop()
		RunManager.State.VICTORY:
			_show_victory()
		RunManager.State.GAME_OVER:
			_show_game_over()
```

- [ ] **Step 2: Add level data sync RPC**

In `src/levels/generated_level.gd`, the host generates the level and needs to send the seed to all clients so they generate the same geometry. Add after level generation in `_ready()`:

```gdscript
	# Generate level
	if Net.is_active and not Net.is_host:
		# Client: wait for seed from host (set via RPC before level scene is created)
		pass  # seed already set in Config.level_seed by host's RPC
	var gen = LevelGenerator.new()
	var seed_val = Config.level_seed if Config.level_seed != 0 else randi()
	level_data = gen.generate(Config.level_grid_width, Config.level_grid_height, seed_val, Config.level_tile_size)
	add_child(level_data.geometry)
```

In `src/main.gd`, before `_start_level()`, the host should broadcast config values. Update `_on_map_node_selected()`:

```gdscript
func _on_map_node_selected(node_index: int) -> void:
	RunManager.select_map_node(node_index)
	# After select_map_node sets Config values, broadcast to clients
	if Net.is_active and Net.is_host:
		_sync_level_config.rpc(
			Config.level_seed,
			Config.level_grid_width,
			Config.level_grid_height,
			Config.monster_hp_mult,
			Config.monster_damage_mult,
			Config.monsters_per_room,
			Config.max_monsters_per_level,
			Config.light_range_mult,
			Config.current_modifier
		)

@rpc("authority", "reliable")
func _sync_level_config(seed_val: int, width: int, height: int, hp_mult: float, dmg_mult: float, mpr: int, max_m: int, light: float, modifier: StringName) -> void:
	Config.level_seed = seed_val
	Config.level_grid_width = width
	Config.level_grid_height = height
	Config.monster_hp_mult = hp_mult
	Config.monster_damage_mult = dmg_mult
	Config.monsters_per_room = mpr
	Config.max_monsters_per_level = max_m
	Config.light_range_mult = light
	Config.current_modifier = modifier
```

- [ ] **Step 3: Gate map selection to host only**

In the MAP screen, only the host should be able to select nodes. Add a check in `_on_map_node_selected()`:

```gdscript
func _on_map_node_selected(node_index: int) -> void:
	# Only host can select map nodes
	if Net.is_active and not Net.is_host:
		return
	RunManager.select_map_node(node_index)
	# ... broadcast as above ...
```

- [ ] **Step 4: Gate RunManager mutations to host**

In `src/run/run_manager.gd`, add guards to methods that mutate run state:

```gdscript
func start_run() -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...

func select_map_node(node_index: int) -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...

func on_level_cleared() -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...

func on_player_died() -> void:
	if Net.is_active and not Net.is_host:
		return
	# ... rest unchanged ...
```

- [ ] **Step 5: Commit**

```bash
git add src/run/run_manager.gd src/main.gd src/levels/generated_level.gd
git commit -m "feat: host broadcasts run state transitions, level config, and map selection to clients"
```

---

### Task 12: Connection Handling & Solo Mode

**Files:**
- Modify: `src/networking/network_manager.gd`
- Modify: `src/main.gd`
- Modify: `src/levels/generated_level.gd`

- [ ] **Step 1: Handle player disconnect on host**

In `src/networking/network_manager.gd`, the `player_disconnected` signal already fires. Connect it in `generated_level.gd` to remove the disconnected player's entity.

In `src/levels/generated_level.gd`, add in `_ready()` after the spawner setup:

```gdscript
	# Handle player disconnects
	if Net.is_active:
		Net.player_disconnected.connect(_on_player_disconnected)

func _on_player_disconnected(peer_id: int) -> void:
	if not Net.is_host:
		return
	# Find and remove the disconnected player
	for child in _player_container.get_children():
		if child.name == "Player_%d" % peer_id:
			if child.ecs_entity and ECS.world:
				ECS.world.remove_entity(child.ecs_entity)
			child.queue_free()
			_alive_players -= 1
			break
```

- [ ] **Step 2: Handle host disconnect on clients**

In `src/main.gd`, add in `_ready()`:

```gdscript
func _ready():
	RunManager.state_changed.connect(_on_state_changed)
	multiplayer.server_disconnected.connect(_on_host_disconnected)
	_show_lobby()

func _on_host_disconnected() -> void:
	_clear_current()
	Net.disconnect_all()
	is_solo = false
	RunManager.return_to_lobby()
	# Show message to user
	print("[Main] Host disconnected — returning to lobby")
```

- [ ] **Step 3: Verify solo mode still works**

Solo mode uses `is_solo = true` in `main.gd`. All the guards use `Net.is_active` which returns `false` when there's no multiplayer peer. Verify:

- `Net.is_active` returns `false` when `multiplayer.has_multiplayer_peer()` is false (solo mode)
- When `Net.is_active` is false, all guards pass through (host-only code runs because we're effectively the host)
- `_start_level()` with `is_solo = true` spawns single player with `peer_id = 1`

No code changes needed — the `Net.is_active` guard pattern handles solo mode naturally.

- [ ] **Step 4: Commit**

```bash
git add src/networking/network_manager.gd src/main.gd src/levels/generated_level.gd
git commit -m "feat: handle player/host disconnect, verify solo mode compatibility"
```

---

### Task 13: Manual Integration Test

No code changes. Run through these scenarios to verify the full multiplayer stack.

- [ ] **Step 1: Test solo mode**

Launch the game. Press Solo. Verify:
- Level generates, player spawns, monsters spawn
- Movement, shooting, damage, death all work
- Run progression (reward, shop, map) works
- No errors in console about missing multiplayer peers

- [ ] **Step 2: Test signaling server**

```bash
cd signaling_server && node server.js
```

Verify server starts on port 3000, health check returns "ok".

- [ ] **Step 3: Test two-player connection**

1. Start signaling server locally: `cd signaling_server && node server.js`
2. In `network_manager.gd`, temporarily set `signaling_url = "ws://localhost:3000"` (or use the export in editor)
3. Launch two game instances (export the game or run two editor instances)
4. Instance 1: Host a lobby
5. Instance 2: Join the lobby
6. Verify: both instances show connected in lobby UI
7. Host starts game

- [ ] **Step 4: Test player sync**

After both players are in a level:
- Verify: each player can see the other player's model
- Move around — verify remote player position updates smoothly
- Verify: camera only active on local player

- [ ] **Step 5: Test combat sync**

- Player 1 shoots a monster — verify damage applies and monster health bar shows on both screens
- Player 2 shoots Player 1 — verify friendly fire works, damage shows on both screens
- Kill a monster — verify death animation/removal on both screens
- Kill all monsters — verify level clear triggers on both screens

- [ ] **Step 6: Test disconnect**

- Disconnect Player 2 (close window) — verify Player 2's entity is removed from Player 1's screen
- Test host disconnect — verify client returns to lobby

- [ ] **Step 7: Fix any issues found during testing**

Address any bugs or sync issues discovered. Common issues:
- Entity name conflicts (ensure unique names per peer)
- Authority not set correctly (check `set_multiplayer_authority` calls)
- Sync properties not updating (check `SceneReplicationConfig` paths)
- RPC not reaching target (check `rpc_id` vs `rpc` usage)
