extends Control

@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var peers_label: Label = $MarginContainer/VBoxContainer/PeersLabel

func _process(_delta: float) -> void:
    var peer_count = Net.peers.size() + 1  # +1 for self
    peers_label.text = "Players: %d" % peer_count
