class_name MetaUpgradesScreen
extends Control

signal back_pressed()

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = ThemeManager.active_theme.ui_background_color
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.set("theme_override_constants/separation", 15)
	margin.add_child(root_vbox)

	var title = Label.new()
	title.text = "PERMANENT UPGRADES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(title)

	var currency_label = Label.new()
	currency_label.text = "Meta-Currency: %d" % MetaSave.meta_currency
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	currency_label.name = "CurrencyLabel"
	root_vbox.add_child(currency_label)

	var stats_label = Label.new()
	stats_label.text = "Best Loop: %d | Best Depth: %d | Total Kills: %d" % [
		MetaSave.best_loop, MetaSave.best_depth, MetaSave.total_kills]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(stats_label)

	var upgrades_vbox = VBoxContainer.new()
	upgrades_vbox.set("theme_override_constants/separation", 10)
	upgrades_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrades_vbox.name = "UpgradesVBox"
	root_vbox.add_child(upgrades_vbox)

	_rebuild_upgrades(upgrades_vbox, currency_label)

	var back_btn = Button.new()
	back_btn.text = "Back to Lobby"
	back_btn.pressed.connect(func(): back_pressed.emit())
	root_vbox.add_child(back_btn)

func _rebuild_upgrades(container: VBoxContainer, currency_label: Label) -> void:
	for child in container.get_children():
		child.queue_free()

	for def in MetaSave.UPGRADE_DEFS:
		var current_tier = MetaSave.upgrades.get(def.id, 0)
		var hbox = HBoxContainer.new()
		hbox.set("theme_override_constants/separation", 15)
		container.add_child(hbox)

		var info = Label.new()
		var tier_text = "Tier %d/%d" % [current_tier, def.max_tier]
		info.text = "%s — %s (%s)" % [def.name, def.description, tier_text]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		if current_tier < def.max_tier:
			var cost = def.costs[current_tier]
			var btn = Button.new()
			btn.text = "Buy (%d)" % cost
			if MetaSave.meta_currency < cost:
				btn.disabled = true
			btn.pressed.connect(func():
				if MetaSave.purchase_upgrade(def.id):
					_rebuild_upgrades(container, currency_label)
					currency_label.text = "Meta-Currency: %d" % MetaSave.meta_currency
			)
			hbox.add_child(btn)
		else:
			var maxed = Label.new()
			maxed.text = "MAXED"
			maxed.modulate = Color(0.3, 1.0, 0.3)
			hbox.add_child(maxed)
