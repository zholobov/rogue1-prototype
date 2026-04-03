extends Node

signal damage_dealt(position: Vector3, amount: int, element: String)

func emit_damage(pos: Vector3, amount: int, element: String) -> void:
    damage_dealt.emit(pos, amount, element)
