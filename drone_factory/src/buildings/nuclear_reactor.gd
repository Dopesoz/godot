class_name NuclearReactor
extends FuelGenerator

## Реактор: очень много энергии из одного стержня, без копоти.
##
## Цель поздней игры: урановая руда встречается редко и далеко, стержень
## дорог в сборке, а сам реактор стоит стали и микросхем. Зато одна порция
## топлива держит фабрику полторы минуты и не портит небо.

const BURN_SECONDS: float = 90.0
const WATER_PER_ROD: int = 12


func fuel_item() -> StringName:
	return Items.FUEL_ROD


func burn_seconds() -> float:
	return BURN_SECONDS


func water_per_fuel() -> int:
	return WATER_PER_ROD


func request_fuel() -> int:
	return 4


func request_water() -> int:
	return 60
