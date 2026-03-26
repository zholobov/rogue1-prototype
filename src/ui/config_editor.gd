class_name ConfigEditor
extends ScrollContainer

signal property_changed(key: String, value: Variant)

var _controls: Dictionary = {}  # key -> Control
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
    hbox.add_theme_constant_override("separation", 8)
    container.add_child(hbox)

    var label = Label.new()
    label.text = prop.get("label", prop.get("key", ""))
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 11)
    hbox.add_child(label)

    var key = prop.get("key", "")
    var type = prop.get("type", "int")
    var value = prop.get("value", 0)

    match type:
        "int":
            var spin = SpinBox.new()
            spin.min_value = prop.get("min_value", 0)
            spin.max_value = prop.get("max_value", 100)
            spin.step = prop.get("step", 1)
            spin.value = value
            spin.custom_minimum_size.x = 80
            spin.value_changed.connect(_on_value_changed.bind(key))
            hbox.add_child(spin)
            _controls[key] = spin

        "float":
            var spin = SpinBox.new()
            spin.min_value = prop.get("min_value", 0.0)
            spin.max_value = prop.get("max_value", 10.0)
            spin.step = prop.get("step", 0.01)
            spin.value = value
            spin.custom_minimum_size.x = 80
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
            # Select current value
            for i in range(option.item_count):
                if option.get_item_text(i) == str(value):
                    option.selected = i
                    break
            option.custom_minimum_size.x = 100
            option.item_selected.connect(_on_enum_changed.bind(key, option))
            hbox.add_child(option)
            _controls[key] = option

        "color":
            var picker = ColorPickerButton.new()
            picker.color = value
            picker.custom_minimum_size = Vector2(40, 24)
            picker.color_changed.connect(_on_color_changed.bind(key))
            hbox.add_child(picker)
            _controls[key] = picker

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

func _toggle_section(header: Button, content: VBoxContainer) -> void:
    content.visible = not content.visible
    var title = header.text.substr(2)  # Remove "▼ " or "▶ "
    header.text = "%s %s" % ["▼" if content.visible else "▶", title]

func _on_theme_changed(_theme: Variant) -> void:
    _apply_theme()

func _apply_theme() -> void:
    if not ThemeManager:
        return
    var theme = ThemeManager.active_theme
    for key in _controls:
        var control = _controls[key]
        if control.get_parent() and control.get_parent().get_child(0) is Label:
            control.get_parent().get_child(0).add_theme_color_override("font_color", theme.ui_text_color)
