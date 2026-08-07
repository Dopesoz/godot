class_name ResearchState
extends RefCounted

## Что уже изучено и какие бонусы это даёт.
##
## Отдельный объект, а не часть системы: состояние читают и здания (через
## контекст тика), и интерфейс, и строительство. Система лишь изменяет его.

var completed: Dictionary[StringName, bool] = {}

## Сводные бонусы, пересчитываются при каждом открытии технологии.
var _bonuses: Dictionary[StringName, float] = {}


func is_completed(tech_id: StringName) -> bool:
	return completed.has(tech_id)


## Доступна ли технология к изучению: изучены все предшественники.
func is_available(tech_id: StringName) -> bool:
	if not Technologies.exists(tech_id) or is_completed(tech_id):
		return false
	for requirement: Variant in Technologies.requires(tech_id):
		if not is_completed(requirement):
			return false
	return true


func complete(tech_id: StringName) -> void:
	if not Technologies.exists(tech_id):
		return
	completed[tech_id] = true
	_recalculate_bonuses()


## Прибавка в долях: 0.0 — без бонуса, 0.25 — плюс четверть.
func bonus(key: StringName) -> float:
	return _bonuses.get(key, 0.0)


## Множитель для формул: 1.0 + бонус.
func multiplier(key: StringName) -> float:
	return 1.0 + bonus(key)


## Здание доступно, если у него нет требования или технология изучена.
func is_building_unlocked(def_id: StringName) -> bool:
	var tech_id: StringName = BuildingDefs.required_tech(def_id)
	return tech_id == &"" or is_completed(tech_id)


func is_recipe_unlocked(recipe_id: StringName) -> bool:
	var tech_id: StringName = Recipes.required_tech(recipe_id)
	return tech_id == &"" or is_completed(tech_id)


func unlocked_buildings() -> Array[StringName]:
	var result: Array[StringName] = []
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		if is_building_unlocked(def_id):
			result.append(def_id)
	return result


func unlocked_recipes(machine_kind: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id: StringName in Recipes.for_machine(machine_kind):
		if is_recipe_unlocked(recipe_id):
			result.append(recipe_id)
	return result


func clear() -> void:
	completed.clear()
	_bonuses.clear()


func serialize() -> Array:
	var list: Array = []
	for tech_id: StringName in completed:
		list.append(String(tech_id))
	return list


func deserialize(list: Array) -> void:
	clear()
	for entry: Variant in list:
		var tech_id := StringName(entry)
		# Технология могла исчезнуть после обновления — пропускаем.
		if Technologies.exists(tech_id):
			completed[tech_id] = true
	_recalculate_bonuses()


func _recalculate_bonuses() -> void:
	_bonuses.clear()
	for tech_id: StringName in completed:
		var bonuses: Dictionary = Technologies.bonuses(tech_id)
		for key: StringName in bonuses:
			_bonuses[key] = _bonuses.get(key, 0.0) + float(bonuses[key])
