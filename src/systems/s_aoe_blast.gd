class_name S_AoEBlast
extends System

func query() -> QueryBuilder:
    return q.with_all([C_AoEBlast, C_NetworkIdentity])

func process(entities: Array[Entity], _components: Array, delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var net_id := entity.get_component(C_NetworkIdentity) as C_NetworkIdentity
        if not net_id.is_local:
            continue

        var blast := entity.get_component(C_AoEBlast) as C_AoEBlast
        blast.cooldown_remaining = maxf(blast.cooldown_remaining - delta, 0)

        if Input.is_action_just_pressed("aoe_blast") and blast.cooldown_remaining <= 0:
            blast.cooldown_remaining = blast.cooldown
            var body = entity.get_parent() as Node3D
            if not body:
                continue
            _deal_aoe_damage(body.global_position, blast.damage, blast.radius)

func _deal_aoe_damage(center: Vector3, damage: int, radius: float) -> void:
    var tree = ECS.world.get_tree()
    if not tree:
        return
    for monster in tree.get_nodes_in_group("monsters"):
        if not is_instance_valid(monster):
            continue
        if monster.global_position.distance_to(center) <= radius:
            if monster is MonsterEntity and monster.ecs_entity:
                S_Damage.apply_damage(monster.ecs_entity, damage, "")

    # Visual feedback: ring of particles
    var particles = GPUParticles3D.new()
    particles.position = center
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 20
    particles.lifetime = 0.3
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)

    var mat = ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0.5, 0)
    mat.spread = 180.0
    mat.initial_velocity_min = 8.0
    mat.initial_velocity_max = 12.0
    mat.gravity = Vector3(0, -2, 0)
    mat.scale_min = 0.08
    mat.scale_max = 0.15
    particles.process_material = mat

    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = ThemeManager.active_theme.aoe_blast_color
    draw_mat.emission_enabled = true
    draw_mat.emission = ThemeManager.active_theme.aoe_blast_color
    draw_mat.emission_energy_multiplier = 4.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    var mesh = SphereMesh.new()
    mesh.radius = 0.04
    mesh.height = 0.08
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    tree.current_scene.add_child(particles)
