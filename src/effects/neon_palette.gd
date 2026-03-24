class_name NeonPalette
extends RefCounted

const CYAN := Color(0.0, 0.83, 1.0)
const MAGENTA := Color(1.0, 0.0, 0.67)
const PURPLE := Color(0.67, 0.27, 1.0)
const TEAL := Color(0.0, 1.0, 0.67)
const ORANGE := Color(1.0, 0.53, 0.0)

const ALL := [CYAN, MAGENTA, PURPLE, TEAL, ORANGE]

# Element to VFX color mapping
const ELEMENT_COLORS := {
    "": Color(1.0, 1.0, 1.0),
    "fire": Color(1.0, 0.27, 0.0),
    "ice": Color(0.0, 0.87, 1.0),
    "water": Color(0.0, 0.4, 1.0),
}

static func random_color() -> Color:
    return ALL[randi() % ALL.size()]

static func element_color(element: String) -> Color:
    return ELEMENT_COLORS.get(element, Color.WHITE)
