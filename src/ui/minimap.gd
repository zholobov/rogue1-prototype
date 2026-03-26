class_name Minimap
extends Control

## Renders level grid, player dot, and monster dots via _draw().
## Redraws at ~10 FPS via Timer, not every frame.

const MAP_SIZE: float = 120.0

var _grid: Array = []
var _grid_width: int = 0
var _grid_height: int = 0
var _tile_size: float = 4.0
var _cell_size: float = 1.0
var _timer: Timer

func _init() -> void:
    custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
    size = Vector2(MAP_SIZE, MAP_SIZE)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
    _timer = Timer.new()
    _timer.wait_time = 0.1  # ~10 FPS
    _timer.timeout.connect(queue_redraw)
    add_child(_timer)
    _timer.start()

func setup(level_data: Dictionary) -> void:
    _grid = level_data.get("grid", [])
    _grid_width = level_data.get("width", 0)
    _grid_height = level_data.get("height", 0)
    _tile_size = Config.level_tile_size
    if _grid_width > 0 and _grid_height > 0:
        _cell_size = MAP_SIZE / float(maxi(_grid_width, _grid_height))
    queue_redraw()

func apply_theme() -> void:
    queue_redraw()

func _draw() -> void:
    var theme = ThemeManager.active_theme

    # Semi-transparent background
    var bg_color = Color(theme.ui_background_color.r, theme.ui_background_color.g, theme.ui_background_color.b, 0.7)
    draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), bg_color)

    if _grid.is_empty():
        return

    # Draw tile grid
    for y in range(_grid.size()):
        var row = _grid[y]
        for x in range(row.size()):
            var tile: String = row[x]
            var color: Color
            match tile:
                "room", "spawn":
                    color = theme.ui_minimap_room
                "corridor_h", "corridor_v", "door":
                    # Slightly darker than room
                    color = Color(
                        theme.ui_minimap_room.r - 0.03,
                        theme.ui_minimap_room.g - 0.03,
                        theme.ui_minimap_room.b - 0.03
                    )
                "wall":
                    color = theme.ui_minimap_wall
                _:
                    continue  # "empty" — skip
            draw_rect(Rect2(x * _cell_size, y * _cell_size, _cell_size, _cell_size), color)

    # Monster dots (red)
    var monsters = get_tree().get_nodes_in_group("monsters")
    for monster in monsters:
        if is_instance_valid(monster) and monster is Node3D:
            var dot_pos = _world_to_map(monster.global_position)
            draw_circle(dot_pos, 2.0, theme.health_bar_low_color)

    # Player dot + view cone
    var players = get_tree().get_nodes_in_group("players")
    for player in players:
        if player is PlayerEntity:
            var net_id = player.get_component(C_NetworkIdentity)
            if net_id and net_id.is_local:
                var dot_pos = _world_to_map(player.global_position)
                # View cone — triangle showing facing direction
                var facing_angle = -player.rotation.y  # Godot Y rotation, negated for 2D
                var cone_length = 18.0
                var cone_half_angle = 0.45  # ~25 degrees half-angle
                var cone_color = Color(theme.health_bar_foreground, 0.2)
                var tip = dot_pos
                var left_pt = tip + Vector2(sin(facing_angle - cone_half_angle), -cos(facing_angle - cone_half_angle)) * cone_length
                var right_pt = tip + Vector2(sin(facing_angle + cone_half_angle), -cos(facing_angle + cone_half_angle)) * cone_length
                draw_colored_polygon(PackedVector2Array([tip, left_pt, right_pt]), cone_color)
                # Player dot on top
                draw_circle(dot_pos, 3.0, theme.health_bar_foreground)
                break

    # Border
    draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), theme.ui_minimap_wall, false, 2.0)

func _world_to_map(world_pos: Vector3) -> Vector2:
    var mx = (world_pos.x / (_grid_width * _tile_size)) * MAP_SIZE
    var my = (world_pos.z / (_grid_height * _tile_size)) * MAP_SIZE
    return Vector2(clampf(mx, 0, MAP_SIZE), clampf(my, 0, MAP_SIZE))
