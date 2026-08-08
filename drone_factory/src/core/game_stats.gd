class_name GameStats
extends RefCounted

## Накопительная статистика партии: сколько чего произведено, добыто, построено.
##
## Один общий счётчик обслуживает и достижения, и задачи сюжета: обе системы
## задают вопрос «сколько уже сделано», и заводить для них отдельные подсчёты
## значило бы считать одно и то же дважды.

var counters: Dictionary[StringName, int] = {}


## --- Ключи -----------------------------------------------------------------

static func produced_key(item_id: StringName) -> StringName:
	return StringName("produced:" + String(item_id))


static func mined_key(item_id: StringName) -> StringName:
	return StringName("mined:" + String(item_id))


static func built_key(def_id: StringName) -> StringName:
	return StringName("built:" + String(def_id))


const TECHS_KEY := &"techs"
const PLAYTIME_KEY := &"playtime"


## --- Счётчики --------------------------------------------------------------

func add(key: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	counters[key] = counters.get(key, 0) + amount


func get_count(key: StringName) -> int:
	return counters.get(key, 0)


## Сколько предмета получено любым способом: и добыто, и произведено.
func total_of(item_id: StringName) -> int:
	return get_count(produced_key(item_id)) + get_count(mined_key(item_id))


func clear() -> void:
	counters.clear()


func serialize() -> Dictionary:
	var data: Dictionary = {}
	for key: StringName in counters:
		data[String(key)] = counters[key]
	return data


func deserialize(data: Dictionary) -> void:
	clear()
	for key: Variant in data:
		counters[StringName(key)] = int(data[key])
