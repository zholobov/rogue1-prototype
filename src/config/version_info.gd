extends Node

# Auto-updated by pre-commit hook
const COMMIT := "729053c"
const TIMESTAMP := "2026-04-03 00:25 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
