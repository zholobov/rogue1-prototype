extends Node3D

const HUDScene = preload("res://src/ui/hud.tscn")
const ProjectileScene = preload("res://src/entities/projectile.tscn")
const MonsterScene = preload("res://src/entities/monster.tscn")

var weapon_system: S_Weapon
var level_data: Dictionary = {}
var monsters_remaining: int = 0
var death_system: S_Death
var _is_boss_level: bool = false
var _damage_accum: Dictionary = {}   # rounded pos key -> {amount: int, time: float}
const DAMAGE_NUMBER_INTERVAL := 0.3  # seconds between damage numbers per location
var _hud: Control

func _ready():
	print("[GeneratedLevel] _ready() started")

	var theme = ThemeManager.active_theme
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = theme.background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = theme.ambient_color
	env.ambient_light_energy = theme.ambient_energy
	env.fog_enabled = true
	env.fog_light_color = theme.fog_color
	env.fog_density = theme.fog_density
	env.fog_depth_begin = theme.fog_depth_begin
	env.fog_depth_end = theme.fog_depth_end
	env.fog_sky_affect = 0.0
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	# Open sky for biomes without ceiling
	if not theme.has_ceiling and theme.sky_config.size() > 0:
		var sky_cfg = theme.sky_config
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = sky_cfg.get("sky_top_color", Color(0.05, 0.05, 0.1))
		sky_mat.sky_horizon_color = sky_cfg.get("sky_horizon_color", Color(0.1, 0.15, 0.2))
		sky_mat.ground_bottom_color = sky_cfg.get("ground_bottom_color", Color(0.02, 0.02, 0.02))
		sky_mat.ground_horizon_color = sky_cfg.get("ground_horizon_color", Color(0.1, 0.1, 0.1))
		sky_mat.sun_angle_max = sky_cfg.get("sun_angle_max", 30.0)
		sky_mat.sun_curve = 0.1
		var sky = Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY

	add_child(world_env)

	# Create and register the ECS world
	var world = World.new()
	world.name = "World"
	add_child(world)
	ECS.world = world
	print("[GeneratedLevel] ECS world created")

	# Register all systems
	ECS.world.add_system(S_PlayerInput.new())
	ECS.world.add_system(S_Movement.new())
	ECS.world.add_system(S_Conditions.new())
	ECS.world.add_system(S_Lifetime.new())
	death_system = S_Death.new()
	death_system.actor_died.connect(_on_actor_died)
	ECS.world.add_system(death_system)
	var lifesteal_system = S_Lifesteal.new()
	death_system.actor_died.connect(lifesteal_system.on_actor_died)
	ECS.world.add_system(lifesteal_system)
	ECS.world.add_system(S_HpRegen.new())
	ECS.world.add_system(S_MonsterAI.new())
	var boss_ai_system = S_BossAI.new()
	boss_ai_system.boss_projectile_requested.connect(_on_boss_projectile_requested)
	ECS.world.add_system(boss_ai_system)

	ECS.world.add_system(S_Dash.new())
	ECS.world.add_system(S_AoEBlast.new())

	weapon_system = S_Weapon.new()
	weapon_system.projectile_requested.connect(_on_projectile_requested)
	ECS.world.add_system(weapon_system)
	ECS.world.add_system(S_WeaponVisual.new())
	print("[GeneratedLevel] Systems registered")

	# Generate level
	var gen = LevelGenerator.new()
	var seed_val = Config.level_seed if Config.level_seed != 0 else randi()
	level_data = gen.generate(Config.level_grid_width, Config.level_grid_height, seed_val, Config.level_tile_size)
	add_child(level_data.geometry)

	print("[GeneratedLevel] Level generated with seed: %d, spawn_points: %d" % [level_data.seed, level_data.spawn_points.size()])
	for i in range(level_data.spawn_points.size()):
		print("[GeneratedLevel]   spawn[%d] = %s" % [i, str(level_data.spawn_points[i])])

	# HUD
	_hud = HUDScene.instantiate()
	add_child(_hud)
	_hud.setup_minimap(level_data)

	# Kill feed
	death_system.actor_died.connect(_hud.on_actor_died)

	# Floating damage numbers
	DamageEvents.damage_dealt.connect(_on_damage_dealt)

	# Spawn monsters at spawn points
	_spawn_monsters()
	_is_boss_level = RunManager != null and RunManager.state == RunManager.State.BOSS
	if _is_boss_level:
		_spawn_boss()
	if monsters_remaining <= 0:
		call_deferred("_auto_clear")
	print("[GeneratedLevel] _ready() completed")

func get_spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for child in _find_in_group(level_data.geometry, "spawn_point"):
		points.append(child.global_position)
	return points

func get_player_spawn() -> Vector3:
	var points = get_spawn_points()
	if points.size() > 0:
		return points[0]
	# Fallback to center of grid (avoids border walls)
	var cx = level_data.width * Config.level_tile_size / 2.0
	var cz = level_data.height * Config.level_tile_size / 2.0
	return Vector3(cx, 1.0, cz)

func _spawn_monsters() -> void:
	monsters_remaining = 0
	var spawn_points = get_spawn_points()
	for i in range(1, spawn_points.size()):
		for _m in range(Config.monsters_per_room):
			if Config.max_monsters_per_level > 0 and monsters_remaining >= Config.max_monsters_per_level:
				break
			var monster = MonsterScene.instantiate()
			# Pick monster variant using weighted random from theme
			var spawnable = ThemeManager.get_spawnable_variants()
			if spawnable.size() > 0:
				var total_weight = 0.0
				for v in spawnable:
					total_weight += v.spawn_weight
				var roll = randf() * total_weight
				var cumulative = 0.0
				for v in spawnable:
					cumulative += v.spawn_weight
					if roll < cumulative:
						monster.visual_variant = v.variant_key
						break
			var offset = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			monster.position = spawn_points[i] + offset
			add_child(monster)
			# Apply horde modifier HP scaling (monster.ecs_entity is set in MonsterEntity._ready)
			if Config.monster_hp_mult != 1.0 and monster.ecs_entity:
				var health := monster.ecs_entity.get_component(C_Health) as C_Health
				if health:
					health.max_health = int(health.max_health * Config.monster_hp_mult)
					health.current_health = health.max_health
			if Config.monster_damage_mult != 1.0 and monster.ecs_entity:
				var ai := monster.ecs_entity.get_component(C_MonsterAI) as C_MonsterAI
				if ai:
					ai.attack_damage = int(ai.attack_damage * Config.monster_damage_mult)
			if randf() < Config.monster_weapon_chance and monster.ecs_entity:
				var weapon_index := randi() % WeaponRegistry.weapon_count()
				var weapon_def = WeaponRegistry.get_weapon(weapon_index)
				var boss_ai := C_BossAI.new()
				boss_ai.projectile_damage = Config.monster_ranged_damage
				boss_ai.ranged_cooldown = Config.monster_ranged_cooldown
				boss_ai.projectile_speed = weapon_def.speed
				monster.ecs_entity.add_component(boss_ai)
				var wv := C_WeaponVisual.new()
				wv.weapon_index = weapon_index
				wv.element = weapon_def.element
				monster.ecs_entity.add_component(wv)
				var ai := monster.ecs_entity.get_component(C_MonsterAI) as C_MonsterAI
				if ai:
					ai.attack_range = 8.0
			monsters_remaining += 1

func _spawn_boss() -> void:
	var boss = MonsterScene.instantiate()
	var cx = level_data.width * Config.level_tile_size / 2.0
	var cz = level_data.height * Config.level_tile_size / 2.0
	boss.position = Vector3(cx, 1.0, cz)
	add_child(boss)
	boss.setup_as_boss(RunManager.stats.loop if RunManager else 0)
	monsters_remaining += 1
	print("[GeneratedLevel] Boss spawned at center (%s)" % str(boss.position))
	if _hud:
		_hud.show_boss_bar(boss.ecs_entity)

func _auto_clear() -> void:
	print("[GeneratedLevel] No monsters — auto-clearing level")
	if RunManager:
		RunManager.on_level_cleared()

func _physics_process(delta: float) -> void:
	ECS.process(delta)

func _on_projectile_requested(owner_body: Node3D, weapon: C_Weapon) -> void:
	if not is_instance_valid(owner_body) or not owner_body.is_inside_tree():
		return
	var projectile = ProjectileScene.instantiate()
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
	add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.setup(
		-camera.global_transform.basis.z,
		weapon.projectile_speed,
		weapon.damage,
		weapon.element,
		owner_body.get_instance_id()
	)

	# Muzzle flash
	var flash = VfxFactory.create_muzzle_flash(spawn_pos)
	add_child(flash)

func _on_boss_projectile_requested(pos: Vector3, direction: Vector3, damage: int, speed: float, owner_id: int) -> void:
	var projectile = ProjectileScene.instantiate()
	add_child(projectile)
	projectile.global_position = pos
	projectile.setup(direction, speed, damage, "", owner_id)

	var flash = VfxFactory.create_muzzle_flash(pos)
	add_child(flash)

func _on_actor_died(entity: Entity) -> void:
	var tag := entity.get_component(C_ActorTag) as C_ActorTag
	if not tag:
		return

	if tag.actor_type == C_ActorTag.ActorType.MONSTER:
		var health := entity.get_component(C_Health) as C_Health
		if health and RunManager:
			RunManager.register_kill(health.max_health)

		monsters_remaining -= 1

		# Boss death = immediate level clear (only actual boss, not armed regular monsters)
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
			RunManager.on_player_died()

func _on_damage_dealt(pos: Vector3, amount: int, element: String) -> void:
	# Rate-limit: accumulate damage per location, show combined number every 0.3s
	var key = Vector3i(roundi(pos.x * 2), roundi(pos.y * 2), roundi(pos.z * 2))
	var now = Time.get_ticks_msec() / 1000.0
	if _damage_accum.has(key):
		var entry = _damage_accum[key]
		entry.amount += amount
		entry.element = element
		if now - entry.time < DAMAGE_NUMBER_INTERVAL:
			return  # Accumulate, don't spawn yet
		# Time to show accumulated damage
		amount = entry.amount
		_damage_accum.erase(key)
	else:
		_damage_accum[key] = {"amount": amount, "time": now, "element": element}

	var ft = DamageNumberFactory.create(element)
	get_tree().current_scene.add_child(ft)
	ft.show_text(pos, "-%d" % amount)

	# Clean up old entries that were never flushed
	var stale_keys: Array = []
	for k in _damage_accum:
		if now - _damage_accum[k].time > 1.0:
			stale_keys.append(k)
	for k in stale_keys:
		_damage_accum.erase(k)

func _find_in_group(node: Node, group: String) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		if child.is_in_group(group):
			found.append(child)
		found.append_array(_find_in_group(child, group))
	return found
