extends Node
## Корневой узел игры. На первом этапе только проверяет, что проект запускается.
## По мере развития сюда подключаются мир, системы и UI.

@onready var _label: Label = $BootLabel


func _ready() -> void:
	print("[Drone Factory] boot ok, engine=", Engine.get_version_info().string)
	print("[Drone Factory] world=%dx%d cells, tile=%dpx" % [
		Constants.WORLD_SIZE, Constants.WORLD_SIZE, Constants.TILE_SIZE,
	])
	if is_instance_valid(_label):
		_label.text = "Drone Factory\nболванка проекта"
