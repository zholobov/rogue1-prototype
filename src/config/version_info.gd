extends Node

# Auto-updated by pre-commit hook
const COMMIT := "c15bd4d"
const TIMESTAMP := "2026-04-02 23:59 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
