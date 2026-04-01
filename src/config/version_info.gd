extends Node

# Auto-updated by pre-commit hook
const COMMIT := "2fd7ed5"
const TIMESTAMP := "2026-04-01 15:35 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
