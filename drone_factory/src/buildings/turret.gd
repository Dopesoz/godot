class_name Turret
extends Building

## Турель: стреляет по жукам в радиусе.
##
## Держит только своё состояние — перезарядку и запас патронов. Кого и когда
## бить, решает боевая система: она одна знает, где сейчас жуки, и не заставит
## каждую турель обходить весь мир в поисках цели.
##
## Патроны — обычный предмет, который привозят курьеры теми же правилами, что
## и руду в печь. Отдельного «снабжения боеприпасами» в игре нет специально:
## оборона должна быть ещё одной производственной цепочкой, а не отдельной
## игрой внутри игры.

## Радиус поражения в клетках.
const RANGE_CELLS: float = 9.0
## Пауза между выстрелами, секунды.
const RELOAD_SECONDS: float = 0.5
## Базовый урон одного выстрела.
const DAMAGE: int = 12
## Сколько патронов уходит на выстрел.
const AMMO_PER_SHOT: int = 1
## Сколько патронов турель просит про запас.
const AMMO_STOCK: int = 40

var reload_left: float = 0.0
## Множитель урона от исследований. Ставит боевая система.
var damage_multiplier: float = 1.0


func _on_setup() -> void:
	if input != null:
		input.filter = [Items.AMMO]


func range_cells() -> float:
	return RANGE_CELLS


func damage() -> int:
	return int(round(float(DAMAGE) * damage_multiplier))


## Готова ли турель выстрелить прямо сейчас.
func can_fire() -> bool:
	return (
		enabled
		and reload_left <= 0.0
		and has_power()
		and input != null
		and input.count(Items.AMMO) >= AMMO_PER_SHOT
	)


## Списывает патрон и уходит на перезарядку. Вызывает боевая система, когда
## цель действительно найдена — иначе турель расстреляла бы боезапас в воздух.
func fire() -> int:
	input.remove(Items.AMMO, AMMO_PER_SHOT)
	reload_left = RELOAD_SECONDS
	Events.inventory_changed.emit(id)
	return damage()


func tick(delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	reload_left = maxf(reload_left - delta, 0.0)
	if not has_power():
		status = Status.NO_POWER
	elif input == null or input.count(Items.AMMO) < AMMO_PER_SHOT:
		status = Status.NO_INPUT
	else:
		status = Status.WORKING


func requests() -> Dictionary[StringName, int]:
	var needed: Dictionary[StringName, int] = {}
	if not enabled or input == null:
		return needed
	var missing: int = AMMO_STOCK - input.count(Items.AMMO)
	if missing > 0:
		needed[Items.AMMO] = mini(missing, input.free_space())
	return needed


func _serialize_extra() -> Dictionary:
	return {"reload": reload_left}


func _deserialize_extra(data: Dictionary) -> void:
	reload_left = maxf(float(data.get("reload", 0.0)), 0.0)
