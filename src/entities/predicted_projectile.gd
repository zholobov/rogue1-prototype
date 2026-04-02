extends Node3D

var direction: Vector3
var speed: float
var lifetime: float
var _logged := false

func _ready() -> void:
    direction = get_meta("direction", Vector3.FORWARD)
    speed = get_meta("speed", 30.0)
    lifetime = get_meta("lifetime", 0.3)
    GameLog.info("[Predicted] _ready: speed=%s lifetime=%s" % [str(speed), str(lifetime)])

func _physics_process(delta: float) -> void:
    if not _logged:
        _logged = true
        GameLog.info("[Predicted] _physics_process running: speed=%s lifetime=%s" % [str(speed), str(lifetime)])
    position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0:
        GameLog.info("[Predicted] expired, freeing")
        queue_free()
