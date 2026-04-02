extends Node

# Auto-updated by pre-commit hook
const COMMIT := "a19fa9d"
const TIMESTAMP := "2026-04-02 00:50 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
