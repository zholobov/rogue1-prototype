class_name ShopScreen
extends Control

signal shop_finished()

var _items: Array = []
var _reroll_cost: int = 25
var _currency_label: Label
var _items_container: HBoxContainer

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    _items = UpgradeData.roll_random(5, RunManager.stats.loop if RunManager else 0)
    _build_ui()

func _build_ui() -> void:
    var bg = ColorRect.new()
    bg.color = ThemeManager.active_theme.ui_background_color
    bg.set_anchors_preset(PRESET_FULL_RECT)
    add_child(bg)

    var margin = MarginContainer.new()
    margin.set_anchors_preset(PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 40)
    margin.add_theme_constant_override("margin_right", 40)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    add_child(margin)

    var root_vbox = VBoxContainer.new()
    root_vbox.set("theme_override_constants/separation", 12)
    margin.add_child(root_vbox)

    var title = Label.new()
    title.text = "SHOP"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_vbox.add_child(title)

    _currency_label = Label.new()
    _update_currency_label()
    _currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_vbox.add_child(_currency_label)

    _items_container = HBoxContainer.new()
    _items_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _items_container.set("theme_override_constants/separation", 15)
    root_vbox.add_child(_items_container)

    _rebuild_items()

    var bottom_row = HBoxContainer.new()
    bottom_row.set("theme_override_constants/separation", 20)
    bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
    root_vbox.add_child(bottom_row)

    var heal_cost = _get_heal_cost()
    var heal_btn = Button.new()
    heal_btn.text = "Heal to Full (%d)" % heal_cost
    heal_btn.pressed.connect(_on_heal.bind(heal_btn))
    bottom_row.add_child(heal_btn)

    var reroll_btn = Button.new()
    reroll_btn.text = "Reroll (%d)" % _reroll_cost
    reroll_btn.pressed.connect(_on_reroll.bind(reroll_btn))
    bottom_row.add_child(reroll_btn)

    var continue_btn = Button.new()
    continue_btn.text = "Continue"
    continue_btn.pressed.connect(func(): shop_finished.emit())
    bottom_row.add_child(continue_btn)

func _rebuild_items() -> void:
    for child in _items_container.get_children():
        child.queue_free()

    var rarity_colors = ThemeManager.active_theme.rarity_colors
    var loop = RunManager.stats.loop if RunManager else 0
    var price_mult = 1.0 + (0.5 * loop)

    for i in range(_items.size()):
        var upgrade = _items[i]
        var price = int(upgrade.cost * price_mult)

        var panel = PanelContainer.new()
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _items_container.add_child(panel)

        var vbox = VBoxContainer.new()
        vbox.set("theme_override_constants/separation", 6)
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

        var buy_btn = Button.new()
        buy_btn.text = "Buy (%d)" % price
        buy_btn.pressed.connect(_on_buy.bind(i, price, buy_btn))
        if RunManager and RunManager.currency < price:
            buy_btn.disabled = true
        vbox.add_child(buy_btn)

func _on_buy(index: int, price: int, _btn: Button) -> void:
    if not RunManager or not RunManager.spend_currency(price):
        return
    var upgrade = _items[index]
    RunManager.active_upgrades.append(upgrade)
    _items.remove_at(index)
    _update_currency_label()
    _rebuild_items()

func _on_heal(btn: Button) -> void:
    var cost = _get_heal_cost()
    if not RunManager or not RunManager.spend_currency(cost):
        return
    btn.disabled = true
    btn.text = "Healed!"
    _update_currency_label()

func _on_reroll(btn: Button) -> void:
    if not RunManager or not RunManager.spend_currency(_reroll_cost):
        return
    _reroll_cost += 25
    btn.text = "Reroll (%d)" % _reroll_cost
    _items = UpgradeData.roll_random(5, RunManager.stats.loop if RunManager else 0)
    _update_currency_label()
    _rebuild_items()

func _update_currency_label() -> void:
    _currency_label.text = "Currency: %d" % (RunManager.currency if RunManager else 0)

func _get_heal_cost() -> int:
    var loop = RunManager.stats.loop if RunManager else 0
    return 50 + (25 * loop)
