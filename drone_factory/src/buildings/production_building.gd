class_name ProductionBuilding
extends Building

## Общая логика машины с рецептом: печь, сборщик.
##
## Очередь производства — список заданий «рецепт × количество». Задание с
## количеством REPEAT повторяется бесконечно: на телефоне переключать рецепт
## вручную неудобно, и большая часть машин должна работать «поставил и забыл».
##
## Машина не тянет ресурсы сама: их привозят дроны по её запросам (requests()).
## Это единственный вид логистики в игре, и правило соблюдается везде.

## Специальное значение количества: повторять, пока игрок не отменит.
const REPEAT: int = -1
## Сколько порций сырья машина просит про запас (в порциях рецепта).
const REQUEST_BATCH: int = 5

## Очередь: массив словарей {"recipe": StringName, "count": int}.
var queue: Array[Dictionary] = []
## Прогресс текущей порции, 0..1.
var progress: float = 0.0


func machine_kind() -> int:
	return Recipes.Machine.ASSEMBLER


func speed() -> float:
	return power_satisfaction


## --- Очередь ---------------------------------------------------------------

func current_recipe() -> StringName:
	if queue.is_empty():
		return &""
	return queue[0]["recipe"]


func enqueue(recipe_id: StringName, count: int = REPEAT) -> bool:
	if not Recipes.exists(recipe_id) or Recipes.machine(recipe_id) != machine_kind():
		return false
	# Повтор того же рецепта в конце очереди просто увеличивает количество.
	if not queue.is_empty():
		var last: Dictionary = queue[queue.size() - 1]
		if last["recipe"] == recipe_id and int(last["count"]) >= 0 and count >= 0:
			last["count"] = int(last["count"]) + count
			_notify_queue()
			return true
	queue.append({"recipe": recipe_id, "count": count})
	_update_input_filter()
	_notify_queue()
	return true


## Заменяет очередь одним заданием — обычный сценарий выбора рецепта в панели.
func set_recipe(recipe_id: StringName, count: int = REPEAT) -> bool:
	if not Recipes.exists(recipe_id) or Recipes.machine(recipe_id) != machine_kind():
		return false
	queue.clear()
	progress = 0.0
	return enqueue(recipe_id, count)


func remove_job(index: int) -> void:
	if index < 0 or index >= queue.size():
		return
	if index == 0:
		progress = 0.0
	queue.remove_at(index)
	_update_input_filter()
	_notify_queue()


func clear_queue() -> void:
	queue.clear()
	progress = 0.0
	_update_input_filter()
	_notify_queue()


func queue_size() -> int:
	return queue.size()


## --- Симуляция -------------------------------------------------------------

func tick(delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	var recipe_id: StringName = current_recipe()
	if recipe_id == &"":
		status = Status.IDLE
		return
	if power_satisfaction <= 0.01:
		status = Status.NO_POWER
		return
	if not output.fits_all(Recipes.outputs(recipe_id)):
		status = Status.OUTPUT_FULL
		return

	if progress <= 0.0:
		# Сырьё списывается в начале порции: так вход не «зависает» наполовину
		# и дроны сразу видят, чего не хватает.
		if not input.consume_all(Recipes.inputs(recipe_id)):
			status = Status.NO_INPUT
			return
		progress = 0.0001

	progress += speed() * delta / Recipes.craft_time(recipe_id)
	status = Status.WORKING
	if progress < 1.0:
		return

	progress = 0.0
	output.add_all(Recipes.outputs(recipe_id))
	for item_id: StringName in Recipes.outputs(recipe_id):
		Events.items_produced.emit(item_id, int(Recipes.outputs(recipe_id)[item_id]))
	Events.inventory_changed.emit(id)
	_consume_job()


func _consume_job() -> void:
	if queue.is_empty():
		return
	var job: Dictionary = queue[0]
	var count: int = int(job["count"])
	if count == REPEAT:
		return
	job["count"] = count - 1
	if int(job["count"]) <= 0:
		queue.remove_at(0)
		_update_input_filter()
	_notify_queue()


## --- Логистика -------------------------------------------------------------

## Чего не хватает для работы: дроны привозят именно это.
func requests() -> Dictionary[StringName, int]:
	var needed: Dictionary[StringName, int] = {}
	var recipe_id: StringName = current_recipe()
	if recipe_id == &"" or not enabled:
		return needed
	for item_id: StringName in Recipes.inputs(recipe_id):
		var per_batch: int = int(Recipes.inputs(recipe_id)[item_id])
		var target: int = per_batch * REQUEST_BATCH
		var missing: int = target - input.count(item_id)
		if missing > 0:
			needed[item_id] = mini(missing, input.free_space())
	return needed


## Вход принимает только то, что нужно текущей очереди: иначе дрон может
## забить буфер лишним и машина встанет.
func _update_input_filter() -> void:
	if input == null:
		return
	var allowed: Array[StringName] = []
	for job: Dictionary in queue:
		for item_id: StringName in Recipes.inputs(job["recipe"]):
			if not allowed.has(item_id):
				allowed.append(item_id)
	input.filter = allowed


func _notify_queue() -> void:
	Events.production_queue_changed.emit(id)


## --- Сохранение ------------------------------------------------------------

func _serialize_extra() -> Dictionary:
	var jobs: Array = []
	for job: Dictionary in queue:
		jobs.append({"r": String(job["recipe"]), "c": int(job["count"])})
	return {"queue": jobs, "progress": progress}


func _deserialize_extra(data: Dictionary) -> void:
	queue.clear()
	for entry: Variant in data.get("queue", []):
		var job: Dictionary = entry
		var recipe_id := StringName(job.get("r", ""))
		# Рецепт мог исчезнуть после обновления игры — задание просто пропускаем.
		if Recipes.exists(recipe_id) and Recipes.machine(recipe_id) == machine_kind():
			queue.append({"recipe": recipe_id, "count": int(job.get("c", REPEAT))})
	progress = clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
	_update_input_filter()
