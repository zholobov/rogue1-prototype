class_name RewardScreen
extends Control

signal upgrade_picked(upgrade: UpgradeData)

var _upgrades: Array = []

func _ready() -> void:
    _upgrades = UpgradeData.roll_random(3, RunManager.stats.loop if RunManager else 0)
    _build_ui()

func _build_ui() -> void:
    var bg = ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.1)
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var title = Label.new()
    title.text = "Level Complete! Pick an Upgrade"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.position = Vector2(0, 30)
    title.size = Vector2(get_viewport_rect().size.x, 40)
    add_child(title)

    # Currency display
    var currency_label = Label.new()
    currency_label.text = "Currency: %d" % (RunManager.currency if RunManager else 0)
    currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    currency_label.position = Vector2(0, 60)
    currency_label.size = Vector2(get_viewport_rect().size.x, 30)
    add_child(currency_label)

    var hbox = HBoxContainer.new()
    hbox.set("theme_override_constants/separation", 20)
    hbox.position = Vector2(60, 120)
    hbox.size = Vector2(get_viewport_rect().size.x - 120, get_viewport_rect().size.y - 200)
    add_child(hbox)

    var rarity_colors = {
        "common": Color(0.8, 0.8, 0.8),
        "rare": Color(0.3, 0.5, 1.0),
        "epic": Color(0.7, 0.2, 1.0),
    }

    for i in range(_upgrades.size()):
        var upgrade = _upgrades[i]

        var panel = PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hbox.add_child(panel)

        var vbox = VBoxContainer.new()
        vbox.set("theme_override_constants/separation", 8)
        panel.add_child(vbox)

        var name_label = Label.new()
        name_label.text = upgrade.upgrade_name
        name_label.modulate = rarity_colors.get(upgrade.rarity, Color.WHITE)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(name_label)

        var rarity_label = Label.new()
        rarity_label.text = "[%s]" % upgrade.rarity.to_upper()
        rarity_label.modulate = rarity_colors.get(upgrade.rarity, Color.WHITE)
        rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        vbox.add_child(rarity_label)

        var desc_label = Label.new()
        desc_label.text = upgrade.description
        desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        vbox.add_child(desc_label)

        var btn = Button.new()
        btn.text = "Pick"
        btn.pressed.connect(_on_pick.bind(i))
        vbox.add_child(btn)

func _on_pick(index: int) -> void:
    upgrade_picked.emit(_upgrades[index])
