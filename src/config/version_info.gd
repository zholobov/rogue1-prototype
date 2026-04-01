extends Node

var commit: String = "dev"
var timestamp: String = ""
var version_string: String = "dev"

func _ready() -> void:
    var cfg = ConfigFile.new()
    if cfg.load("res://version.cfg") == OK:
        commit = cfg.get_value("version", "commit", "dev")
        timestamp = cfg.get_value("version", "timestamp", "")
    if timestamp != "":
        version_string = "%s · %s" % [commit, timestamp]
    else:
        version_string = commit
