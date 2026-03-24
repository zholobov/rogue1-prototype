class_name MapScreen
extends Control

signal node_selected(node_index: int)

var _current_depth: int = 0

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    # Full-screen dark background
    var bg = ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.1)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var map = RunManager.map
    if not map:
        return
    _current_depth = RunManager.current_depth

    # Title
    var title = Label.new()
    title.text = "Choose Your Path — Depth %d" % _current_depth
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 20)
    title.size = Vector2(get_viewport_rect().size.x, 40)
    add_child(title)

    # Currency display
    var currency_label = Label.new()
    currency_label.text = "Currency: %d" % RunManager.currency
    currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    currency_label.position = Vector2(0, 20)
    currency_label.size = Vector2(get_viewport_rect().size.x - 20, 40)
    add_child(currency_label)

    # HBox for columns
    var hbox = HBoxContainer.new()
    hbox.set_anchors_preset(PRESET_FULL_RECT)
    hbox.set("theme_override_constants/separation", 20)
    hbox.position = Vector2(40, 80)
    hbox.size = Vector2(get_viewport_rect().size.x - 80, get_viewport_rect().size.y - 120)
    add_child(hbox)

    # Draw columns for each depth layer
    for depth in range(map.layers.size()):
        var vbox = VBoxContainer.new()
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.set("theme_override_constants/separation", 10)
        hbox.add_child(vbox)

        # Depth label
        var depth_label = Label.new()
        if depth == map.layers.size() - 1:
            depth_label.text = "BOSS"
        else:
            depth_label.text = "Depth %d" % depth
        depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(depth_label)

        var layer = map.layers[depth]
        for node_idx in range(layer.size()):
            var node = layer[node_idx]
            var btn = Button.new()
            btn.text = node.modifier.to_upper()
            btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

            if node.visited:
                btn.modulate = Color(0.5, 0.5, 0.5)
                btn.disabled = true
            elif depth == _current_depth:
                # Check if reachable
                var reachable = map.get_reachable_indices(depth, RunManager.last_selected_node_index)
                if node_idx in reachable:
                    btn.pressed.connect(_on_node_pressed.bind(node_idx))
                else:
                    btn.disabled = true
                    btn.modulate = Color(0.3, 0.3, 0.3)
            else:
                btn.disabled = true
                btn.modulate = Color(0.4, 0.4, 0.4)

            vbox.add_child(btn)

func _on_node_pressed(node_index: int) -> void:
    node_selected.emit(node_index)
