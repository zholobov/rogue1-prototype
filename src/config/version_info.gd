extends Node

# Auto-updated by pre-commit hook
const COMMIT := "47da23d"
const TIMESTAMP := "2026-04-01 15:18 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
