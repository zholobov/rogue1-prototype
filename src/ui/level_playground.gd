class_name LevelPlayground
extends Control

signal back_pressed()

var _config_editor: ConfigEditor
var _grid_preview: GridPreview
var _generate_btn: Button
var _error_label: Label
var _preview_3d_btn: Button
var _back_to_2d_btn: Button
var _viewport_container: SubViewportContainer
var _right_panel: VBoxContainer
var _current_grid: Array = []
var _current_params: Dictionary = {}
var _is_3d_mode: bool = false
var _level_builder: LevelBuilder  # Lazy init on first 3D preview
var _level_generator: LevelGenerator
var _stale: bool = false

const LEFT_WIDTH = 240

func _ready() -> void:
    # Parent is Node (not Control), so anchors resolve to 0. Set size explicitly.
    size = get_viewport().get_visible_rect().size
    get_viewport().size_changed.connect(func(): size = get_viewport().get_visible_rect().size)
    _build_ui()

func _build_ui() -> void:
    var active_theme = ThemeManager.active_theme
    var btn_font_size = 11

    # Background — fills viewport via anchors
    var bg = ColorRect.new()
    bg.color = active_theme.ui_background_color
    bg.set_anchors_preset(PRESET_FULL_RECT)
    bg.mouse_filter = MOUSE_FILTER_IGNORE
    add_child(bg)

    # Top bar — anchored top-wide
    var top_bar = HBoxContainer.new()
    top_bar.set_anchors_preset(PRESET_TOP_WIDE)
    top_bar.offset_left = 10
    top_bar.offset_top = 8
    top_bar.offset_right = -10
    top_bar.offset_bottom = 34
    add_child(top_bar)

    var title = Label.new()
    title.text = "LEVEL GENERATOR PLAYGROUND"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 14)
    title.add_theme_color_override("font_color", active_theme.ui_accent_color)
    top_bar.add_child(title)

    var back_btn = Button.new()
    back_btn.text = "Back"
    back_btn.add_theme_font_size_override("font_size", btn_font_size)
    back_btn.pressed.connect(func(): back_pressed.emit())
    top_bar.add_child(back_btn)

    # Left panel — anchored: left edge, top to bottom, fixed width
    var left_vbox = VBoxContainer.new()
    left_vbox.anchor_left = 0.0
    left_vbox.anchor_top = 0.0
    left_vbox.anchor_right = 0.0
    left_vbox.anchor_bottom = 1.0
    left_vbox.offset_left = 10
    left_vbox.offset_top = 40
    left_vbox.offset_right = 10 + LEFT_WIDTH
    left_vbox.offset_bottom = -10
    left_vbox.add_theme_constant_override("separation", 4)
    add_child(left_vbox)

    _config_editor = ConfigEditor.new()
    _config_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var sections = _build_sections()
    _config_editor.setup(sections)
    _config_editor.property_changed.connect(_on_property_changed)
    left_vbox.add_child(_config_editor)

    # Action buttons
    var btn_vbox = VBoxContainer.new()
    btn_vbox.add_theme_constant_override("separation", 2)
    left_vbox.add_child(btn_vbox)

    _generate_btn = Button.new()
    _generate_btn.text = "Generate"
    _generate_btn.add_theme_font_size_override("font_size", btn_font_size)
    _generate_btn.pressed.connect(_on_generate)
    btn_vbox.add_child(_generate_btn)

    var random_btn = Button.new()
    random_btn.text = "Randomize Seed"
    random_btn.add_theme_font_size_override("font_size", btn_font_size)
    random_btn.pressed.connect(_on_randomize_seed)
    btn_vbox.add_child(random_btn)

    var clipboard_row = HBoxContainer.new()
    clipboard_row.add_theme_constant_override("separation", 4)
    btn_vbox.add_child(clipboard_row)

    var copy_btn = Button.new()
    copy_btn.text = "Copy"
    copy_btn.add_theme_font_size_override("font_size", btn_font_size)
    copy_btn.pressed.connect(func(): _config_editor.copy_to_clipboard())
    copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clipboard_row.add_child(copy_btn)

    var paste_btn = Button.new()
    paste_btn.text = "Paste"
    paste_btn.add_theme_font_size_override("font_size", btn_font_size)
    paste_btn.pressed.connect(_on_paste_params)
    paste_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clipboard_row.add_child(paste_btn)

    var reset_btn = Button.new()
    reset_btn.text = "Reset All"
    reset_btn.add_theme_font_size_override("font_size", btn_font_size)
    reset_btn.pressed.connect(func():
        _config_editor.reset_all()
        _stale = true
        _generate_btn.text = "Generate *"
    )
    btn_vbox.add_child(reset_btn)

    # Right panel — anchored: from left panel edge to right edge, top to bottom
    _right_panel = VBoxContainer.new()
    _right_panel.anchor_left = 0.0
    _right_panel.anchor_top = 0.0
    _right_panel.anchor_right = 1.0
    _right_panel.anchor_bottom = 1.0
    _right_panel.offset_left = LEFT_WIDTH + 18
    _right_panel.offset_top = 40
    _right_panel.offset_right = -10
    _right_panel.offset_bottom = -10
    _right_panel.add_theme_constant_override("separation", 4)
    add_child(_right_panel)

    _grid_preview = GridPreview.new()
    _grid_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _right_panel.add_child(_grid_preview)

    _error_label = Label.new()
    _error_label.text = ""
    _error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    _error_label.add_theme_font_size_override("font_size", 11)
    _error_label.visible = false
    _right_panel.add_child(_error_label)

    # Bottom bar for 3D toggle
    var bottom_bar = HBoxContainer.new()
    bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom_bar.add_theme_constant_override("separation", 8)
    _right_panel.add_child(bottom_bar)

    _preview_3d_btn = Button.new()
    _preview_3d_btn.text = "Preview 3D"
    _preview_3d_btn.add_theme_font_size_override("font_size", btn_font_size)
    _preview_3d_btn.pressed.connect(_on_preview_3d)
    _preview_3d_btn.disabled = true
    bottom_bar.add_child(_preview_3d_btn)

    _back_to_2d_btn = Button.new()
    _back_to_2d_btn.text = "Back to 2D"
    _back_to_2d_btn.add_theme_font_size_override("font_size", btn_font_size)
    _back_to_2d_btn.pressed.connect(_on_back_to_2d)
    _back_to_2d_btn.visible = false
    bottom_bar.add_child(_back_to_2d_btn)

    # Auto-generate on open
    _on_generate()

func _build_sections() -> Array:
    # Auto-discover all Config properties from @export annotations
    var sections = ConfigSectionBuilder.from_object(Config)

    # Add tile weights (derived from TileRules, not a Config property)
    var modifier = Config.current_modifier if Config.current_modifier != "" else Modifiers.NORMAL
    var weights = TileRules.get_profile_weights(modifier)
    sections.append({
        "title": "Tile Weights",
        "properties": [
            {"label": "Room", "key": "w_room", "type": "float", "value": weights.room, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
            {"label": "Spawn", "key": "w_spawn", "type": "float", "value": weights.spawn, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
            {"label": "Corridor", "key": "w_cor", "type": "float", "value": weights.cor, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
            {"label": "Door", "key": "w_door", "type": "float", "value": weights.door, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
            {"label": "Wall", "key": "w_wall", "type": "float", "value": weights.wall, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
            {"label": "Empty", "key": "w_empty", "type": "float", "value": weights.empty, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
        ]
    })

    # Add theme visual props (from ThemeData, not Config)
    var active_theme = ThemeManager.active_theme
    sections.append({
        "title": "Theme Props",
        "properties": [
            {"label": "Prop Density", "key": "prop_density", "type": "float", "value": active_theme.prop_density, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
            {"label": "Pillar Chance", "key": "pillar_chance", "type": "float", "value": active_theme.pillar_chance, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
            {"label": "Rubble Chance", "key": "rubble_chance", "type": "float", "value": active_theme.rubble_chance, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
            {"label": "Beam Spacing", "key": "ceiling_beam_spacing", "type": "int", "value": active_theme.ceiling_beam_spacing, "min_value": 1, "max_value": 10, "step": 1, "options": []},
            {"label": "Light Spacing", "key": "point_light_spacing", "type": "int", "value": active_theme.point_light_spacing, "min_value": 1, "max_value": 10, "step": 1, "options": []},
            {"label": "Prop Min", "key": "room_prop_min", "type": "int", "value": active_theme.room_prop_min, "min_value": 0, "max_value": 5, "step": 1, "options": []},
            {"label": "Prop Max", "key": "room_prop_max", "type": "int", "value": active_theme.room_prop_max, "min_value": 0, "max_value": 10, "step": 1, "options": []},
        ]
    })

    return sections

func _on_property_changed(key: String, value: Variant) -> void:
    if not _stale:
        _stale = true
        _generate_btn.text = "Generate *"

    # When modifier changes, reset tile weights to profile defaults
    if key == "current_modifier":
        var weights = TileRules.get_profile_weights(str(value))
        _config_editor.set_property_value("w_room", weights.room)
        _config_editor.set_property_value("w_spawn", weights.spawn)
        _config_editor.set_property_value("w_cor", weights.cor)
        _config_editor.set_property_value("w_door", weights.door)
        _config_editor.set_property_value("w_wall", weights.wall)
        _config_editor.set_property_value("w_empty", weights.empty)

func _on_generate() -> void:
    _current_params = _config_editor.get_values()

    # Seed handling: 0 = random
    var seed_val = int(_current_params.get("level_seed", 0))
    if seed_val == 0:
        seed_val = randi() % 999999 + 1
        _config_editor.set_property_value("level_seed", seed_val)
        _current_params["level_seed"] = seed_val

    var width = int(_current_params.get("level_grid_width", 12))
    var height = int(_current_params.get("level_grid_height", 12))

    # Build local TileRules with custom weights
    var modifier = str(_current_params.get("current_modifier", Modifiers.NORMAL))
    var rules = TileRules.new()
    rules.setup_profile(modifier)
    # Override individual tile weights from editor
    var weight_keys = {"w_room": "room", "w_spawn": "spawn", "w_cor": "corridor_h", "w_door": "door", "w_wall": "wall", "w_empty": "empty"}
    for w_key in weight_keys:
        var tile_name = weight_keys[w_key]
        if _current_params.has(w_key) and rules.tiles.has(tile_name):
            rules.tiles[tile_name].weight = float(_current_params[w_key])
    # corridor_v uses same weight as corridor_h (both from "cor")
    if _current_params.has("w_cor") and rules.tiles.has("corridor_v"):
        rules.tiles["corridor_v"].weight = float(_current_params["w_cor"])

    # Reuse LevelGenerator for the full pipeline (WFC + post-processing)
    if not _level_generator:
        _level_generator = LevelGenerator.new()
    var grid = _level_generator.generate_grid(rules, width, height, seed_val, modifier)
    _current_grid = grid

    # Check for empty/bad generation
    var has_walkable = false
    for row in grid:
        for cell in row:
            if cell in ["room", "spawn", "corridor_h", "corridor_v", "door"]:
                has_walkable = true
                break
        if has_walkable:
            break

    if not has_walkable:
        _error_label.text = "Generation produced no walkable area. Try different parameters."
        _error_label.visible = true
    else:
        _error_label.visible = false

    _grid_preview.set_grid(grid)
    _preview_3d_btn.disabled = false
    _stale = false
    _generate_btn.text = "Generate"

    # If 3D mode is active, rebuild
    if _is_3d_mode:
        _rebuild_3d_preview()

func _on_paste_params() -> void:
    _config_editor.paste_from_clipboard()
    _stale = true
    _generate_btn.text = "Generate *"

func _on_randomize_seed() -> void:
    var new_seed = randi() % 999999 + 1
    _config_editor.set_property_value("level_seed", new_seed)
    _on_generate()

func _on_preview_3d() -> void:
    if _current_grid.is_empty():
        return
    _is_3d_mode = true
    _grid_preview.visible = false
    _preview_3d_btn.visible = false
    _back_to_2d_btn.visible = true
    _rebuild_3d_preview()

func _on_back_to_2d() -> void:
    _is_3d_mode = false
    _grid_preview.visible = true
    _preview_3d_btn.visible = true
    _back_to_2d_btn.visible = false
    if _viewport_container:
        _viewport_container.queue_free()
        _viewport_container = null

func _rebuild_3d_preview() -> void:
    if _viewport_container:
        _viewport_container.queue_free()
        _viewport_container = null

    if _current_grid.is_empty():
        return

    var params = _current_params
    var tile_size = float(params.get("level_tile_size", 4.0))
    var width = _current_grid[0].size() if _current_grid.size() > 0 else 0
    var height_val = _current_grid.size()

    # Lazy init builder
    if not _level_builder:
        _level_builder = LevelBuilder.new()

    # Build local TileRules for builder
    var modifier = str(params.get("current_modifier", Modifiers.NORMAL))
    var rules = TileRules.new()
    rules.setup_profile(modifier)

    var geometry = _level_builder.build(_current_grid, rules, tile_size)

    # SubViewport setup — fill right panel
    _viewport_container = SubViewportContainer.new()
    _viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _viewport_container.stretch = true
    _right_panel.add_child(_viewport_container)
    _right_panel.move_child(_viewport_container, 0)

    var viewport = SubViewport.new()
    viewport.own_world_3d = true
    viewport.size = Vector2i(800, 600)
    _viewport_container.add_child(viewport)

    viewport.add_child(geometry)

    # Orthographic camera
    var camera = Camera3D.new()
    var center_x = width * tile_size / 2.0
    var center_z = height_val * tile_size / 2.0
    camera.position = Vector3(center_x, 50.0, center_z)
    camera.rotation_degrees = Vector3(-90, 0, 0)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = max(width, height_val) * tile_size * 1.1
    camera.near = 0.1
    camera.far = 200.0
    viewport.add_child(camera)

    # Directional light
    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-60, 30, 0)
    light.light_energy = 1.5
    viewport.add_child(light)

    # World environment
    var active_theme = ThemeManager.active_theme
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = active_theme.background_color
    env.ambient_light_color = active_theme.ambient_color
    env.ambient_light_energy = active_theme.ambient_energy
    var world_env = WorldEnvironment.new()
    world_env.environment = env
    viewport.add_child(world_env)


# ===== GridPreview inner class =====

class GridPreview extends Control:
    var _grid: Array = []

    const TILE_COLORS = {
        "room": Color(0.2, 0.6, 0.2),
        "spawn": Color(0.2, 0.7, 0.7),
        "corridor_h": Color(0.7, 0.65, 0.2),
        "corridor_v": Color(0.7, 0.65, 0.2),
        "door": Color(0.8, 0.5, 0.15),
        "wall": Color(0.2, 0.2, 0.2),
        "empty": Color(0.05, 0.05, 0.05),
    }

    const LEGEND_LABELS = ["room", "spawn", "corridor", "door", "wall", "empty"]
    const LEGEND_KEYS = ["room", "spawn", "corridor_h", "door", "wall", "empty"]

    func set_grid(grid: Array) -> void:
        _grid = grid
        queue_redraw()

    func _draw() -> void:
        if _grid.is_empty():
            return

        var grid_h = _grid.size()
        var grid_w = _grid[0].size() if grid_h > 0 else 0
        if grid_w == 0:
            return

        var avail = size
        var cell_size = minf(avail.x / grid_w, avail.y / grid_h)
        var offset_x = (avail.x - grid_w * cell_size) / 2.0
        var offset_y = (avail.y - grid_h * cell_size) / 2.0

        # Draw tiles
        for y in range(grid_h):
            for x in range(grid_w):
                var tile = _grid[y][x]
                var color = TILE_COLORS.get(tile, Color(0.1, 0.0, 0.1))
                var rect = Rect2(offset_x + x * cell_size, offset_y + y * cell_size, cell_size, cell_size)
                draw_rect(rect, color)

        # Grid lines
        var line_color = Color(1, 1, 1, 0.1)
        for x in range(grid_w + 1):
            var px = offset_x + x * cell_size
            draw_line(Vector2(px, offset_y), Vector2(px, offset_y + grid_h * cell_size), line_color, 1.0)
        for y in range(grid_h + 1):
            var py = offset_y + y * cell_size
            draw_line(Vector2(offset_x, py), Vector2(offset_x + grid_w * cell_size, py), line_color, 1.0)

        # Legend (top-right corner)
        var legend_x = avail.x - 110
        var legend_y = 10.0
        for i in range(LEGEND_LABELS.size()):
            var color = TILE_COLORS.get(LEGEND_KEYS[i], Color.WHITE)
            draw_rect(Rect2(legend_x, legend_y + i * 18, 12, 12), color)
            draw_string(ThemeDB.fallback_font, Vector2(legend_x + 18, legend_y + i * 18 + 11), LEGEND_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
