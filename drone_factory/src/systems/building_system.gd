class_name BuildingSystem
extends GameSystem

## Обновление всех зданий за тик.
##
## Здания опрашиваются одним плоским проходом по реестру: никакого обхода
## дерева сцены и виртуальных вызовов Node — только массив объектов.

func system_name() -> String:
	return "здания"


func tick(delta: float, context: Dictionary) -> void:
	var registry: BuildingRegistry = context["registry"]
	for building: Building in registry.all():
		var previous: int = building.status
		building.tick(delta, context)
		# Событие шлём только при смене состояния: перерисовка значков и
		# обновление панели не должны происходить десять раз в секунду.
		if building.status != previous:
			Events.building_state_changed.emit(building.id)
