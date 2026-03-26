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
var _current_grid: Array = []
var _current_params: Dictionary = {}
var _is_3d_mode: bool = false
var _level_builder: LevelBuilder  # Lazy init on first 3D preview
var _stale: bool = false

func _ready() -> void:
    set_anchors_preset(PRESET_FULL_RECT)
    _build_ui()

func _build_ui() -> void:
    var theme = ThemeManager.active_theme

    # Background
    var bg = ColorRect.new()
    bg.color = theme.ui_background_color
    bg.set_anchors_preset(PRESET_FULL_RECT)
    bg.mouse_filter = MOUSE_FILTER_IGNORE
    add_child(bg)

    # Top bar
    var top_bar = HBoxContainer.new()
    top_bar.set_anchors_preset(PRESET_TOP_WIDE)
    top_bar.offset_top = 8
    top_bar.offset_bottom = 36
    top_bar.offset_left = 16
    top_bar.offset_right = -16
    add_child(top_bar)

    var title = Label.new()
    title.text = "LEVEL GENERATOR PLAYGROUND"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", theme.ui_accent_color)
    top_bar.add_child(title)

    var back_btn = Button.new()
    back_btn.text = "Back"
    back_btn.pressed.connect(func(): back_pressed.emit())
    top_bar.add_child(back_btn)

    # Main split: left panel + right panel
    var hsplit = HSplitContainer.new()
    hsplit.anchor_left = 0.0
    hsplit.anchor_top = 0.0
    hsplit.anchor_right = 1.0
    hsplit.anchor_bottom = 1.0
    hsplit.offset_top = 44
    hsplit.offset_left = 8
    hsplit.offset_right = -8
    hsplit.offset_bottom = -8
    hsplit.split_offset = 300
    add_child(hsplit)

    # Left panel: config editor + buttons
    var left_vbox = VBoxContainer.new()
    left_vbox.custom_minimum_size.x = 280
    left_vbox.add_theme_constant_override("separation", 6)
    hsplit.add_child(left_vbox)

    _config_editor = ConfigEditor.new()
    _config_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _config_editor.setup(_build_sections())
    _config_editor.property_changed.connect(_on_property_changed)
    left_vbox.add_child(_config_editor)

    # Action buttons
    var btn_vbox = VBoxContainer.new()
    btn_vbox.add_theme_constant_override("separation", 4)
    left_vbox.add_child(btn_vbox)

    _generate_btn = Button.new()
    _generate_btn.text = "Generate"
    _generate_btn.pressed.connect(_on_generate)
    btn_vbox.add_child(_generate_btn)

    var random_btn = Button.new()
    random_btn.text = "Randomize Seed"
    random_btn.pressed.connect(_on_randomize_seed)
    btn_vbox.add_child(random_btn)

    # Right panel: visualization area
    var right_panel = VBoxContainer.new()
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.add_theme_constant_override("separation", 4)
    hsplit.add_child(right_panel)

    _grid_preview = GridPreview.new()
    _grid_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.add_child(_grid_preview)

    _error_label = Label.new()
    _error_label.text = ""
    _error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
    _error_label.add_theme_font_size_override("font_size", 12)
    _error_label.visible = false
    right_panel.add_child(_error_label)

    # Bottom bar for 3D toggle
    var bottom_bar = HBoxContainer.new()
    bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom_bar.add_theme_constant_override("separation", 12)
    right_panel.add_child(bottom_bar)

    _preview_3d_btn = Button.new()
    _preview_3d_btn.text = "Preview 3D"
    _preview_3d_btn.pressed.connect(_on_preview_3d)
    _preview_3d_btn.disabled = true
    bottom_bar.add_child(_preview_3d_btn)

    _back_to_2d_btn = Button.new()
    _back_to_2d_btn.text = "Back to 2D"
    _back_to_2d_btn.pressed.connect(_on_back_to_2d)
    _back_to_2d_btn.visible = false
    bottom_bar.add_child(_back_to_2d_btn)

    # Auto-generate on open
    _on_generate()

func _build_sections() -> Array:
    var theme = ThemeManager.active_theme
    var modifier = Config.current_modifier if Config.current_modifier != "" else "normal"
    var weights = TileRules.get_profile_weights(modifier)

    return [
        {
            "title": "Grid",
            "properties": [
                {"label": "Width", "key": "level_grid_width", "type": "int", "value": Config.level_grid_width, "min_value": 4, "max_value": 32, "step": 1, "options": []},
                {"label": "Height", "key": "level_grid_height", "type": "int", "value": Config.level_grid_height, "min_value": 4, "max_value": 32, "step": 1, "options": []},
                {"label": "Seed (0=random)", "key": "level_seed", "type": "int", "value": Config.level_seed, "min_value": 0, "max_value": 999999, "step": 1, "options": []},
                {"label": "Tile Size", "key": "level_tile_size", "type": "float", "value": Config.level_tile_size, "min_value": 1.0, "max_value": 10.0, "step": 0.5, "options": []},
            ]
        },
        {
            "title": "Modifier",
            "properties": [
                {"label": "Preset", "key": "current_modifier", "type": "string_enum", "value": modifier, "min_value": 0, "max_value": 0, "step": 0, "options": PackedStringArray(["normal", "dense", "large", "dark", "horde", "boss"])},
            ]
        },
        {
            "title": "Tile Weights",
            "properties": [
                {"label": "Room", "key": "w_room", "type": "float", "value": weights.room, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Spawn", "key": "w_spawn", "type": "float", "value": weights.spawn, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Corridor", "key": "w_cor", "type": "float", "value": weights.cor, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Door", "key": "w_door", "type": "float", "value": weights.door, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Wall", "key": "w_wall", "type": "float", "value": weights.wall, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Empty", "key": "w_empty", "type": "float", "value": weights.empty, "min_value": 0.0, "max_value": 10.0, "step": 0.1, "options": []},
            ]
        },
        {
            "title": "Monsters",
            "properties": [
                {"label": "Per Room", "key": "monsters_per_room", "type": "int", "value": Config.monsters_per_room, "min_value": 0, "max_value": 10, "step": 1, "options": []},
                {"label": "Max/Level (0=∞)", "key": "max_monsters_per_level", "type": "int", "value": Config.max_monsters_per_level, "min_value": 0, "max_value": 50, "step": 1, "options": []},
                {"label": "HP Mult", "key": "monster_hp_mult", "type": "float", "value": Config.monster_hp_mult, "min_value": 0.1, "max_value": 10.0, "step": 0.1, "options": []},
                {"label": "Damage Mult", "key": "monster_damage_mult", "type": "float", "value": Config.monster_damage_mult, "min_value": 0.1, "max_value": 10.0, "step": 0.1, "options": []},
            ]
        },
        {
            "title": "Lighting",
            "properties": [
                {"label": "Range Mult", "key": "light_range_mult", "type": "float", "value": Config.light_range_mult, "min_value": 0.1, "max_value": 5.0, "step": 0.1, "options": []},
                {"label": "Spacing", "key": "point_light_spacing", "type": "int", "value": theme.point_light_spacing, "min_value": 1, "max_value": 10, "step": 1, "options": []},
            ]
        },
        {
            "title": "Props",
            "properties": [
                {"label": "Density", "key": "prop_density", "type": "float", "value": theme.prop_density, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
                {"label": "Pillar Chance", "key": "pillar_chance", "type": "float", "value": theme.pillar_chance, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
                {"label": "Rubble Chance", "key": "rubble_chance", "type": "float", "value": theme.rubble_chance, "min_value": 0.0, "max_value": 1.0, "step": 0.05, "options": []},
                {"label": "Beam Spacing", "key": "ceiling_beam_spacing", "type": "int", "value": theme.ceiling_beam_spacing, "min_value": 1, "max_value": 10, "step": 1, "options": []},
                {"label": "Prop Min", "key": "room_prop_min", "type": "int", "value": theme.room_prop_min, "min_value": 0, "max_value": 5, "step": 1, "options": []},
                {"label": "Prop Max", "key": "room_prop_max", "type": "int", "value": theme.room_prop_max, "min_value": 0, "max_value": 10, "step": 1, "options": []},
            ]
        },
    ]

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
    var tile_size = float(_current_params.get("level_tile_size", 4.0))

    # Build local TileRules with custom weights
    var modifier = str(_current_params.get("current_modifier", "normal"))
    var rules = TileRules.new()
    rules.setup_profile(modifier)
    # Override individual tile weights
    var weight_keys = {"w_room": "room", "w_spawn": "spawn", "w_cor": "corridor_h", "w_door": "door", "w_wall": "wall", "w_empty": "empty"}
    for w_key in weight_keys:
        var tile_name = weight_keys[w_key]
        if _current_params.has(w_key) and rules.tiles.has(tile_name):
            rules.tiles[tile_name].weight = float(_current_params[w_key])
    # corridor_v uses same weight as corridor_h (both from "cor")
    if _current_params.has("w_cor") and rules.tiles.has("corridor_v"):
        rules.tiles["corridor_v"].weight = float(_current_params["w_cor"])

    # Run generation using local TileRules — bypass LevelGenerator to avoid Config mutation
    var solver = WFCSolver.new()
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_val

    var pinned = _generate_room_seeds(rng, width, height, modifier)
    var grid = solver.solve(rules, width, height, seed_val, pinned)

    # Post-processing — mirrors LevelGenerator pipeline (all 4 steps)
    _ensure_connectivity(grid)
    _remove_tiny_rooms(grid)
    _prune_dead_ends(grid)
    _seal_empty_borders(grid)
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
    var modifier = str(params.get("current_modifier", "normal"))
    var rules = TileRules.new()
    rules.setup_profile(modifier)

    var geometry = _level_builder.build(_current_grid, rules, tile_size)

    # SubViewport setup
    _viewport_container = SubViewportContainer.new()
    _viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _viewport_container.stretch = true
    _grid_preview.get_parent().add_child(_viewport_container)
    _grid_preview.get_parent().move_child(_viewport_container, 0)

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
    var theme = ThemeManager.active_theme
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = theme.background_color
    env.ambient_light_color = theme.ambient_color
    env.ambient_light_energy = theme.ambient_energy
    var world_env = WorldEnvironment.new()
    world_env.environment = env
    viewport.add_child(world_env)

# --- Room seed generation (mirrors LevelGenerator._generate_room_seeds) ---

func _generate_room_seeds(rng: RandomNumberGenerator, width: int, height: int, modifier: String) -> Dictionary:
    var pinned: Dictionary = {}
    var seeds: Array = []

    var room_count: int
    var min_dist: int
    match modifier:
        "dense":
            room_count = rng.randi_range(6, 9)
            min_dist = 3
        "large":
            room_count = rng.randi_range(3, 5)
            min_dist = 5
        "dark":
            room_count = rng.randi_range(5, 8)
            min_dist = 3
        "horde":
            room_count = rng.randi_range(3, 5)
            min_dist = 5
        "boss":
            var cx = width / 2
            var cy = height / 2
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    var px = cx + dx
                    var py = cy + dy
                    if px > 0 and px < width - 1 and py > 0 and py < height - 1:
                        if dx == 0 and dy == 0:
                            pinned[Vector2i(px, py)] = "spawn"
                        else:
                            pinned[Vector2i(px, py)] = "room"
            return pinned
        _:
            room_count = rng.randi_range(4, 7)
            min_dist = 4

    var attempts = 0
    while seeds.size() < room_count and attempts < 100:
        attempts += 1
        var x = rng.randi_range(2, width - 3)
        var y = rng.randi_range(2, height - 3)
        var too_close = false
        for s in seeds:
            if absi(x - s.x) + absi(y - s.y) < min_dist:
                too_close = true
                break
        if too_close:
            continue
        seeds.append(Vector2i(x, y))
        pinned[Vector2i(x, y)] = "spawn"

    return pinned

# --- Post-processing (mirrors LevelGenerator._ensure_connectivity) ---

func _ensure_connectivity(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var visited: Dictionary = {}
    var clusters: Array = []
    var walkable = ["room", "spawn", "corridor_h", "corridor_v", "door"]

    for y in range(h):
        for x in range(w):
            var key = Vector2i(x, y)
            if visited.has(key) or grid[y][x] not in walkable:
                continue
            var cluster: Array = []
            var stack: Array = [key]
            while not stack.is_empty():
                var cell = stack.pop_back()
                if visited.has(cell):
                    continue
                if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h:
                    continue
                if grid[cell.y][cell.x] not in walkable:
                    continue
                visited[cell] = true
                cluster.append(cell)
                stack.append(Vector2i(cell.x + 1, cell.y))
                stack.append(Vector2i(cell.x - 1, cell.y))
                stack.append(Vector2i(cell.x, cell.y + 1))
                stack.append(Vector2i(cell.x, cell.y - 1))
            if cluster.size() > 0:
                clusters.append(cluster)

    if clusters.size() <= 1:
        return
    clusters.sort_custom(func(a, b): return a.size() > b.size())
    var main_cluster = clusters[0]
    for i in range(1, clusters.size()):
        var small = clusters[i]
        var best_dist = 9999
        var best_main = Vector2i.ZERO
        var best_small = Vector2i.ZERO
        for mc in main_cluster:
            for sc in small:
                var dist = absi(mc.x - sc.x) + absi(mc.y - sc.y)
                if dist < best_dist:
                    best_dist = dist
                    best_main = mc
                    best_small = sc
        var cx = best_main.x
        var cy = best_main.y
        while cx != best_small.x:
            cx += 1 if best_small.x > cx else -1
            if cx > 0 and cx < w - 1 and grid[cy][cx] not in walkable:
                grid[cy][cx] = "corridor_h"
        while cy != best_small.y:
            cy += 1 if best_small.y > cy else -1
            if cy > 0 and cy < h - 1 and grid[cy][cx] not in walkable:
                grid[cy][cx] = "corridor_v"
        main_cluster.append_array(small)

func _remove_tiny_rooms(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var visited: Dictionary = {}
    var room_tiles = ["room", "spawn"]
    for y in range(h):
        for x in range(w):
            var key = Vector2i(x, y)
            if visited.has(key) or grid[y][x] not in room_tiles:
                continue
            var cluster: Array = []
            var has_spawn = false
            var stack: Array = [key]
            while not stack.is_empty():
                var cell = stack.pop_back()
                if visited.has(cell):
                    continue
                if cell.x < 0 or cell.x >= w or cell.y < 0 or cell.y >= h:
                    continue
                if grid[cell.y][cell.x] not in room_tiles:
                    continue
                visited[cell] = true
                cluster.append(cell)
                if grid[cell.y][cell.x] == "spawn":
                    has_spawn = true
                for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                    stack.append(cell + d)
            if cluster.size() < 4 and not has_spawn:
                for cell in cluster:
                    grid[cell.y][cell.x] = "wall"

func _prune_dead_ends(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var corridor_tiles = ["corridor_h", "corridor_v"]
    var walkable = ["room", "spawn", "corridor_h", "corridor_v", "door"]
    var changed = true
    while changed:
        changed = false
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                if grid[y][x] not in corridor_tiles:
                    continue
                var neighbors = 0
                for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                    if grid[y + d.y][x + d.x] in walkable:
                        neighbors += 1
                if neighbors <= 1:
                    grid[y][x] = "wall"
                    changed = true

func _seal_empty_borders(grid: Array) -> void:
    var h = grid.size()
    var w = grid[0].size() if h > 0 else 0
    var walkable = ["room", "spawn", "corridor_h", "corridor_v", "door"]
    for y in range(h):
        for x in range(w):
            if grid[y][x] != "empty":
                continue
            for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                var nx = x + d.x
                var ny = y + d.y
                if nx >= 0 and nx < w and ny >= 0 and ny < h:
                    if grid[ny][nx] in walkable:
                        grid[y][x] = "wall"
                        break


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
