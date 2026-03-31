class_name DamageNumberFactory
extends RefCounted

## Creates a FloatingText with element-colored tint.
## Caller must add_child() first, then call ft.show_text().

static func create(element: String) -> FloatingText:
	var ft = FloatingText.new()
	var color = ThemeManager.active_theme.get_element_color(element)
	ft.add_theme_color_override("font_color", color)
	return ft
