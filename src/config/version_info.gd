extends Node

# Auto-updated by pre-commit hook
const COMMIT := "2e7e32b"
const TIMESTAMP := "2026-04-02 20:25 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
