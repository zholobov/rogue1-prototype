extends Node3D

const HUDScene = preload("res://src/ui/hud.tscn")

func _ready():
    # Create and register the ECS world
    var world = World.new()
    world.name = "World"
    add_child(world)
    ECS.world = world

    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())

    var hud = HUDScene.instantiate()
    add_child(hud)

func _physics_process(delta: float) -> void:
    ECS.process(delta)
