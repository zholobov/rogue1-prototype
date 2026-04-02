extends Node3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 30.0
var lifetime: float = 0.3

func _physics_process(delta: float) -> void:
    position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0:
        queue_free()
