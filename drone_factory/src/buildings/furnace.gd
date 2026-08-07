class_name Furnace
extends ProductionBuilding

## Печь: плавит руду в пластины. Отличается от сборщика только набором
## доступных рецептов — вся общая механика в ProductionBuilding.


func machine_kind() -> int:
	return Recipes.Machine.FURNACE
