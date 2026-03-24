class_name RunStats
extends RefCounted

var kills: int = 0
var damage_dealt: int = 0
var time_elapsed: float = 0.0
var levels_cleared: int = 0
var loop: int = 0
var took_damage_this_level: bool = false
var total_currency_earned: int = 0

func reset() -> void:
    kills = 0
    damage_dealt = 0
    time_elapsed = 0.0
    levels_cleared = 0
    loop = 0
    took_damage_this_level = false
    total_currency_earned = 0
