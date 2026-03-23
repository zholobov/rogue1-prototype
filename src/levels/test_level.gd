extends Node3D

func _ready():
    # Register systems with ECS
    ECS.world.add_system(S_PlayerInput.new())
    ECS.world.add_system(S_Movement.new())

func _physics_process(delta: float) -> void:
    ECS.world.process(delta)
