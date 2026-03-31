class_name S_WeaponVisual
extends System

const VIEWMODEL_BASE_POS = Vector3(0.35, -0.35, -0.6)
const VIEWMODEL_BASE_ROT = Vector3(0, -5, 0)

var _last_index: Dictionary = {}  # entity instance_id -> last weapon_index
var _weapon_nodes: Dictionary = {}  # entity instance_id -> Node3D (weapon mesh)
var _recoil_tweens: Dictionary = {}  # entity instance_id -> Tween

func query() -> QueryBuilder:
    return q.with_all([C_WeaponVisual])

func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
    for entity in entities:
        if not is_instance_valid(entity):
            continue
        var wv := entity.get_component(C_WeaponVisual) as C_WeaponVisual
        if wv.weapon_index < 0:
            continue

        var eid = entity.get_instance_id()
        var body = entity.get_parent() as CharacterBody3D
        if not body:
            continue

        # Detect weapon change
        var last = _last_index.get(eid, -1)
        if last != wv.weapon_index:
            _swap_weapon(entity, wv, body, eid)
            _last_index[eid] = wv.weapon_index

        var weapon_node = _weapon_nodes.get(eid) as Node3D
        if not weapon_node or not is_instance_valid(weapon_node):
            continue

        # Idle sway (viewmodel only) — only X/Y, leave Z for recoil
        if wv.show_viewmodel:
            var t = Time.get_ticks_msec() / 1000.0
            weapon_node.position.x = VIEWMODEL_BASE_POS.x + sin(t * 2.0) * 0.003
            weapon_node.position.y = VIEWMODEL_BASE_POS.y + cos(t * 1.5) * 0.002

        # Fire recoil
        if wv.just_fired:
            wv.just_fired = false
            if wv.show_viewmodel:
                _play_recoil(weapon_node, eid)

        # Element pulse — only for viewmodel (player's weapon), throttled for world models
        if wv.element != "" and (wv.show_viewmodel or eid % 6 == Engine.get_frames_drawn() % 6):
            var pulse = 1.5 + sin(Time.get_ticks_msec() / 500.0) * 0.5
            _set_accent_energy(weapon_node, pulse)

func _swap_weapon(_entity: Entity, wv: C_WeaponVisual, body: CharacterBody3D, eid: int) -> void:
    # Remove old
    var old_node = _weapon_nodes.get(eid)
    if old_node and is_instance_valid(old_node):
        old_node.queue_free()
    _weapon_nodes.erase(eid)

    # Create new
    var new_node: Node3D
    var weapon_def = WeaponRegistry.get_weapon(wv.weapon_index)
    if weapon_def:
        if wv.show_viewmodel:
            new_node = weapon_def.build_viewmodel.call()
        else:
            new_node = weapon_def.build_world_model.call()

    if not new_node:
        return

    if wv.show_viewmodel:
        # Attach to camera
        var camera = body.get_node_or_null("Camera3D")
        if camera:
            new_node.position = VIEWMODEL_BASE_POS
            new_node.rotation_degrees = VIEWMODEL_BASE_ROT
            camera.add_child(new_node)
    else:
        # Attach to WeaponMount or fallback position
        var mount = _find_weapon_mount(body)
        if mount:
            mount.add_child(new_node)
        else:
            new_node.position = Vector3(0.4, 0.3, -0.3)
            body.add_child(new_node)

    _weapon_nodes[eid] = new_node

func _find_weapon_mount(body: Node) -> Node:
    # Check direct children
    var mount = body.get_node_or_null("WeaponMount")
    if mount:
        return mount
    # Check in VisualRoot (theme scene override)
    var visual_root = body.get_node_or_null("VisualRoot")
    if visual_root:
        mount = visual_root.get_node_or_null("WeaponMount")
        if mount:
            return mount
    return null

func _play_recoil(weapon_node: Node3D, eid: int) -> void:
    # Kill existing recoil tween
    var old_tween = _recoil_tweens.get(eid)
    if old_tween and old_tween.is_valid():
        old_tween.kill()
    # Reset to base immediately so rapid fire doesn't stack
    weapon_node.position.z = VIEWMODEL_BASE_POS.z
    weapon_node.rotation_degrees = VIEWMODEL_BASE_ROT

    var tree = weapon_node.get_tree()
    if not tree:
        return
    var tween = tree.create_tween()
    # Kick back
    tween.tween_property(weapon_node, "position:z", VIEWMODEL_BASE_POS.z + 0.05, 0.05)
    tween.parallel().tween_property(weapon_node, "rotation_degrees:x", VIEWMODEL_BASE_ROT.x + 3.0, 0.05)
    # Return
    tween.tween_property(weapon_node, "position:z", VIEWMODEL_BASE_POS.z, 0.1)
    tween.parallel().tween_property(weapon_node, "rotation_degrees:x", VIEWMODEL_BASE_ROT.x, 0.1)
    _recoil_tweens[eid] = tween

func _set_accent_energy(weapon_node: Node3D, energy: float) -> void:
    for child in weapon_node.get_children():
        if child is MeshInstance3D and child.name.begins_with("Accent"):
            var mat = child.material_override as StandardMaterial3D
            if mat and mat.emission_enabled:
                mat.emission_energy_multiplier = energy
