class_name WeaponModelFactory
extends RefCounted

# Material colors (theme-independent)
const BASE_METAL = Color(0.55, 0.55, 0.60)
const DARK_METAL = Color(0.35, 0.35, 0.38)
const GRIP_COLOR = Color(0.27, 0.20, 0.13)

static func create_viewmodel(weapon_index: int, element: String) -> Node3D:
    var root: Node3D
    match weapon_index:
        0: root = _build_pistol_viewmodel()
        1: root = _build_flamethrower_viewmodel()
        2: root = _build_ice_rifle_viewmodel()
        3: root = _build_water_gun_viewmodel()
        _: return null
    root.name = "WeaponViewmodel"
    _apply_element_glow(root, element)
    return root

static func create_world_model(weapon_index: int, element: String) -> Node3D:
    var root: Node3D
    match weapon_index:
        0: root = _build_pistol_world()
        1: root = _build_flamethrower_world()
        2: root = _build_ice_rifle_world()
        3: root = _build_water_gun_world()
        _: return null
    root.name = "WeaponWorldModel"
    root.scale = Vector3(1.2, 1.2, 1.2)
    _apply_element_glow(root, element)
    return root

static func create_hud_icon(weapon_index: int, element: String) -> Control:
    var root = Control.new()
    root.custom_minimum_size = Vector2(64, 48)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    match weapon_index:
        0: _build_pistol_icon(root, element)
        1: _build_flamethrower_icon(root, element)
        2: _build_ice_rifle_icon(root, element)
        3: _build_water_gun_icon(root, element)
    return root

# --- Material helpers ---

static func _make_mat(color: Color, roughness: float = 0.7) -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat

static func _make_emissive_mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color.darkened(0.5)
    mat.roughness = 0.5
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    return mat

static func _add_box(parent: Node3D, pos: Vector3, box_size: Vector3, mat: StandardMaterial3D, node_name: String = "") -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = box_size
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if node_name != "":
        mi.name = node_name
    parent.add_child(mi)
    return mi

static func _add_sphere(parent: Node3D, pos: Vector3, radius: float, mat: StandardMaterial3D, node_name: String = "") -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if node_name != "":
        mi.name = node_name
    parent.add_child(mi)
    return mi

static func _add_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: StandardMaterial3D, node_name: String = "") -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if node_name != "":
        mi.name = node_name
    parent.add_child(mi)
    return mi

static func _add_muzzle(parent: Node3D, pos: Vector3) -> void:
    var marker = Marker3D.new()
    marker.name = "MuzzlePoint"
    marker.position = pos
    parent.add_child(marker)

# --- Element glow ---

static func _get_element_color(element: String) -> Color:
    if ThemeManager and ThemeManager.active_theme:
        return ThemeManager.active_theme.get_element_color(element)
    match element:
        "fire": return Color(1.0, 0.5, 0.1)
        "ice": return Color(0.0, 0.8, 1.0)
        "water": return Color(0.0, 0.5, 1.0)
        _: return Color.WHITE

static func _apply_element_glow(root: Node3D, element: String) -> void:
    if element == "":
        return
    var color = _get_element_color(element)
    for child in root.get_children():
        if child is MeshInstance3D and child.name.begins_with("Accent"):
            child.material_override = _make_emissive_mat(color)

# --- Pistol ---

static func _build_pistol_viewmodel() -> Node3D:
    var root = Node3D.new()
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)

    # Barrel
    _add_box(root, Vector3(0, 0.06, -0.18), Vector3(0.04, 0.035, 0.22), base)
    # Front sight
    _add_box(root, Vector3(0, 0.085, -0.27), Vector3(0.015, 0.015, 0.01), dark)
    # Rear sight
    _add_box(root, Vector3(0, 0.085, -0.08), Vector3(0.025, 0.015, 0.01), dark)
    # Slide body
    _add_box(root, Vector3(0, 0.03, -0.1), Vector3(0.05, 0.04, 0.18), base)
    # Panel line top
    _add_box(root, Vector3(0, 0.052, -0.1), Vector3(0.052, 0.003, 0.17), dark)
    # Panel line bottom
    _add_box(root, Vector3(0, 0.008, -0.1), Vector3(0.052, 0.003, 0.17), dark)
    # Ejection port
    _add_box(root, Vector3(0.02, 0.04, -0.06), Vector3(0.015, 0.02, 0.03), dark)
    # Muzzle
    _add_sphere(root, Vector3(0, 0.06, -0.29), 0.012, _make_mat(Color(0.15, 0.15, 0.15)))
    # Trigger guard
    _add_box(root, Vector3(0, -0.02, -0.06), Vector3(0.035, 0.003, 0.04), dark)
    # Trigger
    _add_box(root, Vector3(0, -0.01, -0.05), Vector3(0.008, 0.02, 0.006), base)
    # Grip
    _add_box(root, Vector3(0, -0.06, -0.04), Vector3(0.035, 0.07, 0.03), grip)
    # Grip lines
    _add_box(root, Vector3(0, -0.04, -0.04), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.055, -0.04), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.07, -0.04), Vector3(0.036, 0.004, 0.031), dark)
    # Accent (for element glow)
    _add_box(root, Vector3(0, 0.052, -0.18), Vector3(0.042, 0.004, 0.06), base, "AccentStrip")
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.06, -0.32))
    return root

static func _build_pistol_world() -> Node3D:
    var root = Node3D.new()
    var base = _make_mat(BASE_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    _add_box(root, Vector3(0, 0.05, -0.15), Vector3(0.04, 0.035, 0.2), base)
    _add_box(root, Vector3(0, 0.02, -0.08), Vector3(0.05, 0.04, 0.15), base)
    _add_box(root, Vector3(0, -0.04, -0.04), Vector3(0.035, 0.06, 0.03), grip)
    _add_box(root, Vector3(0, 0.052, -0.15), Vector3(0.042, 0.004, 0.06), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.05, -0.26))
    return root

# --- Flamethrower ---

static func _build_flamethrower_viewmodel() -> Node3D:
    var root = Node3D.new()
    var barrel_col = Color(0.47, 0.27, 0.0)
    var barrel_mat = _make_mat(barrel_col)
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var tank_col = Color(0.27, 0.2, 0.0)
    var tank_mat = _make_mat(tank_col)

    # Wide barrel
    _add_box(root, Vector3(0, 0.05, -0.2), Vector3(0.06, 0.05, 0.28), barrel_mat)
    # Barrel rings
    _add_box(root, Vector3(0, 0.05, -0.30), Vector3(0.065, 0.055, 0.015), dark)
    _add_box(root, Vector3(0, 0.05, -0.22), Vector3(0.065, 0.055, 0.015), dark)
    _add_box(root, Vector3(0, 0.05, -0.14), Vector3(0.065, 0.055, 0.015), dark)
    # Body
    _add_box(root, Vector3(0, 0.01, -0.05), Vector3(0.07, 0.05, 0.2), base)
    # Accent strip
    _add_box(root, Vector3(0, 0.038, -0.05), Vector3(0.05, 0.005, 0.12), base, "AccentStrip")
    # Panel line
    _add_box(root, Vector3(0, -0.015, -0.05), Vector3(0.072, 0.003, 0.19), dark)
    # Fuel tank (sphere scaled as ellipsoid)
    var tank = _add_sphere(root, Vector3(0, -0.08, -0.02), 0.04, tank_mat)
    tank.scale = Vector3(1.0, 1.4, 1.0)
    # Tank ring
    _add_cylinder(root, Vector3(0, -0.08, -0.02), 0.032, 0.005, dark)
    # Connector
    _add_box(root, Vector3(0, -0.03, -0.02), Vector3(0.02, 0.03, 0.015), base)
    # Igniter
    _add_box(root, Vector3(-0.025, 0.04, -0.32), Vector3(0.015, 0.015, 0.015), base)
    # Grip
    _add_box(root, Vector3(0.025, 0.0, 0.04), Vector3(0.03, 0.05, 0.025), grip)
    _add_box(root, Vector3(0.025, 0.005, 0.04), Vector3(0.031, 0.004, 0.026), dark)
    _add_box(root, Vector3(0.025, -0.01, 0.04), Vector3(0.031, 0.004, 0.026), dark)
    # Indicator light
    _add_sphere(root, Vector3(-0.02, 0.035, -0.1), 0.006, base, "AccentLight")
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.05, -0.36))
    return root

static func _build_flamethrower_world() -> Node3D:
    var root = Node3D.new()
    var barrel_mat = _make_mat(Color(0.47, 0.27, 0.0))
    var base = _make_mat(BASE_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var tank_mat = _make_mat(Color(0.27, 0.2, 0.0))
    _add_box(root, Vector3(0, 0.05, -0.2), Vector3(0.06, 0.05, 0.28), barrel_mat)
    _add_box(root, Vector3(0, 0.01, -0.05), Vector3(0.07, 0.05, 0.2), base)
    var tank = _add_sphere(root, Vector3(0, -0.06, -0.02), 0.035, tank_mat)
    tank.scale = Vector3(1.0, 1.3, 1.0)
    _add_box(root, Vector3(0.025, 0.0, 0.04), Vector3(0.03, 0.05, 0.025), grip)
    _add_box(root, Vector3(0, 0.038, -0.05), Vector3(0.05, 0.005, 0.12), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.05, -0.36))
    return root

# --- Ice Rifle ---

static func _build_ice_rifle_viewmodel() -> Node3D:
    var root = Node3D.new()
    var rifle_col = Color(0.33, 0.47, 0.67)
    var rifle_mat = _make_mat(rifle_col)
    var dark_rifle = _make_mat(Color(0.27, 0.33, 0.4))
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)

    # Long barrel
    _add_box(root, Vector3(0, 0.05, -0.22), Vector3(0.035, 0.03, 0.35), rifle_mat)
    # Barrel rings
    _add_box(root, Vector3(0, 0.05, -0.35), Vector3(0.04, 0.035, 0.01), dark_rifle)
    _add_box(root, Vector3(0, 0.05, -0.28), Vector3(0.04, 0.035, 0.01), dark_rifle)
    _add_box(root, Vector3(0, 0.05, -0.21), Vector3(0.04, 0.035, 0.01), dark_rifle)
    # Muzzle glow
    _add_sphere(root, Vector3(0, 0.05, -0.40), 0.01, base, "AccentMuzzle")
    # Receiver
    _add_box(root, Vector3(0, 0.025, -0.02), Vector3(0.06, 0.04, 0.2), dark_rifle)
    # Accent strip
    _add_box(root, Vector3(0, 0.047, -0.02), Vector3(0.04, 0.004, 0.14), rifle_mat, "AccentStrip")
    # Panel line
    _add_box(root, Vector3(0, 0.003, -0.02), Vector3(0.062, 0.003, 0.19), dark)
    # Scope
    _add_box(root, Vector3(0, 0.08, -0.05), Vector3(0.03, 0.025, 0.08), dark_rifle)
    _add_sphere(root, Vector3(0, 0.08, -0.09), 0.008, base, "AccentLensFront")
    _add_sphere(root, Vector3(0, 0.08, -0.01), 0.008, base, "AccentLensRear")
    # Stock
    _add_box(root, Vector3(0, 0.035, 0.12), Vector3(0.04, 0.035, 0.08), dark_rifle)
    _add_box(root, Vector3(0, 0.01, 0.14), Vector3(0.04, 0.05, 0.06), dark_rifle)
    # Grip
    _add_box(root, Vector3(0, -0.03, 0.02), Vector3(0.03, 0.06, 0.025), grip)
    _add_box(root, Vector3(0, -0.015, 0.02), Vector3(0.031, 0.004, 0.026), dark)
    _add_box(root, Vector3(0, -0.035, 0.02), Vector3(0.031, 0.004, 0.026), dark)
    # Trigger guard + trigger
    _add_box(root, Vector3(0, -0.005, -0.01), Vector3(0.035, 0.003, 0.04), dark)
    _add_box(root, Vector3(0, 0.0, -0.005), Vector3(0.008, 0.02, 0.006), base)
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.05, -0.42))
    return root

static func _build_ice_rifle_world() -> Node3D:
    var root = Node3D.new()
    var rifle_mat = _make_mat(Color(0.33, 0.47, 0.67))
    var dark_rifle = _make_mat(Color(0.27, 0.33, 0.4))
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var base = _make_mat(BASE_METAL)
    _add_box(root, Vector3(0, 0.05, -0.22), Vector3(0.035, 0.03, 0.35), rifle_mat)
    _add_box(root, Vector3(0, 0.025, -0.02), Vector3(0.06, 0.04, 0.2), dark_rifle)
    _add_box(root, Vector3(0, 0.08, -0.05), Vector3(0.03, 0.025, 0.08), dark_rifle)
    _add_box(root, Vector3(0, -0.03, 0.02), Vector3(0.03, 0.06, 0.025), grip)
    _add_box(root, Vector3(0, 0.047, -0.02), Vector3(0.04, 0.004, 0.14), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.05, -0.42))
    return root

# --- Water Gun ---

static func _build_water_gun_viewmodel() -> Node3D:
    var root = Node3D.new()
    var water_col = Color(0.2, 0.33, 0.67)
    var water_mat = _make_mat(water_col)
    var dark_water = _make_mat(Color(0.16, 0.27, 0.53))
    var base = _make_mat(BASE_METAL)
    var dark = _make_mat(DARK_METAL)
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var tank_col = Color(0.1, 0.2, 0.47)

    # Stubby barrel
    _add_box(root, Vector3(0, 0.04, -0.15), Vector3(0.055, 0.045, 0.2), water_mat)
    # Barrel rings
    _add_box(root, Vector3(0, 0.04, -0.22), Vector3(0.06, 0.05, 0.015), dark_water)
    _add_box(root, Vector3(0, 0.04, -0.14), Vector3(0.06, 0.05, 0.015), dark_water)
    # Nozzle
    _add_box(root, Vector3(0, 0.04, -0.27), Vector3(0.03, 0.03, 0.02), dark_water)
    _add_sphere(root, Vector3(0, 0.04, -0.29), 0.012, base, "AccentNozzle")
    # Body
    _add_box(root, Vector3(0, 0.0, -0.03), Vector3(0.065, 0.05, 0.18), dark_water)
    # Accent strip
    _add_box(root, Vector3(0, 0.027, -0.03), Vector3(0.045, 0.004, 0.12), water_mat, "AccentStrip")
    # Panel line
    _add_box(root, Vector3(0, -0.025, -0.03), Vector3(0.067, 0.003, 0.17), dark)
    # Water tank (sphere)
    var tank = _add_sphere(root, Vector3(0, 0.1, -0.05), 0.045, _make_mat(Color(tank_col)))
    tank.scale = Vector3(1.2, 0.9, 1.0)
    # Tank cap
    _add_box(root, Vector3(0, 0.145, -0.05), Vector3(0.03, 0.015, 0.025), dark_water)
    # Water indicator
    _add_sphere(root, Vector3(0, 0.1, -0.05), 0.012, base, "AccentIndicator")
    # Connector
    _add_box(root, Vector3(0, 0.06, -0.05), Vector3(0.02, 0.02, 0.015), dark_water)
    # Grip
    _add_box(root, Vector3(0, -0.05, 0.02), Vector3(0.035, 0.07, 0.03), grip)
    _add_box(root, Vector3(0, -0.03, 0.02), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.045, 0.02), Vector3(0.036, 0.004, 0.031), dark)
    _add_box(root, Vector3(0, -0.06, 0.02), Vector3(0.036, 0.004, 0.031), dark)
    # Trigger guard + pump trigger
    _add_box(root, Vector3(0, -0.01, -0.02), Vector3(0.035, 0.003, 0.04), dark)
    _add_box(root, Vector3(0, -0.005, -0.015), Vector3(0.008, 0.02, 0.008), water_mat)
    # Muzzle point
    _add_muzzle(root, Vector3(0, 0.04, -0.30))
    return root

static func _build_water_gun_world() -> Node3D:
    var root = Node3D.new()
    var water_mat = _make_mat(Color(0.2, 0.33, 0.67))
    var dark_water = _make_mat(Color(0.16, 0.27, 0.53))
    var grip = _make_mat(GRIP_COLOR, 0.9)
    var base = _make_mat(BASE_METAL)
    _add_box(root, Vector3(0, 0.04, -0.15), Vector3(0.055, 0.045, 0.2), water_mat)
    _add_box(root, Vector3(0, 0.0, -0.03), Vector3(0.065, 0.05, 0.18), dark_water)
    var tank = _add_sphere(root, Vector3(0, 0.1, -0.05), 0.04, _make_mat(Color(0.1, 0.2, 0.47)))
    tank.scale = Vector3(1.2, 0.9, 1.0)
    _add_box(root, Vector3(0, -0.05, 0.02), Vector3(0.035, 0.07, 0.03), grip)
    _add_box(root, Vector3(0, 0.027, -0.03), Vector3(0.045, 0.004, 0.12), base, "AccentStrip")
    _add_muzzle(root, Vector3(0, 0.04, -0.30))
    return root

# --- HUD Icons (2D silhouettes from ColorRects) ---

static func _icon_rect(parent: Control, pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
    var r = ColorRect.new()
    r.position = pos
    r.size = sz
    r.color = color
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(r)
    return r

static func _get_element_icon_color(element: String) -> Color:
    match element:
        "fire": return Color(1.0, 0.4, 0.05, 0.6)
        "ice": return Color(0.0, 0.8, 1.0, 0.6)
        "water": return Color(0.0, 0.53, 1.0, 0.6)
        _: return Color(0.6, 0.6, 0.6, 0.0)  # invisible for no element

static func _build_pistol_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(8, 8), Vector2(40, 10), Color(0.5, 0.5, 0.52))    # barrel
    _icon_rect(root, Vector2(12, 18), Vector2(32, 16), Color(0.38, 0.38, 0.4))  # body
    _icon_rect(root, Vector2(22, 34), Vector2(14, 14), GRIP_COLOR)              # grip
    _icon_rect(root, Vector2(4, 10), Vector2(6, 6), Color(0.25, 0.25, 0.25))   # muzzle
    if accent.a > 0:
        _icon_rect(root, Vector2(12, 16), Vector2(24, 3), accent)               # element accent

static func _build_flamethrower_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(2, 10), Vector2(50, 12), Color(0.47, 0.27, 0.0))  # barrel
    _icon_rect(root, Vector2(14, 22), Vector2(38, 14), Color(0.38, 0.38, 0.4)) # body
    _icon_rect(root, Vector2(24, 36), Vector2(20, 12), Color(0.27, 0.2, 0.0))  # tank (approx)
    _icon_rect(root, Vector2(0, 12), Vector2(6, 8), Color(1.0, 0.4, 0.0, 0.4)) # muzzle glow
    if accent.a > 0:
        _icon_rect(root, Vector2(16, 24), Vector2(22, 3), accent)

static func _build_ice_rifle_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(0, 16), Vector2(55, 9), Color(0.33, 0.47, 0.67))   # long barrel
    _icon_rect(root, Vector2(22, 25), Vector2(36, 13), Color(0.27, 0.33, 0.4))  # receiver
    _icon_rect(root, Vector2(28, 8), Vector2(16, 7), Color(0.22, 0.27, 0.33))   # scope
    _icon_rect(root, Vector2(50, 22), Vector2(14, 16), Color(0.27, 0.33, 0.4))  # stock
    _icon_rect(root, Vector2(0, 18), Vector2(4, 5), Color(0.0, 0.8, 1.0, 0.5)) # muzzle glow
    if accent.a > 0:
        _icon_rect(root, Vector2(24, 27), Vector2(26, 3), accent)

static func _build_water_gun_icon(root: Control, element: String) -> void:
    var accent = _get_element_icon_color(element)
    _icon_rect(root, Vector2(4, 20), Vector2(40, 12), Color(0.2, 0.33, 0.67))   # barrel
    _icon_rect(root, Vector2(16, 32), Vector2(34, 14), Color(0.16, 0.27, 0.53)) # body
    _icon_rect(root, Vector2(20, 4), Vector2(24, 16), Color(0.1, 0.2, 0.47))    # tank (approx rect)
    _icon_rect(root, Vector2(44, 44), Vector2(12, 4), Color(0.15, 0.24, 0.48))  # grip hint
    _icon_rect(root, Vector2(2, 22), Vector2(6, 8), Color(0.0, 0.53, 1.0, 0.4)) # nozzle glow
    if accent.a > 0:
        _icon_rect(root, Vector2(18, 34), Vector2(24, 3), accent)
