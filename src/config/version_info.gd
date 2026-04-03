extends Node

# Auto-updated by pre-commit hook
const COMMIT := "756df86"
const TIMESTAMP := "2026-04-03 15:48 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
