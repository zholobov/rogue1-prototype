class_name VfxFactory
extends RefCounted

static func create_muzzle_flash(pos: Vector3) -> GPUParticles3D:
    var particles = GPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 6
    particles.lifetime = 0.05
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)

    var mat = ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0, -1)
    mat.spread = 30.0
    mat.initial_velocity_min = 2.0
    mat.initial_velocity_max = 4.0
    mat.gravity = Vector3.ZERO
    mat.scale_min = 0.1
    mat.scale_max = 0.2
    particles.process_material = mat

    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = Color(1.0, 0.9, 0.6)
    draw_mat.emission_enabled = true
    draw_mat.emission = Color(1.0, 0.9, 0.6)
    draw_mat.emission_energy_multiplier = 5.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    var mesh = SphereMesh.new()
    mesh.radius = 0.03
    mesh.height = 0.06
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    return particles

static func create_trail(element: String) -> GPUParticles3D:
    var particles = GPUParticles3D.new()
    particles.emitting = true
    particles.amount = 12
    particles.lifetime = 0.3
    particles.explosiveness = 0.0

    var mat = ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0, 0)
    mat.spread = 10.0
    mat.initial_velocity_min = 0.0
    mat.initial_velocity_max = 0.5
    mat.gravity = Vector3.ZERO
    mat.scale_min = 0.05
    mat.scale_max = 0.05
    mat.damping_min = 5.0
    mat.damping_max = 5.0
    particles.process_material = mat

    var color = NeonPalette.element_color(element)
    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = color
    draw_mat.emission_enabled = true
    draw_mat.emission = color
    draw_mat.emission_energy_multiplier = 3.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    draw_mat.albedo_color.a = 0.8

    var mesh = SphereMesh.new()
    mesh.radius = 0.02
    mesh.height = 0.04
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    return particles

static func create_impact(pos: Vector3, direction: Vector3, element: String) -> GPUParticles3D:
    var particles = GPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 10
    particles.lifetime = 0.2
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)

    var mat = ParticleProcessMaterial.new()
    # Spray opposite to projectile travel direction
    mat.direction = -direction.normalized()
    mat.spread = 60.0
    mat.initial_velocity_min = 3.0
    mat.initial_velocity_max = 5.0
    mat.gravity = Vector3(0, -5, 0)
    mat.scale_min = 0.03
    mat.scale_max = 0.06
    particles.process_material = mat

    var color = NeonPalette.element_color(element)
    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = color
    draw_mat.emission_enabled = true
    draw_mat.emission = color
    draw_mat.emission_energy_multiplier = 4.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    var mesh = SphereMesh.new()
    mesh.radius = 0.02
    mesh.height = 0.04
    mesh.material = draw_mat
    particles.draw_pass_1 = mesh

    return particles
