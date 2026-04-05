extends Node

# Auto-updated by pre-commit hook
const COMMIT := "b2f449a"
const TIMESTAMP := "2026-04-05 02:30 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
