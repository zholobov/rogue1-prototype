extends CanvasLayer

var _entries: PackedStringArray = PackedStringArray()
var _panel: PanelContainer
var _text: RichTextLabel
var _visible := false
var _max_entries := 500

func _ready():
    layer = 100
    _build_ui()

func info(msg: String) -> void:
    print(msg)
    _entries.append(msg)
    if _entries.size() > _max_entries:
        _entries = _entries.slice(_entries.size() - _max_entries)
    if _text and _panel.visible:
        _update_text()

func _build_ui():
    _panel = PanelContainer.new()
    _panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    _panel.visible = false
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.02, 0.05, 0.92)
    _panel.add_theme_stylebox_override("panel", style)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    _panel.add_child(margin)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    margin.add_child(vbox)

    var header = HBoxContainer.new()
    vbox.add_child(header)

    var title = Label.new()
    title.text = "GAME LOG"
    title.add_theme_font_size_override("font_size", 14)
    title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    var copy_btn = Button.new()
    copy_btn.text = "Copy All"
    copy_btn.pressed.connect(_on_copy)
    header.add_child(copy_btn)

    var clear_btn = Button.new()
    clear_btn.text = "Clear"
    clear_btn.pressed.connect(_on_clear)
    header.add_child(clear_btn)

    var close_btn = Button.new()
    close_btn.text = "Close"
    close_btn.pressed.connect(_toggle)
    header.add_child(close_btn)

    _text = RichTextLabel.new()
    _text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _text.scroll_following = true
    _text.selection_enabled = true
    _text.add_theme_font_size_override("normal_font_size", 11)
    _text.add_theme_color_override("default_color", Color(0.8, 0.9, 0.8))
    vbox.add_child(_text)

    add_child(_panel)

func _update_text():
    _text.text = "\n".join(_entries)

func _on_copy():
    DisplayServer.clipboard_set("\n".join(_entries))

func _on_clear():
    _entries.clear()
    _text.text = ""

func _toggle():
    _visible = not _visible
    _panel.visible = _visible
    if _visible:
        _update_text()
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
        _toggle()
        get_viewport().set_input_as_handled()
