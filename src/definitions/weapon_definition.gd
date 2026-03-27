class_name WeaponDefinition
extends RefCounted

var weapon_name: String = ""
var damage: int = 10
var fire_rate: float = 0.3
var speed: float = 30.0
var element: StringName = ElementNames.NONE
var build_viewmodel: Callable   # func() -> Node3D
var build_world_model: Callable # func() -> Node3D
var build_crosshair: Callable   # func(parent: Control) -> void
var build_hud_icon: Callable    # func() -> Control
