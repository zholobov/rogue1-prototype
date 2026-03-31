extends Control

signal back_pressed

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var active_theme = ThemeManager.active_theme

	# Full-screen background
	var bg = ColorRect.new()
	bg.color = active_theme.ui_background_color
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	# Center container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "SELECT THEME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", active_theme.ui_text_color)
	vbox.add_child(title)

	# Theme cards grid
	var grid = HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 20)
	vbox.add_child(grid)

	for t in ThemeManager.available_themes:
		var card = _create_theme_card(t)
		grid.add_child(card)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.pressed.connect(func(): back_pressed.emit())
	vbox.add_child(back_btn)

func _create_theme_card(t: ThemeData) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 250)

	# Highlight active theme
	var style = StyleBoxFlat.new()
	style.bg_color = ThemeManager.active_theme.ui_panel_color
	if t.theme_name == ThemeManager.active_theme.theme_name:
		style.border_color = ThemeManager.active_theme.ui_accent_color
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_width_left = 3
		style.border_width_right = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Theme name
	var name_label = Label.new()
	name_label.text = t.theme_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", t.ui_text_color)
	vbox.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = t.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", t.ui_text_color)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	# Color swatch — 5 palette colors
	var swatch = HBoxContainer.new()
	swatch.alignment = BoxContainer.ALIGNMENT_CENTER
	swatch.add_theme_constant_override("separation", 4)
	vbox.add_child(swatch)
	for color in t.get_palette_array():
		var rect = ColorRect.new()
		rect.color = color
		rect.custom_minimum_size = Vector2(30, 30)
		swatch.add_child(rect)

	# Select button
	var btn = Button.new()
	btn.text = "Select" if t.theme_name != ThemeManager.active_theme.theme_name else "Active"
	btn.disabled = (t.theme_name == ThemeManager.active_theme.theme_name)
	btn.pressed.connect(func():
		ThemeManager.set_theme(t.theme_name)
		# Rebuild UI to reflect new selection — free synchronously to avoid flicker
		for child in get_children():
			remove_child(child)
			child.free()
		_build_ui()
	)
	vbox.add_child(btn)

	return panel
