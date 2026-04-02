extends Node

# Auto-updated by pre-commit hook
const COMMIT := "1a6e76b"
const TIMESTAMP := "2026-04-02 02:43 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
