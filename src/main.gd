extends Node

const TestLevel = preload("res://src/levels/test_level.tscn")
const PlayerScene = preload("res://src/entities/player.tscn")

func _ready():
    var level = TestLevel.instantiate()
    add_child(level)

    var player = PlayerScene.instantiate()
    player.position = level.get_node("SpawnPoint").position
    level.add_child(player)  # player._ready() creates and registers ECS entity
    player.setup(1, true)
