extends Node

# Auto-updated by pre-commit hook
const COMMIT := "4edb535"
const TIMESTAMP := "2026-04-03 00:00 UTC"

var version_string: String

func _ready() -> void:
    if TIMESTAMP != "":
        version_string = "%s · %s" % [COMMIT, TIMESTAMP]
    else:
        version_string = COMMIT
