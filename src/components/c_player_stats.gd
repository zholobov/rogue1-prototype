class_name C_PlayerStats
extends Component

# Stat modifiers — recalculated from RunManager.active_upgrades at level start
var max_health_bonus: int = 0
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var damage_reduction: float = 0.0
var hp_regen: float = 0.0
var condition_duration_mult: float = 1.0
var fire_rate_bonus: float = 0.0
var proj_speed_bonus: float = 0.0

func recalculate(upgrades: Array) -> void:
    # Reset to base
    max_health_bonus = 0
    damage_mult = 1.0
    speed_mult = 1.0
    damage_reduction = 0.0
    hp_regen = 0.0
    condition_duration_mult = 1.0
    fire_rate_bonus = 0.0
    proj_speed_bonus = 0.0

    # Stack additively from all upgrades
    for upgrade in upgrades:
        match upgrade.property:
            "max_health_bonus":
                max_health_bonus += int(upgrade.value)
            "damage_mult":
                damage_mult += upgrade.value
            "speed_mult":
                speed_mult += upgrade.value
            "damage_reduction":
                damage_reduction += upgrade.value
            "hp_regen":
                hp_regen += upgrade.value
            "condition_duration_reduction":
                condition_duration_mult -= upgrade.value
            "fire_rate_bonus":
                fire_rate_bonus += upgrade.value
            "proj_speed_bonus":
                proj_speed_bonus += upgrade.value

    # Clamp
    condition_duration_mult = maxf(condition_duration_mult, 0.1)
    damage_reduction = minf(damage_reduction, 0.9)
