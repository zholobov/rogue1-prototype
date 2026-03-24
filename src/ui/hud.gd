extends Control

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var peers_label: Label = $MarginContainer/VBoxContainer/PeersLabel
@onready var weapon_label: Label = $MarginContainer/VBoxContainer/WeaponLabel

func _process(_delta: float) -> void:
    var peer_count = Net.peers.size() + 1  # +1 for self
    peers_label.text = "Players: %d" % peer_count

    # Find local player health
    var players = get_tree().get_nodes_in_group("players")
    for player in players:
        if player is PlayerEntity:
            var health = player.get_component(C_Health)
            if health:
                health_label.text = "HP: %d/%d" % [health.current_health, health.max_health]
            var weapon = player.get_component(C_Weapon)
            if weapon:
                var elem_text = weapon.element if weapon.element != "" else "none"
                weapon_label.text = "Weapon: %s [%s]" % [_get_weapon_name(weapon), elem_text]
                break

func _get_weapon_name(weapon: C_Weapon) -> String:
    for preset in Config.weapon_presets:
        if preset.damage == weapon.damage and preset.element == weapon.element:
            return preset.name
    return "Custom"
