extends Node

# Auto-updated by pre-commit hook
const COMMIT := "67c0770"
const TIMESTAMP := "2026-04-02 03:45 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
