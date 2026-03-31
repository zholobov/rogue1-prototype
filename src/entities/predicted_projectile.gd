extends Node3D

var direction: Vector3
var speed: float
var lifetime: float

func _ready() -> void:
	direction = get_meta("direction", Vector3.FORWARD)
	speed = get_meta("speed", 30.0)
	lifetime = get_meta("lifetime", 0.3)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
