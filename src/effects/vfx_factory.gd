class_name VfxFactory
extends RefCounted

# Cached materials and meshes — created once, reused for all particles
static var _trail_cache: Dictionary = {}      # element -> {mat, draw_mat, mesh}
static var _muzzle_cache: Dictionary = {}     # single entry
static var _impact_cache: Dictionary = {}     # element -> {mat, draw_mat, mesh}

static func _get_trail_resources(element: String) -> Dictionary:
    if _trail_cache.has(element):
        return _trail_cache[element]

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

    var color = ThemeManager.active_theme.get_element_color(element)
    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
    draw_mat.emission_enabled = true
    draw_mat.emission = color
    draw_mat.emission_energy_multiplier = 3.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var mesh = SphereMesh.new()
    mesh.radius = 0.02
    mesh.height = 0.04
    mesh.material = draw_mat

    var res = {"mat": mat, "mesh": mesh}
    _trail_cache[element] = res
    return res

static func _get_muzzle_resources() -> Dictionary:
    if _muzzle_cache.size() > 0:
        return _muzzle_cache

    var mat = ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0, -1)
    mat.spread = 30.0
    mat.initial_velocity_min = 2.0
    mat.initial_velocity_max = 4.0
    mat.gravity = Vector3.ZERO
    mat.scale_min = 0.1
    mat.scale_max = 0.2

    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = ThemeManager.active_theme.muzzle_flash_color
    draw_mat.emission_enabled = true
    draw_mat.emission = ThemeManager.active_theme.muzzle_flash_color
    draw_mat.emission_energy_multiplier = 5.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    var mesh = SphereMesh.new()
    mesh.radius = 0.03
    mesh.height = 0.06
    mesh.material = draw_mat

    _muzzle_cache = {"mat": mat, "mesh": mesh}
    return _muzzle_cache

static func _get_impact_resources(element: String) -> Dictionary:
    if _impact_cache.has(element):
        return _impact_cache[element]

    var color = ThemeManager.active_theme.get_element_color(element)
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

    var res = {"draw_mat": draw_mat, "mesh": mesh}
    _impact_cache[element] = res
    return res

static func clear_cache() -> void:
    _trail_cache.clear()
    _muzzle_cache.clear()
    _impact_cache.clear()

static func create_muzzle_flash(pos: Vector3) -> GPUParticles3D:
    var res = _get_muzzle_resources()
    var particles = GPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 6
    particles.lifetime = 0.05
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)
    particles.process_material = res.mat
    particles.draw_pass_1 = res.mesh
    return particles

static func create_trail(element: String) -> GPUParticles3D:
    var res = _get_trail_resources(element)
    var particles = GPUParticles3D.new()
    particles.emitting = true
    particles.amount = 12
    particles.lifetime = 0.3
    particles.explosiveness = 0.0
    particles.process_material = res.mat
    particles.draw_pass_1 = res.mesh
    return particles

static func create_impact(pos: Vector3, direction: Vector3, element: String) -> GPUParticles3D:
    var res = _get_impact_resources(element)
    var particles = GPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 10
    particles.lifetime = 0.2
    particles.explosiveness = 1.0
    particles.finished.connect(particles.queue_free)

    # Impact needs a unique process material because direction varies per impact
    var mat = ParticleProcessMaterial.new()
    mat.direction = -direction.normalized()
    mat.spread = 60.0
    mat.initial_velocity_min = 3.0
    mat.initial_velocity_max = 5.0
    mat.gravity = Vector3(0, -5, 0)
    mat.scale_min = 0.03
    mat.scale_max = 0.06
    particles.process_material = mat
    particles.draw_pass_1 = res.mesh
    return particles
