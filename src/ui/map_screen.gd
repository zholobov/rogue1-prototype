class_name MapScreen
extends Control

signal node_selected(node_index: int)

var _current_depth: int = 0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	# Full-screen dark background
	var bg = ColorRect.new()
	bg.color = ThemeManager.active_theme.ui_background_color
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var map = RunManager.map
	if not map:
		return
	_current_depth = RunManager.current_depth

	# Root margin container for padding
	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.set("theme_override_constants/separation", 10)
	margin.add_child(root_vbox)

	# Title row
	var title_row = HBoxContainer.new()
	root_vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Choose Your Path — Depth %d" % _current_depth
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var currency_label = Label.new()
	currency_label.text = "Currency: %d" % RunManager.currency
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(currency_label)

	# HBox for depth columns
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.set("theme_override_constants/separation", 20)
	root_vbox.add_child(hbox)

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
			if ThemeManager and ThemeManager.active_group and ThemeManager.active_group.biomes.size() > 1:
				var biome = ThemeManager.active_group.get_biome(node.biome_index)
				if biome:
					btn.text += "\n[%s]" % biome.biome_name
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
