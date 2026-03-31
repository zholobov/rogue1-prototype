class_name AbilityIndicator
extends Control

var ability_name: String = ""
var cooldown_total: float = 0.0
var cooldown_remaining: float = 0.0
var is_active: bool = false

var _label: Label
var _status_label: Label

func _init() -> void:
    custom_minimum_size = Vector2(50, 60)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
    _label = Label.new()
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.position = Vector2(0, 18)
    _label.size = Vector2(50, 16)
    _label.add_theme_font_size_override("font_size", 9)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_label)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status_label.position = Vector2(0, 44)
    _status_label.size = Vector2(50, 14)
    _status_label.add_theme_font_size_override("font_size", 8)
    _status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_status_label)

func setup(p_name: String, p_cooldown: float) -> void:
    ability_name = p_name
    cooldown_total = p_cooldown
    if _label:
        _label.text = p_name

func update_state(p_remaining: float, p_active: bool = false) -> void:
    cooldown_remaining = p_remaining
    is_active = p_active
    _update_status_label()
    queue_redraw()

func apply_theme() -> void:
    var active_theme = ThemeManager.active_theme
    if _label:
        _label.add_theme_color_override("font_color", active_theme.ui_text_color)
    _update_status_label()
    queue_redraw()

func _update_status_label() -> void:
    var active_theme = ThemeManager.active_theme
    if not _status_label:
        return
    if is_active:
        _status_label.text = "ON"
        _status_label.add_theme_color_override("font_color", active_theme.highlight)
    elif cooldown_remaining <= 0:
        _status_label.text = "READY"
        _status_label.add_theme_color_override("font_color", active_theme.health_bar_foreground)
    else:
        _status_label.text = "%.1fs" % cooldown_remaining
        _status_label.add_theme_color_override("font_color", active_theme.ui_text_color)

func _draw() -> void:
    var active_theme = ThemeManager.active_theme
    var center = Vector2(25, 22)
    var radius = 18.0

    # Background circle fill
    draw_circle(center, radius, active_theme.ui_panel_color)

    if is_active:
        # Active: highlight border
        draw_arc(center, radius, 0, TAU, 64, active_theme.highlight, 2.0)
    elif cooldown_remaining <= 0:
        # Ready: accent border
        draw_arc(center, radius, 0, TAU, 64, active_theme.ui_accent_color, 2.0)
    else:
        # On cooldown: dim border + progress arc
        draw_arc(center, radius, 0, TAU, 64, active_theme.ui_panel_color.lightened(0.2), 1.5)
        if cooldown_total > 0:
            var progress = 1.0 - (cooldown_remaining / cooldown_total)
            var sweep = progress * TAU
            # Clockwise fill from top (-PI/2)
            draw_arc(center, radius - 3, -PI / 2, -PI / 2 + sweep, 64, Color(active_theme.ui_accent_color, 0.4), 6.0)

    if _label:
        _label.text = ability_name
