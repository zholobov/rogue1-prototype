class_name RunMap
extends RefCounted

var layers: Array = []  # Array of Array[MapNode]

class MapNode:
    var level_seed: int = 0
    var modifier: String = "normal"
    var connections: Array = []
    var visited: bool = false
    var biome_index: int = 0

static func generate(boss_depth: int) -> RunMap:
    var map = RunMap.new()

    for depth in range(boss_depth):
        var layer: Array = []
        var node_count = randi_range(2, 3)
        var used_modifiers: Array = []
        for i in range(node_count):
            var node = MapNode.new()
            node.level_seed = randi()
            node.modifier = _random_modifier_excluding(used_modifiers)
            used_modifiers.append(node.modifier)
            var node_biome_count = ThemeManager.active_group.biomes.size() if ThemeManager and ThemeManager.active_group else 1
            node.biome_index = randi() % node_biome_count
            layer.append(node)
        map.layers.append(layer)

    # Boss layer
    var boss_node = MapNode.new()
    boss_node.level_seed = randi()
    boss_node.modifier = "boss"
    var biome_count = ThemeManager.active_group.biomes.size() if ThemeManager and ThemeManager.active_group else 1
    boss_node.biome_index = randi() % biome_count
    map.layers.append([boss_node])

    # Connect layers
    for depth in range(map.layers.size() - 1):
        var current_layer = map.layers[depth]
        var next_layer = map.layers[depth + 1]

        for node in current_layer:
            var conn_count = randi_range(1, mini(2, next_layer.size()))
            var indices: Array = []
            for idx in range(next_layer.size()):
                indices.append(idx)
            indices.shuffle()
            node.connections = indices.slice(0, conn_count)

        # Ensure all next-layer nodes reachable
        for next_idx in range(next_layer.size()):
            var reachable = false
            for node in current_layer:
                if next_idx in node.connections:
                    reachable = true
                    break
            if not reachable:
                current_layer[randi() % current_layer.size()].connections.append(next_idx)

    return map

static func _random_modifier_excluding(exclude: Array) -> String:
    var all_modifiers = ModifierRegistry.get_spawnable_names()

    # Remove excluded modifiers and collect weights
    var available: Array = []
    var available_weights: Array = []
    for name in all_modifiers:
        if name not in exclude:
            available.append(name)
            available_weights.append(ModifierRegistry.get_modifier(name).map_weight)

    if available.is_empty():
        return Modifiers.NORMAL

    var total = 0.0
    for w in available_weights:
        total += w
    var roll = randf() * total
    var running = 0.0
    for i in range(available.size()):
        running += available_weights[i]
        if roll <= running:
            return available[i]
    return available[available.size() - 1]

func get_node(depth: int, index: int) -> MapNode:
    return layers[depth][index]

func visit_node(depth: int, index: int) -> void:
    layers[depth][index].visited = true

func get_reachable_indices(depth: int, prev_index: int) -> Array:
    if depth == 0:
        var indices: Array = []
        for i in range(layers[0].size()):
            indices.append(i)
        return indices
    return layers[depth - 1][prev_index].connections
