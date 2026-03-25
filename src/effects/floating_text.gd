class_name FloatingText
extends Label3D

func _init() -> void:
    billboard = BaseMaterial3D.BILLBOARD_ENABLED
    modulate = ThemeManager.active_theme.health_bar_foreground
    outline_modulate = Color.BLACK
    outline_size = 8
    font_size = 32
    pixel_size = 0.01

func show_text(pos: Vector3, value: String) -> void:
    global_position = pos + Vector3(0, 1.5, 0)
    text = value
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "global_position:y", global_position.y + 1.0, 0.8)
    tween.tween_property(self, "modulate:a", 0.0, 0.8)
    tween.chain().tween_callback(queue_free)
