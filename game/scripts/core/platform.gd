class_name Platform
extends RefCounted

## Everything that differs between a phone and a desktop, in one place.
##
## The rule kept throughout the project is that gameplay never asks what device
## it is running on — the camera takes commands, the build tools take cells, the
## simulation takes minutes. Only presentation and budget differ, and that is
## what this file decides.

## Physical size a touch target must not go below. 48 dp is the Android
## guideline; below it people miss and blame the game.
const MIN_TOUCH_TARGET_DP := 48.0

## Reference dpi the UI was designed at.
const BASE_DPI := 160.0


## Development flag: `--as-phone` makes a desktop build answer every question
## below the way a phone would.
##
## Not a hack around the checks — a way to *run* them. The mobile layout, the
## thumb-sized buttons, the safe-area margins and the touch gestures are all
## decided here, and none of that code path executes on a machine with a mouse.
## With this flag it does, and a phone-shaped window can be looked at, dragged
## and screenshotted without a phone.
static var _pretend_phone: int = -1


static func pretends_to_be_phone() -> bool:
	if _pretend_phone < 0:
		_pretend_phone = 1 if OS.get_cmdline_user_args().has("--as-phone") else 0
	return _pretend_phone == 1


static func is_mobile() -> bool:
	return (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
			or pretends_to_be_phone())


static func has_touch() -> bool:
	return is_mobile() or DisplayServer.is_touchscreen_available()


## How much bigger the interface should be than the desktop layout. Driven by
## the screen's real dpi rather than its resolution: a 1080p phone and a 1080p
## monitor need very different button sizes for the same pixel count.
static func ui_scale() -> float:
	if not has_touch():
		return 1.0
	# A desktop monitor pretending to be a phone still reports a desktop dpi,
	# and the interesting case is precisely the one a low dpi hides: at 2x the
	# tool row is twice as wide and has to fit anyway.
	if pretends_to_be_phone():
		return 2.0
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		return 1.25
	return clampf(dpi / BASE_DPI, 1.0, 2.0)


## Margins that keep the interface clear of notches, punch-holes and rounded
## corners. Returns zero on hardware without them, so the same code runs
## everywhere.
static func safe_area_margins() -> Vector4i:
	var window := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if safe.size == Vector2i.ZERO or safe.size == window:
		return Vector4i.ZERO
	return Vector4i(
		maxi(safe.position.x, 0),
		maxi(safe.position.y, 0),
		maxi(window.x - safe.end.x, 0),
		maxi(window.y - safe.end.y, 0)
	)


## Applies the performance budget for this device. A phone has a fraction of the
## CPU and a battery to protect, so it simulates a smaller radius in full detail
## and does not render frames nobody asked for.
static func apply_performance_defaults() -> void:
	if not is_mobile():
		return
	# 60 is plenty for a city builder and roughly halves the power draw compared
	# with an uncapped loop on a 120 Hz panel.
	Engine.max_fps = 60
	# Godot only redraws when something changed; with a mostly static map that
	# is a large saving on a phone.
	OS.low_processor_usage_mode = true


## Simulation radii, tightened on mobile. Distant residents keep living — they
## are simply resolved in coarser steps, which is exactly what SimLOD is for.
static func full_detail_radius() -> float:
	return GameConstants.LOD_FULL_RADIUS * (0.6 if is_mobile() else 1.0)


static func reduced_detail_radius() -> float:
	return GameConstants.LOD_REDUCED_RADIUS * (0.6 if is_mobile() else 1.0)
