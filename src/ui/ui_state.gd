extends Node

## Global UI state — tracks whether game input should be blocked.
## Reference-counted: overlapping overlays (ESC + game log) handled correctly.

var _block_count: int = 0
var input_blocked: bool:
    get: return _block_count > 0

func block_input() -> void:
    _block_count += 1

func unblock_input() -> void:
    _block_count = maxi(0, _block_count - 1)
