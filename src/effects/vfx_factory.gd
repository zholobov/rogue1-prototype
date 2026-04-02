class_name VfxFactory
extends RefCounted

# Cached meshes — created once, reused for all particles
static var _trail_mesh_cache: Dictionary = {}   # element -> mesh
static var _muzzle_mesh: Mesh
static var _impact_mesh_cache: Dictionary = {}  # element -> mesh

static func clear_cache() -> void:
    _trail_mesh_cache.clear()
    _muzzle_mesh = null
    _impact_mesh_cache.clear()

static func _get_trail_mesh(element: String) -> Mesh:
    if _trail_mesh_cache.has(element):
        return _trail_mesh_cache[element]

    var color = ThemeManager.active_theme.get_element_color(element)
    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
    draw_mat.emission_enabled = true
    draw_mat.emission = color
    draw_mat.emission_energy_multiplier = 3.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.03, 0.03, 0.03)
    mesh.material = draw_mat

    _trail_mesh_cache[element] = mesh
    return mesh

static func _get_muzzle_mesh() -> Mesh:
    if _muzzle_mesh:
        return _muzzle_mesh

    var draw_mat = StandardMaterial3D.new()
    draw_mat.albedo_color = ThemeManager.active_theme.muzzle_flash_color
    draw_mat.emission_enabled = true
    draw_mat.emission = ThemeManager.active_theme.muzzle_flash_color
    draw_mat.emission_energy_multiplier = 5.0
    draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

    _muzzle_mesh = PrismMesh.new()
    _muzzle_mesh.size = Vector3(0.06, 0.06, 0.06)
    _muzzle_mesh.material = draw_mat
    return _muzzle_mesh

static func _get_impact_mesh(element: String) -> SphereMesh:
    if _impact_mesh_cache.has(element):
        return _impact_mesh_cache[element]

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

    _impact_mesh_cache[element] = mesh
    return mesh

static func create_muzzle_flash(pos: Vector3) -> CPUParticles3D:
    var particles = CPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 6
    particles.lifetime = 0.05
    particles.explosiveness = 1.0
    particles.direction = Vector3(0, 0, -1)
    particles.spread = 30.0
    particles.initial_velocity_min = 2.0
    particles.initial_velocity_max = 4.0
    particles.gravity = Vector3.ZERO
    particles.scale_amount_min = 0.1
    particles.scale_amount_max = 0.2
    particles.mesh = _get_muzzle_mesh()
    particles.finished.connect(particles.queue_free)
    return particles

static func create_trail(element: String) -> CPUParticles3D:
    var particles = CPUParticles3D.new()
    particles.emitting = true
    particles.amount = 12
    particles.lifetime = 0.3
    particles.explosiveness = 0.0
    particles.direction = Vector3(0, 0, 0)
    particles.spread = 10.0
    particles.initial_velocity_min = 0.0
    particles.initial_velocity_max = 0.5
    particles.gravity = Vector3.ZERO
    particles.scale_amount_min = 0.05
    particles.scale_amount_max = 0.05
    particles.damping_min = 5.0
    particles.damping_max = 5.0
    particles.mesh = _get_trail_mesh(element)
    return particles

static func create_impact(pos: Vector3, direction: Vector3, element: String) -> CPUParticles3D:
    var particles = CPUParticles3D.new()
    particles.position = pos
    particles.emitting = true
    particles.one_shot = true
    particles.amount = 10
    particles.lifetime = 0.2
    particles.explosiveness = 1.0
    particles.direction = -direction.normalized()
    particles.spread = 60.0
    particles.initial_velocity_min = 3.0
    particles.initial_velocity_max = 5.0
    particles.gravity = Vector3(0, -5, 0)
    particles.scale_amount_min = 0.03
    particles.scale_amount_max = 0.06
    particles.mesh = _get_impact_mesh(element)
    particles.finished.connect(particles.queue_free)
    return particles
