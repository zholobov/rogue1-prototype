class_name MonsterVariantDefinition
extends RefCounted

var variant_name: String = ""
var variant_key: StringName = &"basic"
var scene: PackedScene
var spawn_weight: float = 1.0
var hp_mult: float = 1.0
var speed_mult: float = 1.0
var is_boss: bool = false
