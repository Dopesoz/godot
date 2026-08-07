class_name ResearchSystem
extends GameSystem

## Исследования: одно активное направление, лаборатории тратят на него колбы.
##
## Одно направление за раз — сознательное упрощение для телефона: очередь
## исследований потребовала бы отдельного экрана управления, а выигрыш дала бы
## только опытному игроку.

var state: ResearchState = null

## Что изучаем сейчас (&"" — ничего).
var current: StringName = &""
## Сколько колб каждого вида уже вложено.
var invested: Dictionary[StringName, int] = {}


func system_name() -> String:
	return "исследования"


func _on_setup() -> void:
	state = world.research


func reset() -> void:
	current = &""
	invested.clear()


## --- Управление ------------------------------------------------------------

func can_start(tech_id: StringName) -> bool:
	return state != null and state.is_available(tech_id)


func start(tech_id: StringName) -> bool:
	if not can_start(tech_id):
		return false
	current = tech_id
	invested.clear()
	Events.research_progress_changed.emit(current, progress())
	return true


func cancel() -> void:
	# Вложенные колбы не возвращаются: иначе исследование можно было бы
	# использовать как бесплатное хранилище.
	current = &""
	invested.clear()
	Events.research_progress_changed.emit(&"", 0.0)


## Доля выполнения текущего исследования, 0..1.
func progress() -> float:
	if current == &"":
		return 0.0
	var total: int = Technologies.total_cost(current)
	if total <= 0:
		return 1.0
	var done: int = 0
	for item_id: StringName in invested:
		done += invested[item_id]
	return clampf(float(done) / float(total), 0.0, 1.0)


## Чего ещё не хватает текущему исследованию.
func remaining_cost() -> Dictionary[StringName, int]:
	var remaining: Dictionary[StringName, int] = {}
	if current == &"":
		return remaining
	var cost: Dictionary = Technologies.cost(current)
	for item_id: StringName in cost:
		var left: int = int(cost[item_id]) - invested.get(item_id, 0)
		if left > 0:
			remaining[item_id] = left
	return remaining


## --- Симуляция -------------------------------------------------------------

func tick(delta: float, context: Dictionary) -> void:
	var registry: BuildingRegistry = context["registry"]
	var labs: Array[Building] = registry.of_kind(BuildingDefs.Kind.LAB)
	if labs.is_empty():
		return

	var needed: Dictionary[StringName, int] = remaining_cost()
	var wanted: Array[StringName] = []
	for item_id: StringName in needed:
		wanted.append(item_id)

	for lab_building: Building in labs:
		var lab: Lab = lab_building
		# Лаборатория не знает про дерево технологий: что нужно, ей сообщают.
		lab.required_science = wanted
		if wanted.is_empty():
			lab.status = Building.Status.IDLE if lab.enabled else Building.Status.DISABLED
			continue
		var consumed: int = lab.consume(delta)
		if consumed > 0:
			_invest(consumed)


## Записывает потреблённые колбы в прогресс.
func _invest(consumed: int) -> void:
	var left: int = consumed
	for item_id: StringName in remaining_cost():
		if left <= 0:
			break
		invested[item_id] = invested.get(item_id, 0) + 1
		left -= 1
	Events.research_progress_changed.emit(current, progress())
	if remaining_cost().is_empty():
		_complete()


func _complete() -> void:
	var finished: StringName = current
	state.complete(finished)
	current = &""
	invested.clear()
	Events.research_completed.emit(finished)
	Events.unlocks_changed.emit()
	Events.notify.emit("Изучено: %s" % Technologies.display_name(finished))


## --- Сохранение ------------------------------------------------------------

func serialize() -> Dictionary:
	var progress_data: Dictionary = {}
	for item_id: StringName in invested:
		progress_data[String(item_id)] = invested[item_id]
	return {"current": String(current), "invested": progress_data}


func deserialize(data: Dictionary) -> void:
	current = StringName(data.get("current", ""))
	if not Technologies.exists(current):
		current = &""
	invested.clear()
	for key: Variant in data.get("invested", {}):
		var item_id := StringName(key)
		if Items.exists(item_id):
			invested[item_id] = int(data["invested"][key])
