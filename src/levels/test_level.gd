extends Node3D

const HUDScene = preload("res://src/ui/hud.tscn")

func _ready():
    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())

    var hud = HUDScene.instantiate()
    add_child(hud)

func _physics_process(delta: float) -> void:
    ECS.world.process(delta)
