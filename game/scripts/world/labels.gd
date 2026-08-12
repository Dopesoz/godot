class_name Labels
extends RefCounted

## Every piece of text drawn *into the world* goes through here: house names,
## room names, a resident's name, the numbers that float up when something
## happens.
##
## Two problems, one place to solve them.
##
## **Size.** A string drawn in world space is scaled by the camera like anything
## else, so a name that reads well from far away becomes a banner across the
## room when the player zooms in to watch someone cook. Here the canvas
## transform is scaled by 1/zoom before drawing, which cancels the camera
## exactly: the glyphs are still rasterised at their real size — so they stay
## sharp — and end up the same number of pixels tall at every zoom level.
##
## **Overlap.** Labels are placed by what they describe, and things in a city
## stand close together, so two labels regularly want the same patch of screen.
## Each one reserves the rectangle it occupies; a label that would land on a
## reserved rectangle steps up until it is clear. Reservations are stamped with
## the frame they were made on and expire by themselves, so this works no matter
## which node draws first and never needs resetting.

## Room to breathe around a reserved rectangle, in pixels.
const PADDING := 2.0
## Space kept clear at the top of the screen for the clock, the money and the
## controls hint. Scaled with the interface, because on a phone that band is
## twice as tall.
static func top_margin() -> float:
	return 112.0 * Platform.ui_scale()
## Give up after this many steps and draw anyway — an unreadable label is better
## than a label that has climbed off the screen.
const MAX_STEPS := 6

static var _reserved: Array = []
static var _frame: int = -1


## Draws `text` centred above `world_anchor`. `size` is in screen pixels and
## stays that way at any zoom.
static func draw(canvas: CanvasItem, font: Font, text: String, world_anchor: Vector2,
		color: Color, size: int = 14, shadow: Color = Color(0, 0, 0, 0.75)) -> void:
	if text == "":
		return
	# The scale the camera is applying to this canvas item right now. Asking the
	# item rather than the camera keeps this usable from anywhere, including the
	# static painters.
	var transform := canvas.get_global_transform_with_canvas()
	var zoom := maxf(transform.get_scale().x, 0.001)
	var screen := transform * world_anchor

	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var height := float(size) + PADDING * 2.0
	var lift := 0.0
	var rect := Rect2(screen.x - width * 0.5, screen.y - height, width, height)
	# Which way to step out of the way. Up, normally — a name belongs above the
	# thing it names — but not into the clock and the money at the top of the
	# screen, which is where the first version of this piled them.
	var margin := top_margin()
	var step_y := height if rect.position.y - height < margin else -height
	for step in MAX_STEPS:
		if not _overlaps(rect):
			break
		lift -= step_y
		rect.position.y += step_y
	# The HUD is not a label and cannot reserve anything, so the band it owns is
	# simply out of bounds: a name for a house at the top of the screen sits
	# under the clock rather than through it.
	if rect.position.y < margin:
		lift -= margin - rect.position.y
		rect.position.y = margin
	_reserve(rect)

	# 1 unit == 1 pixel from here on, so the offsets below are screen offsets
	# even though the anchor is a world position.
	canvas.draw_set_transform(world_anchor, 0.0, Vector2.ONE / zoom)
	var origin := Vector2(-width * 0.5, -lift)
	canvas.draw_string(font, origin + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size, shadow)
	canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Width of a string on screen, for callers that need to lay something out
## beside it.
static func width_of(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func _reserve(rect: Rect2) -> void:
	_expire()
	_reserved.append(rect)


static func _overlaps(rect: Rect2) -> bool:
	_expire()
	for taken: Rect2 in _reserved:
		if taken.intersects(rect):
			return true
	return false


## Reservations last one frame. Stamping them rather than clearing them from
## some designated node means no node has to be "the first one to draw".
static func _expire() -> void:
	var now := Engine.get_frames_drawn()
	if now != _frame:
		_frame = now
		_reserved.clear()
