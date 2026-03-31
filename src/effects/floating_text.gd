class_name FloatingText
extends Label

## 2D floating damage number — positioned via camera.unproject_position().
## Much cheaper than Label3D (no SDF font rendering in 3D).

var _world_pos: Vector3
var _start_y_offset: float = 0.0

func _init() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", ThemeManager.active_theme.health_bar_foreground)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

func show_text(pos: Vector3, value: String) -> void:
	_world_pos = pos + Vector3(randf_range(-0.3, 0.3), 1.5, 0)
	_start_y_offset = 0.0
	text = value
	modulate.a = 1.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "_start_y_offset", -60.0, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(queue_free)

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	# Only show if in front of camera
	var cam_forward = -camera.global_transform.basis.z
	var to_text = (_world_pos - camera.global_position).normalized()
	if cam_forward.dot(to_text) < 0:
		visible = false
		return
	visible = true
	var screen_pos = camera.unproject_position(_world_pos)
	position = screen_pos + Vector2(-30, _start_y_offset)
