class_name Nest
extends Building

## Гнездо жуков.
##
## Главное правило: гнездо нельзя разобрать. Игрок не «сносит постройку», он
## ведёт к ней технику — и чем дольше гнездо простояло, тем больше техники
## нужно. Это единственное место в игре, где требуется не оптимизация фабрики,
## а разовая операция, и именно поэтому оно устроено предельно понятно:
##
##   уровень гнезда = сколько танков должно бить по нему одновременно.
##
## Не «больше урона» и не «больше здоровья»: такие правила игрок не может
## проверить на глаз. А число танков он видит прямо в панели гнезда.

## Через сколько волн гнездо становится на уровень старше.
const WAVES_PER_LEVEL: int = 3
## Выше этого гнёзда не растут: иначе поздняя партия упирается в сбор армии.
const MAX_LEVEL: int = 5
## Сколько урона гнездо наносит каждому атакующему танку в секунду.
const RETALIATION: int = 4

var level: int = 1


## Сколько танков нужно, чтобы гнездо вообще начало получать урон.
func required_tanks() -> int:
	return level


func max_health() -> int:
	return BuildingDefs.max_health(def_id) * level


func evolve() -> bool:
	if level >= MAX_LEVEL:
		return false
	level += 1
	# Подросшее гнездо чинит себя: иначе можно было бы копить урон годами.
	health = max_health()
	return true


func display_name() -> String:
	return "%s (уровень %d)" % [BuildingDefs.display_name(def_id), level]


func _on_setup() -> void:
	health = max_health()


func _serialize_extra() -> Dictionary:
	return {"level": level}


func _deserialize_extra(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
