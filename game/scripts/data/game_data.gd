class_name GameData
extends Resource

## Base class for every content Resource in res://resources/.
##
## A GameData is a TEMPLATE, never a live object. `FurnitureData` describes what
## a bed is; the bed standing in a bedroom is a separate runtime object that
## points at this template. Templates are shared, immutable at runtime and never
## written into a save file — only their `id` is.

## Stable string key, unique within its category, e.g. "bed_single".
## Saves store this string, so renaming an id breaks existing saves.
@export var id: StringName = &""

## Player-facing name. Will be routed through translations later.
@export var display_name: String = ""

@export_multiline var description: String = ""

## Placeholder art (design doc §28) or the final sprite.
@export var icon: Texture2D

## Flat colour used when `icon` is null, so the game is playable before any art
## exists.
@export var placeholder_color: Color = Color(0.7, 0.7, 0.75)


func is_valid() -> bool:
	return id != &""


func _to_string() -> String:
	return "%s(%s)" % [get_script().get_global_name(), id]
