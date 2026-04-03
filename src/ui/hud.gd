extends Control

var _local_player: PlayerEntity

# --- Health bar ---
var _health_container: Control
var _health_title: Label
var _health_bar_bg: ColorRect
var _health_bar_fill: ColorRect
var _health_label: Label

# --- Weapon panel ---
var _weapon_container: Control
var _weapon_panel_bg: ColorRect
var _weapon_title: Label
var _weapon_name_label: Label
var _weapon_element_label: Label
var _weapon_icon: Control
var _last_hud_weapon_index: int = -1
var _weapon_slots: Array[ColorRect] = []
var _weapon_slot_labels: Array[Label] = []

# --- Abilities ---
var _ability_container: HBoxContainer
var _ability_dash: AbilityIndicator
var _ability_aoe: AbilityIndicator
var _ability_life: AbilityIndicator

# --- Crosshair ---
var _crosshair: CrosshairManager

# --- Kill feed ---
var _kill_feed_container: VBoxContainer

# --- Boss bar ---
var _boss_container: Control
var _boss_name_label: Label
var _boss_bar_bg: ColorRect
var _boss_bar_fill: ColorRect
var _boss_entity: Entity

# --- Minimap ---
var _minimap: Minimap

# --- FPS counter ---
var _fps_label: Label

# --- Pause menu ---
var _pause_menu: PanelContainer
var _pause_visible: bool = false

# --- Config panel ---
var _config_panel: PanelContainer
var _config_editor: ConfigEditor
var _config_visible: bool = false
var _config_keys: Dictionary = {}  # cached set of valid Config property names

# --- Damage flash ---
var _damage_flash: ColorRect

var _prev_health: int = -1
var _damage_flash_tween: Tween

func _ready() -> void:
    _build_damage_flash()
    _build_health_bar()
    _build_weapon_panel()
    _build_ability_indicators()
    _build_crosshair()
    _build_kill_feed()
    _build_boss_bar()
    _build_minimap()
    _build_fps_counter()
    _build_pause_menu()
    _build_config_panel()
    _apply_theme()
    ThemeManager.theme_changed.connect(_on_theme_changed)

# ========== BUILD ==========

func _build_damage_flash() -> void:
    _damage_flash = ColorRect.new()
    _damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    _damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _damage_flash.color = Color(1, 0, 0, 0)
    add_child(_damage_flash)

func _build_health_bar() -> void:
    _health_container = Control.new()
    _health_container.anchor_left = 0.0
    _health_container.anchor_top = 1.0
    _health_container.anchor_right = 0.0
    _health_container.anchor_bottom = 1.0
    _health_container.offset_left = 20
    _health_container.offset_top = -52
    _health_container.offset_right = 220
    _health_container.offset_bottom = -16
    _health_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_health_container)

    _health_title = Label.new()
    _health_title.text = "HEALTH"
    _health_title.position = Vector2(0, -16)
    _health_title.size = Vector2(200, 14)
    _health_title.add_theme_font_size_override("font_size", 10)
    _health_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _health_container.add_child(_health_title)

    _health_bar_bg = ColorRect.new()
    _health_bar_bg.position = Vector2(0, 0)
    _health_bar_bg.size = Vector2(200, 16)
    _health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _health_container.add_child(_health_bar_bg)

    _health_bar_fill = ColorRect.new()
    _health_bar_fill.position = Vector2(0, 0)
    _health_bar_fill.size = Vector2(200, 16)
    _health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _health_container.add_child(_health_bar_fill)

    _health_label = Label.new()
    _health_label.text = "100 / 100"
    _health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _health_label.position = Vector2(0, 0)
    _health_label.size = Vector2(200, 16)
    _health_label.add_theme_font_size_override("font_size", 11)
    _health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _health_container.add_child(_health_label)

func _build_weapon_panel() -> void:
    _weapon_container = Control.new()
    _weapon_container.anchor_left = 1.0
    _weapon_container.anchor_top = 1.0
    _weapon_container.anchor_right = 1.0
    _weapon_container.anchor_bottom = 1.0
    _weapon_container.offset_left = -220
    _weapon_container.offset_top = -90
    _weapon_container.offset_right = -20
    _weapon_container.offset_bottom = -16
    _weapon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_weapon_container)

    _weapon_title = Label.new()
    _weapon_title.text = "WEAPON"
    _weapon_title.position = Vector2(0, -16)
    _weapon_title.size = Vector2(200, 14)
    _weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _weapon_title.add_theme_font_size_override("font_size", 10)
    _weapon_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _weapon_container.add_child(_weapon_title)

    _weapon_panel_bg = ColorRect.new()
    _weapon_panel_bg.position = Vector2(0, 0)
    _weapon_panel_bg.size = Vector2(200, 74)
    _weapon_panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _weapon_container.add_child(_weapon_panel_bg)

    # Row 1: weapon icon (left) + name/element (right)
    _weapon_icon = Control.new()
    _weapon_icon.position = Vector2(6, 4)
    _weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _weapon_container.add_child(_weapon_icon)

    _weapon_name_label = Label.new()
    _weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _weapon_name_label.position = Vector2(80, 6)
    _weapon_name_label.size = Vector2(114, 18)
    _weapon_name_label.add_theme_font_size_override("font_size", 12)
    _weapon_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _weapon_container.add_child(_weapon_name_label)

    _weapon_element_label = Label.new()
    _weapon_element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _weapon_element_label.position = Vector2(80, 26)
    _weapon_element_label.size = Vector2(114, 16)
    _weapon_element_label.add_theme_font_size_override("font_size", 10)
    _weapon_element_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _weapon_container.add_child(_weapon_element_label)

    # Row 2: slot indicators
    for i in range(WeaponRegistry.weapon_count()):
        var slot_bg = ColorRect.new()
        slot_bg.position = Vector2(8 + i * 22, 52)
        slot_bg.size = Vector2(18, 18)
        slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _weapon_container.add_child(slot_bg)
        _weapon_slots.append(slot_bg)

        var slot_label = Label.new()
        slot_label.text = str(i + 1)
        slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        slot_label.position = Vector2(8 + i * 22, 52)
        slot_label.size = Vector2(18, 18)
        slot_label.add_theme_font_size_override("font_size", 9)
        slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _weapon_container.add_child(slot_label)
        _weapon_slot_labels.append(slot_label)

func _build_ability_indicators() -> void:
    _ability_container = HBoxContainer.new()
    _ability_container.anchor_left = 0.5
    _ability_container.anchor_top = 1.0
    _ability_container.anchor_right = 0.5
    _ability_container.anchor_bottom = 1.0
    _ability_container.offset_left = -90
    _ability_container.offset_top = -76
    _ability_container.offset_right = 90
    _ability_container.offset_bottom = -16
    _ability_container.alignment = BoxContainer.ALIGNMENT_CENTER
    _ability_container.add_theme_constant_override("separation", 12)
    _ability_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_ability_container)

    _ability_dash = AbilityIndicator.new()
    _ability_container.add_child(_ability_dash)
    _ability_dash.setup("DASH", 3.0)

    _ability_aoe = AbilityIndicator.new()
    _ability_container.add_child(_ability_aoe)
    _ability_aoe.setup("AOE", 8.0)

    _ability_life = AbilityIndicator.new()
    _ability_container.add_child(_ability_life)
    _ability_life.setup("LIFE", 0.0)

func _build_crosshair() -> void:
    _crosshair = CrosshairManager.new()
    add_child(_crosshair)

func _build_kill_feed() -> void:
    _kill_feed_container = VBoxContainer.new()
    _kill_feed_container.anchor_left = 1.0
    _kill_feed_container.anchor_top = 0.0
    _kill_feed_container.anchor_right = 1.0
    _kill_feed_container.anchor_bottom = 0.0
    _kill_feed_container.offset_left = -200
    _kill_feed_container.offset_top = 12
    _kill_feed_container.offset_right = -16
    _kill_feed_container.offset_bottom = 100
    _kill_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_kill_feed_container)

func _build_boss_bar() -> void:
    _boss_container = Control.new()
    _boss_container.anchor_left = 0.3
    _boss_container.anchor_top = 0.0
    _boss_container.anchor_right = 0.7
    _boss_container.anchor_bottom = 0.0
    _boss_container.offset_top = 12
    _boss_container.offset_bottom = 48
    _boss_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _boss_container.visible = false
    add_child(_boss_container)

    _boss_name_label = Label.new()
    _boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _boss_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _boss_name_label.offset_bottom = 16
    _boss_name_label.add_theme_font_size_override("font_size", 11)
    _boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _boss_container.add_child(_boss_name_label)

    _boss_bar_bg = ColorRect.new()
    _boss_bar_bg.anchor_left = 0.0
    _boss_bar_bg.anchor_right = 1.0
    _boss_bar_bg.offset_top = 18
    _boss_bar_bg.offset_bottom = 34
    _boss_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _boss_container.add_child(_boss_bar_bg)

    _boss_bar_fill = ColorRect.new()
    _boss_bar_fill.anchor_left = 0.0
    _boss_bar_fill.anchor_right = 1.0
    _boss_bar_fill.offset_top = 18
    _boss_bar_fill.offset_bottom = 34
    _boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _boss_container.add_child(_boss_bar_fill)

func _build_minimap() -> void:
    _minimap = Minimap.new()
    _minimap.position = Vector2(16, 12)
    add_child(_minimap)

func _build_fps_counter() -> void:
    _fps_label = Label.new()
    _fps_label.anchor_left = 0.0
    _fps_label.anchor_top = 0.0
    _fps_label.offset_left = 16
    _fps_label.offset_top = 138
    _fps_label.add_theme_font_size_override("font_size", 11)
    _fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_fps_label)

    var version_label = Label.new()
    version_label.text = VersionInfo.version_string
    version_label.anchor_left = 1.0
    version_label.anchor_top = 1.0
    version_label.anchor_right = 1.0
    version_label.anchor_bottom = 1.0
    version_label.offset_left = -200
    version_label.offset_top = -18
    version_label.offset_right = -8
    version_label.offset_bottom = -2
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    version_label.add_theme_font_size_override("font_size", 9)
    version_label.add_theme_color_override("font_color", Color(ThemeManager.active_theme.ui_text_color, 0.25))
    version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(version_label)

func _build_pause_menu() -> void:
    _pause_menu = PanelContainer.new()
    _pause_menu.set_anchors_preset(Control.PRESET_CENTER)
    _pause_menu.offset_left = -100
    _pause_menu.offset_right = 100
    _pause_menu.offset_top = -80
    _pause_menu.offset_bottom = 80
    _pause_menu.visible = false
    _pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
    style.set_corner_radius_all(6)
    _pause_menu.add_theme_stylebox_override("panel", style)
    add_child(_pause_menu)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    _pause_menu.add_child(vbox)

    var title = Label.new()
    title.text = "PAUSED"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", ThemeManager.active_theme.ui_accent_color)
    vbox.add_child(title)

    var resume_btn = Button.new()
    resume_btn.text = "Resume"
    resume_btn.pressed.connect(_on_pause_resume)
    vbox.add_child(resume_btn)

    var config_btn = Button.new()
    config_btn.text = "Config"
    config_btn.pressed.connect(_on_pause_config)
    vbox.add_child(config_btn)

    var exit_btn = Button.new()
    exit_btn.text = "Exit to Menu"
    exit_btn.pressed.connect(_on_pause_exit)
    vbox.add_child(exit_btn)

func _toggle_pause_menu() -> void:
    _pause_visible = not _pause_visible
    _pause_menu.visible = _pause_visible
    if _pause_visible:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        GameLog.block_input()
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        GameLog.unblock_input()
        # Also close config if open
        if _config_visible:
            _config_visible = false
            _config_panel.visible = false
            GameLog.unblock_input()

func _on_pause_resume() -> void:
    _toggle_pause_menu()

func _on_pause_config() -> void:
    _pause_visible = false
    _pause_menu.visible = false
    GameLog.unblock_input()  # pause closing
    _config_visible = true
    _config_panel.visible = true
    GameLog.block_input()  # config opening

func _on_pause_exit() -> void:
    _pause_visible = false
    _pause_menu.visible = false
    GameLog.unblock_input()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if RunManager:
        RunManager.return_to_lobby()

func _build_config_panel() -> void:
    # Semi-transparent panel on the right side, toggled with Tab
    _config_panel = PanelContainer.new()
    _config_panel.anchor_left = 1.0
    _config_panel.anchor_top = 0.0
    _config_panel.anchor_right = 1.0
    _config_panel.anchor_bottom = 1.0
    _config_panel.offset_left = -300
    _config_panel.offset_top = 10
    _config_panel.offset_right = -10
    _config_panel.offset_bottom = -10
    _config_panel.visible = false
    _config_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
    style.set_corner_radius_all(4)
    _config_panel.add_theme_stylebox_override("panel", style)
    add_child(_config_panel)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    _config_panel.add_child(vbox)

    var header = Label.new()
    header.text = "CONFIG [Esc to close]"
    header.add_theme_font_size_override("font_size", 12)
    header.add_theme_color_override("font_color", ThemeManager.active_theme.ui_accent_color)
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(header)

    # Cache valid Config property names for fast lookup
    for prop in Config.get_property_list():
        if prop.usage & PROPERTY_USAGE_EDITOR:
            _config_keys[prop.name] = true

    _config_editor = ConfigEditor.new()
    _config_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var sections = ConfigSectionBuilder.from_object(Config)
    _config_editor.setup(sections)
    _config_editor.property_changed.connect(_on_config_changed)
    vbox.add_child(_config_editor)

    var btn_row = HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 4)
    vbox.add_child(btn_row)

    var copy_btn = Button.new()
    copy_btn.text = "Copy"
    copy_btn.add_theme_font_size_override("font_size", 10)
    copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy_btn.pressed.connect(func(): _config_editor.copy_to_clipboard())
    btn_row.add_child(copy_btn)

    var paste_btn = Button.new()
    paste_btn.text = "Paste"
    paste_btn.add_theme_font_size_override("font_size", 10)
    paste_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    paste_btn.pressed.connect(func():
        _config_editor.paste_from_clipboard()
    )
    btn_row.add_child(paste_btn)

    var reset_btn = Button.new()
    reset_btn.text = "Reset"
    reset_btn.add_theme_font_size_override("font_size", 10)
    reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset_btn.pressed.connect(func(): _config_editor.reset_all())
    btn_row.add_child(reset_btn)

func _on_config_changed(key: String, value: Variant) -> void:
    if _config_keys.has(key):
        Config.set(key, value)

func _toggle_config_panel() -> void:
    _config_visible = not _config_visible
    _config_panel.visible = _config_visible
    if _config_visible:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    else:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed:
        return
    if event.physical_keycode == KEY_ESCAPE:
        if _config_visible:
            # Close config, show pause menu
            _config_visible = false
            _config_panel.visible = false
            GameLog.unblock_input()  # config closing
            _pause_visible = true
            _pause_menu.visible = true
            GameLog.block_input()  # pause opening
            get_viewport().set_input_as_handled()
        elif _pause_visible:
            # Close pause menu, resume game
            _toggle_pause_menu()
            get_viewport().set_input_as_handled()
        elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
            # Mouse free (player released it) — show pause menu
            _pause_visible = true
            _pause_menu.visible = true
            GameLog.block_input()
            get_viewport().set_input_as_handled()

# ========== PUBLIC API ==========

func setup_minimap(level_data: Dictionary) -> void:
    _minimap.setup(level_data)

func show_boss_bar(boss_entity: Entity) -> void:
    _boss_entity = boss_entity
    _boss_container.visible = true
    _boss_name_label.text = "DUNGEON BOSS"

func on_actor_died(entity: Entity) -> void:
    var tag := entity.get_component(C_ActorTag) as C_ActorTag
    if not tag or tag.actor_type != C_ActorTag.ActorType.MONSTER:
        return
    var feed_text = "Defeated Boss" if entity.get_component(C_BossAI) else "Defeated Enemy"
    _add_kill_feed_entry(feed_text)

# ========== PROCESS ==========

func _process(_delta: float) -> void:
    if not is_instance_valid(_local_player):
        _local_player = null
        for player in get_tree().get_nodes_in_group("players"):
            if player is PlayerEntity:
                var net_id = player.get_component(C_NetworkIdentity)
                if net_id and net_id.is_local:
                    _local_player = player
                    break
    if _local_player:
        _update_health(_local_player)
        _update_weapon(_local_player)
        _update_abilities(_local_player)
        _update_crosshair(_local_player)
    _update_boss_bar()
    _fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _update_health(player: PlayerEntity) -> void:
    var health = player.get_component(C_Health)
    if not health:
        return
    var current = health.current_health
    var max_hp = health.max_health
    _health_label.text = "%d / %d" % [current, max_hp]

    var ratio = float(current) / float(maxi(max_hp, 1))
    _health_bar_fill.size.x = _health_bar_bg.size.x * ratio

    var active_theme = ThemeManager.active_theme
    _health_bar_fill.color = active_theme.health_bar_foreground.lerp(active_theme.health_bar_low_color, 1.0 - ratio)

    if _prev_health >= 0 and current < _prev_health:
        _trigger_damage_flash()
    _prev_health = current

func _update_weapon(player: PlayerEntity) -> void:
    var weapon = player.get_component(C_Weapon)
    if not weapon:
        return
    var idx = player._current_weapon_index
    var active_theme = ThemeManager.active_theme

    for i in range(_weapon_slots.size()):
        if i == idx:
            _weapon_slots[i].color = active_theme.ui_accent_color
            _weapon_slot_labels[i].add_theme_color_override("font_color", active_theme.ui_background_color)
        else:
            _weapon_slots[i].color = active_theme.ui_panel_color
            _weapon_slot_labels[i].add_theme_color_override("font_color", active_theme.ui_text_color)

    var preset_name = "Custom"
    var weapon_def = WeaponRegistry.get_weapon(idx)
    if weapon_def:
        preset_name = weapon_def.weapon_name
    _weapon_name_label.text = preset_name
    _weapon_element_label.text = weapon.element if weapon.element != "" else "Standard"

    if idx != _last_hud_weapon_index:
        _last_hud_weapon_index = idx
        for child in _weapon_icon.get_children():
            child.queue_free()
        var wd = WeaponRegistry.get_weapon(idx)
        if wd:
            var new_icon = wd.build_hud_icon.call()
            if new_icon:
                _weapon_icon.add_child(new_icon)

func _update_abilities(player: PlayerEntity) -> void:
    var dash = player.get_component(C_Dash)
    if dash:
        _ability_dash.visible = true
        _ability_dash.update_state(dash.cooldown_remaining)
    else:
        _ability_dash.visible = false

    var aoe = player.get_component(C_AoEBlast)
    if aoe:
        _ability_aoe.visible = true
        _ability_aoe.update_state(aoe.cooldown_remaining)
    else:
        _ability_aoe.visible = false

    var lifesteal = player.get_component(C_Lifesteal)
    if lifesteal:
        _ability_life.visible = true
        _ability_life.update_state(0.0, true)
    else:
        _ability_life.visible = false

func _update_crosshair(player: PlayerEntity) -> void:
    var weapon = player.get_component(C_Weapon)
    if weapon:
        _crosshair.set_weapon(player._current_weapon_index, weapon.element)

func _update_boss_bar() -> void:
    if not _boss_container.visible or not _boss_entity:
        return
    if not is_instance_valid(_boss_entity):
        _boss_container.visible = false
        _boss_entity = null
        return
    var health = _boss_entity.get_component(C_Health)
    if not health or health.current_health <= 0:
        _boss_container.visible = false
        _boss_entity = null
        return
    var ratio = float(health.current_health) / float(maxi(health.max_health, 1))
    _boss_bar_fill.anchor_right = ratio
    var active_theme = ThemeManager.active_theme
    _boss_bar_fill.color = active_theme.health_bar_foreground.lerp(active_theme.health_bar_low_color, 1.0 - ratio)

# ========== KILL FEED ==========

func _add_kill_feed_entry(entry_text: String) -> void:
    var active_theme = ThemeManager.active_theme
    var label = Label.new()
    label.text = entry_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", active_theme.ui_kill_feed_color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _kill_feed_container.add_child(label)
    _kill_feed_container.move_child(label, 0)

    while _kill_feed_container.get_child_count() > 4:
        var old = _kill_feed_container.get_child(_kill_feed_container.get_child_count() - 1)
        old.queue_free()

    var tween = create_tween()
    tween.tween_interval(3.0)
    tween.tween_property(label, "modulate:a", 0.0, 1.0)
    tween.tween_callback(label.queue_free)

# ========== DAMAGE FLASH ==========

func _trigger_damage_flash() -> void:
    if _damage_flash_tween:
        _damage_flash_tween.kill()
    _damage_flash.color = ThemeManager.active_theme.ui_damage_flash_color
    _damage_flash_tween = create_tween()
    _damage_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.15)

# ========== THEME ==========

func _on_theme_changed(_theme: ThemeData) -> void:
    _apply_theme()

func _apply_theme() -> void:
    var active_theme = ThemeManager.active_theme

    _health_bar_bg.color = active_theme.health_bar_background
    _health_label.add_theme_color_override("font_color", active_theme.ui_text_color)
    _health_title.add_theme_color_override("font_color", Color(active_theme.ui_text_color, 0.6))

    _weapon_panel_bg.color = active_theme.ui_panel_color
    _weapon_title.add_theme_color_override("font_color", Color(active_theme.ui_text_color, 0.6))
    _weapon_name_label.add_theme_color_override("font_color", active_theme.ui_text_color)
    _weapon_element_label.add_theme_color_override("font_color", Color(active_theme.ui_text_color, 0.7))

    _boss_name_label.add_theme_color_override("font_color", active_theme.ui_accent_color)
    _boss_bar_bg.color = active_theme.health_bar_background

    _ability_dash.apply_theme()
    _ability_aoe.apply_theme()
    _ability_life.apply_theme()
    _crosshair.apply_theme()
    _minimap.apply_theme()
    _fps_label.add_theme_color_override("font_color", Color(active_theme.ui_text_color, 0.5))
