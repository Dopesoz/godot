class_name Assembler
extends ProductionBuilding

## Сборщик: собирает детали из пластин.


func machine_kind() -> int:
	return Recipes.Machine.ASSEMBLER
