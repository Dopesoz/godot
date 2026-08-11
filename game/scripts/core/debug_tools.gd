class_name DebugTools
extends RefCounted

## Small development-only helpers. Nothing here is part of the game.


## `godot --path game -- --screenshot out.png` renders the world for a moment,
## saves a PNG and quits. Used to eyeball the isometric projection from a
## terminal (and, later, to diff visual regressions in CI) without a human
## sitting in front of the window.
static func maybe_screenshot(node: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--screenshot")
	if index == -1:
		return
	var path := args[index + 1] if index + 1 < args.size() else "user://screenshot.png"
	# Let the scene settle: the camera eases into place over several frames.
	await node.get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var image := node.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("DebugTools: could not write %s (%d)" % [path, error])
	else:
		print("screenshot saved to ", path)
	node.get_tree().quit(0 if error == OK else 1)
