class_name VictoryScreen
extends Control

signal continue_pressed()
signal end_run_pressed()

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = ThemeManager.active_theme.ui_background_color
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 12)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "BOSS DEFEATED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats = RunManager.stats if RunManager else RunStats.new()

	var meta_earned = int(stats.total_currency_earned * Config.meta_currency_rate)
	var stats_text = """Levels Cleared: %d
Monsters Killed: %d
Damage Dealt: %d
Time Survived: %ds
Loop Reached: %d
Currency Earned: %d
Meta-Currency Earned: %d
Upgrades: %d""" % [
		stats.levels_cleared,
		stats.kills,
		stats.damage_dealt,
		int(stats.time_elapsed),
		stats.loop,
		stats.total_currency_earned,
		meta_earned,
		RunManager.active_upgrades.size() if RunManager else 0,
	]

	var stats_label = Label.new()
	stats_label.text = stats_text
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	if RunManager and RunManager.active_upgrades.size() > 0:
		var upgrades_label = Label.new()
		var upgrade_names: PackedStringArray = []
		for u in RunManager.active_upgrades:
			upgrade_names.append(u.upgrade_name)
		upgrades_label.text = "Upgrades: " + ", ".join(upgrade_names)
		upgrades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrades_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(upgrades_label)

	var btn_row = HBoxContainer.new()
	btn_row.set("theme_override_constants/separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var continue_btn = Button.new()
	continue_btn.text = "Continue (Loop +1)"
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	btn_row.add_child(continue_btn)

	var end_btn = Button.new()
	end_btn.text = "End Run"
	end_btn.pressed.connect(func(): end_run_pressed.emit())
	btn_row.add_child(end_btn)
