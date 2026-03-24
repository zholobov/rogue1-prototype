extends Control

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var peers_label: Label = $MarginContainer/VBoxContainer/PeersLabel
@onready var weapon_label: Label = $MarginContainer/VBoxContainer/WeaponLabel
@onready var god_mode_check: CheckBox = $MarginContainer/VBoxContainer/GodModeCheck
@onready var damage_flash: ColorRect = $DamageFlash

var _prev_health: int = -1

func _ready() -> void:
	god_mode_check.button_pressed = Config.god_mode
	god_mode_check.toggled.connect(func(on: bool): Config.god_mode = on)

func _process(_delta: float) -> void:
	var peer_count = Net.peers.size() + 1
	peers_label.text = "Players: %d" % peer_count

	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player is PlayerEntity:
			var health = player.get_component(C_Health)
			if health:
				health_label.text = "HP: %d/%d" % [health.current_health, health.max_health]
				# Damage flash detection
				if _prev_health >= 0 and health.current_health < _prev_health:
					_trigger_damage_flash()
				_prev_health = health.current_health
			var weapon = player.get_component(C_Weapon)
			if weapon:
				var elem_text = weapon.element if weapon.element != "" else "none"
				weapon_label.text = "Weapon: %s [%s]" % [_get_weapon_name(weapon), elem_text]
				break

func _trigger_damage_flash() -> void:
	damage_flash.color = Color(1.0, 0.0, 0.0, 0.3)
	var tween = create_tween()
	tween.tween_property(damage_flash, "color:a", 0.0, 0.15)

func _get_weapon_name(weapon: C_Weapon) -> String:
	for preset in Config.weapon_presets:
		if preset.damage == weapon.damage and preset.element == weapon.element:
			return preset.name
	return "Custom"
