class_name CrosshairManager
extends Control

## Weapon-specific crosshair reticles built from ColorRect nodes.
## Base shapes are white; modulate tints them by element color.

var _current_index: int = -1
var _current_element: String = ""

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    anchor_left = 0.5
    anchor_top = 0.5
    anchor_right = 0.5
    anchor_bottom = 0.5
    offset_left = -30
    offset_top = -30
    offset_right = 30
    offset_bottom = 30

func set_weapon(index: int, element: String) -> void:
    if index == _current_index and element == _current_element:
        return
    _current_index = index
    _current_element = element
    _rebuild()

func apply_theme() -> void:
    _apply_tint()

func _rebuild() -> void:
    for child in get_children():
        child.queue_free()

    match _current_index:
        0: _build_pistol()
        1: _build_flamethrower()
        2: _build_ice_rifle()
        3: _build_water_gun()
        _: _build_pistol()

    _apply_tint()

func _apply_tint() -> void:
    var theme = ThemeManager.active_theme
    if _current_element == "":
        modulate = theme.ui_crosshair_color
    else:
        modulate = theme.get_element_color(_current_element)

# --- Pistol: center dot + 4 lines with gap ---

func _build_pistol() -> void:
    _add_rect(Vector2(28, 28), Vector2(4, 4))   # Center dot
    _add_rect(Vector2(4, 29), Vector2(14, 2))    # Left line
    _add_rect(Vector2(42, 29), Vector2(14, 2))   # Right line
    _add_rect(Vector2(29, 4), Vector2(2, 14))    # Top line
    _add_rect(Vector2(29, 42), Vector2(2, 14))   # Bottom line

# --- Flamethrower: concentric circles + center dot ---

func _build_flamethrower() -> void:
    _add_ring(Vector2(30, 30), 24, 2)   # Outer ring (spray cone)
    _add_ring(Vector2(30, 30), 12, 2)   # Inner ring
    _add_rect(Vector2(28, 28), Vector2(4, 4))  # Center dot

# --- Ice Rifle: sniper cross + corner ticks ---

func _build_ice_rifle() -> void:
    _add_rect(Vector2(0, 29), Vector2(60, 1))    # Full horizontal
    _add_rect(Vector2(29, 0), Vector2(1, 60))    # Full vertical
    # Gap in center (black overlay)
    var gap = ColorRect.new()
    gap.color = Color.BLACK
    gap.position = Vector2(24, 24)
    gap.size = Vector2(12, 12)
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(gap)
    _add_rect(Vector2(28.5, 28.5), Vector2(3, 3))  # Tiny center dot
    # Corner ticks
    _add_rect(Vector2(10, 10), Vector2(8, 1))
    _add_rect(Vector2(42, 10), Vector2(8, 1))
    _add_rect(Vector2(10, 49), Vector2(8, 1))
    _add_rect(Vector2(42, 49), Vector2(8, 1))

# --- Water Gun: scatter dots + dashed circle ---

func _build_water_gun() -> void:
    _add_rect(Vector2(27, 27), Vector2(5, 5))    # Center dot
    _add_rect(Vector2(21, 18), Vector2(3, 3))    # Spray dots
    _add_rect(Vector2(35, 33), Vector2(3, 3))
    _add_rect(Vector2(22, 37), Vector2(3, 3))
    _add_rect(Vector2(37, 20), Vector2(3, 3))
    _add_rect(Vector2(16, 30), Vector2(2, 2))
    _add_rect(Vector2(40, 28), Vector2(2, 2))
    _add_dashed_ring(Vector2(30, 30), 22, 1)     # Outer dashed circle

# --- Helpers ---

func _add_rect(pos: Vector2, rect_size: Vector2) -> void:
    var r = ColorRect.new()
    r.color = Color.WHITE
    r.position = pos
    r.size = rect_size
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(r)

func _add_ring(center: Vector2, radius: float, thickness: float) -> void:
    var segments = 32
    for i in range(segments):
        var angle = (float(i) / segments) * TAU
        var px = center.x + cos(angle) * radius - thickness / 2
        var py = center.y + sin(angle) * radius - thickness / 2
        _add_rect(Vector2(px, py), Vector2(thickness, thickness))

func _add_dashed_ring(center: Vector2, radius: float, thickness: float) -> void:
    var segments = 24
    for i in range(segments):
        if i % 2 == 0:
            continue
        var angle = (float(i) / segments) * TAU
        var px = center.x + cos(angle) * radius - thickness / 2
        var py = center.y + sin(angle) * radius - thickness / 2
        _add_rect(Vector2(px, py), Vector2(thickness + 1, thickness + 1))
