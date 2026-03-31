class_name ConfigEditor
extends ScrollContainer

signal property_changed(key: String, value: Variant)

var _controls: Dictionary = {}	# key -> Control
var _defaults: Dictionary = {}	# key -> default value
var _section_containers: Dictionary = {}  # title -> VBoxContainer
var _root_vbox: VBoxContainer
var _suppress_signals: bool = false

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func setup(sections: Array) -> void:
	# Clear existing UI
	for child in get_children():
		child.queue_free()
	_controls.clear()
	_defaults.clear()
	_section_containers.clear()

	_root_vbox = VBoxContainer.new()
	_root_vbox.add_theme_constant_override("separation", 4)
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_root_vbox)

	for section in sections:
		_build_section(section)

	_apply_theme()
	if ThemeManager and not ThemeManager.theme_changed.is_connected(_on_theme_changed):
		ThemeManager.theme_changed.connect(_on_theme_changed)

func get_values() -> Dictionary:
	var result: Dictionary = {}
	for key in _controls:
		var control = _controls[key]
		if control is SpinBox:
			result[key] = control.value
		elif control is CheckButton:
			result[key] = control.button_pressed
		elif control is OptionButton:
			result[key] = control.get_item_text(control.selected)
		elif control is ColorPickerButton:
			result[key] = control.color
	return result

func set_property_value(key: String, value: Variant) -> void:
	if not _controls.has(key):
		return
	_suppress_signals = true
	var control = _controls[key]
	if control is SpinBox:
		control.value = value
	elif control is CheckButton:
		control.button_pressed = value
	elif control is OptionButton:
		for i in range(control.item_count):
			if control.get_item_text(i) == str(value):
				control.selected = i
				break
	elif control is ColorPickerButton:
		control.color = value
	_suppress_signals = false

func _build_section(section: Dictionary) -> void:
	var title = section.get("title", "Section")
	var properties = section.get("properties", [])

	# Section header button
	var header = Button.new()
	header.text = "▼ %s" % title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_root_vbox.add_child(header)

	# Section content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	_root_vbox.add_child(content)
	_section_containers[title] = content

	header.pressed.connect(_toggle_section.bind(header, content))

	for prop in properties:
		_build_property(content, prop)

	# Separator
	var sep = HSeparator.new()
	_root_vbox.add_child(sep)

func _build_property(container: VBoxContainer, prop: Dictionary) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	container.add_child(hbox)

	var key = prop.get("key", "")
	var type = prop.get("type", "int")
	var value = prop.get("value", 0)
	_defaults[key] = value

	# Label with default hint
	var label = Label.new()
	var default_hint = _format_default(value, type)
	label.text = "%s [%s]" % [prop.get("label", key), default_hint]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 10)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(label)

	match type:
		"int":
			var spin = SpinBox.new()
			spin.min_value = prop.get("min_value", 0)
			spin.max_value = prop.get("max_value", 100)
			spin.step = prop.get("step", 1)
			spin.value = value
			spin.custom_minimum_size.x = 70
			spin.value_changed.connect(_on_value_changed.bind(key))
			hbox.add_child(spin)
			_controls[key] = spin

		"float":
			var spin = SpinBox.new()
			spin.min_value = prop.get("min_value", 0.0)
			spin.max_value = prop.get("max_value", 10.0)
			spin.step = prop.get("step", 0.01)
			spin.value = value
			spin.custom_minimum_size.x = 70
			spin.value_changed.connect(_on_value_changed.bind(key))
			hbox.add_child(spin)
			_controls[key] = spin

		"bool":
			var check = CheckButton.new()
			check.button_pressed = value
			check.toggled.connect(_on_bool_changed.bind(key))
			hbox.add_child(check)
			_controls[key] = check

		"string_enum":
			var option = OptionButton.new()
			var options = prop.get("options", [])
			for opt in options:
				option.add_item(opt)
			for i in range(option.item_count):
				if option.get_item_text(i) == str(value):
					option.selected = i
					break
			option.custom_minimum_size.x = 90
			option.item_selected.connect(_on_enum_changed.bind(key, option))
			hbox.add_child(option)
			_controls[key] = option

		"color":
			var picker = ColorPickerButton.new()
			picker.color = value
			picker.custom_minimum_size = Vector2(36, 20)
			picker.color_changed.connect(_on_color_changed.bind(key))
			hbox.add_child(picker)
			_controls[key] = picker

	# Reset button per property
	var reset_btn = Button.new()
	reset_btn.text = "↺"
	reset_btn.add_theme_font_size_override("font_size", 10)
	reset_btn.custom_minimum_size = Vector2(22, 0)
	reset_btn.tooltip_text = "Reset to default: %s" % str(value)
	reset_btn.pressed.connect(_reset_property.bind(key))
	hbox.add_child(reset_btn)

func _format_default(value: Variant, type: String) -> String:
	match type:
		"float":
			# Round to 2 decimal places, strip trailing zeros
			var s = "%.2f" % value
			if "." in s:
				s = s.rstrip("0").rstrip(".")
			return s
		"bool":
			return "on" if value else "off"
		_:
			return str(value)

func _reset_property(key: String) -> void:
	if _defaults.has(key):
		set_property_value(key, _defaults[key])
		property_changed.emit(key, _defaults[key])

func _on_value_changed(value: float, key: String) -> void:
	if not _suppress_signals:
		property_changed.emit(key, value)

func _on_bool_changed(pressed: bool, key: String) -> void:
	if not _suppress_signals:
		property_changed.emit(key, pressed)

func _on_enum_changed(index: int, key: String, option: OptionButton) -> void:
	if not _suppress_signals:
		property_changed.emit(key, option.get_item_text(index))

func _on_color_changed(color: Color, key: String) -> void:
	if not _suppress_signals:
		property_changed.emit(key, color)

func reset_all() -> void:
	for key in _defaults:
		set_property_value(key, _defaults[key])
	for key in _defaults:
		property_changed.emit(key, _defaults[key])

func copy_to_clipboard() -> void:
	var values = get_values()
	var json_str = JSON.stringify(values, "	 ")
	DisplayServer.clipboard_set(json_str)

func paste_from_clipboard() -> void:
	var text = DisplayServer.clipboard_get()
	if text.is_empty():
		return
	var json = JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if not data is Dictionary:
		return
	for key in data:
		if _controls.has(key):
			set_property_value(key, data[key])
	# Emit property_changed for each restored value so callers can react
	for key in data:
		if _controls.has(key):
			property_changed.emit(key, data[key])

func _toggle_section(header: Button, content: VBoxContainer) -> void:
	content.visible = not content.visible
	var title = header.text.substr(2)  # Remove "▼ " or "▶ "
	header.text = "%s %s" % ["▼" if content.visible else "▶", title]

func _on_theme_changed(_theme: Variant) -> void:
	_apply_theme()

func _apply_theme() -> void:
	if not ThemeManager:
		return
	var active_theme = ThemeManager.active_theme
	for key in _controls:
		var control = _controls[key]
		if control.get_parent() and control.get_parent().get_child(0) is Label:
			control.get_parent().get_child(0).add_theme_color_override("font_color", active_theme.ui_text_color)
