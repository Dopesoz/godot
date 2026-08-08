class_name FusionReactor
extends FuelGenerator

## Термоядерный реактор — вершина энергетики.
##
## Замыкает цепочку, которая начинается с обычного водоёма: насос качает воду,
## завод выделяет из неё тритий, реактор превращает тритий обратно в энергию.
## Никакой копоти и никакой добычи руды: в отличие от урана, топливо здесь
## делается из того, что на карте есть всегда.
##
## Дорог сознательно. Одна установка перекрывает потребление большой фабрики,
## поэтому платой за неё служат сталь, микросхемы и золото с метеоритов —
## то есть весь набор поздних цепочек сразу.

const BURN_SECONDS: float = 45.0
const WATER_PER_UNIT: int = 20


func fuel_item() -> StringName:
	return Items.TRITIUM


func burn_seconds() -> float:
	return BURN_SECONDS


func water_per_fuel() -> int:
	return WATER_PER_UNIT


func request_fuel() -> int:
	return 8


func request_water() -> int:
	return 120
