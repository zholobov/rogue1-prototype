extends Node

# Auto-updated by pre-commit hook
const COMMIT := "b477175"
const TIMESTAMP := "2026-04-02 02:09 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
