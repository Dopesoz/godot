class_name UiTheme
extends RefCounted

## The one place that decides what a panel looks like.
##
## The default theme's panel is translucent, which was fine over flat colour and
## stopped being fine the moment the map underneath became furniture: a resident
## walking behind the needs list is legible only if the list is not a window.
## Nearly opaque, then — enough to still read as an overlay, not enough to make
## the numbers compete with a sofa.

const BACKGROUND := Color(0.07, 0.08, 0.11, 0.95)
const BORDER := Color(1.0, 1.0, 1.0, 0.10)
const RADIUS := 10


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(12)
	return style


## Applies it to a Control that draws a `panel` stylebox (PanelContainer and
## friends). Anything else is left alone rather than silently ignored.
static func apply(control: Control) -> void:
	control.add_theme_stylebox_override(&"panel", panel_style())
