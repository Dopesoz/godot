class_name StorySystem
extends GameSystem

## Ведёт игрока по главам: одна активная задача за раз.
##
## Это одновременно сюжет и обучение. Одна задача вместо списка — сознательное
## решение для телефона: игрок открывает игру на пять минут и должен сразу
## видеть, что делать дальше, а не выбирать из десяти веток.

## Проверяем условие не каждый тик: событий производства слишком много.
const CHECK_EVERY_TICKS: int = 5

var current: int = 0
var won: bool = false

var _stats: GameStats = null


func system_name() -> String:
	return "сюжет"


func _on_setup() -> void:
	_stats = world.stats
	if not Events.game_won.is_connected(_on_game_won):
		Events.game_won.connect(_on_game_won)


func reset() -> void:
	current = 0
	won = false


## --- Текущая глава ---------------------------------------------------------

func is_finished() -> bool:
	return current >= Story.chapter_count()


func chapter() -> Dictionary:
	return Story.chapter_at(current)


func hint() -> String:
	if is_finished():
		return "Все задачи выполнены"
	return String(chapter().get("hint", ""))


func title() -> String:
	if is_finished():
		return Story.ENDING_TITLE
	return String(chapter().get("title", ""))


func progress_text() -> String:
	if is_finished():
		return ""
	var condition: Dictionary = chapter().get("objective", {})
	if String(condition.get("kind", "")) == "won":
		return "передача идёт" if not won else "готово"
	return Conditions.progress_text(condition, _stats, world.research)


## --- Симуляция -------------------------------------------------------------

func tick(_delta: float, context: Dictionary) -> void:
	if is_finished() or int(context.get("tick", 0)) % CHECK_EVERY_TICKS != 0:
		return
	if not _objective_met():
		return
	_advance()


func _objective_met() -> bool:
	var condition: Dictionary = chapter().get("objective", {})
	# Финальная глава завершается не счётчиком, а самим фактом победы.
	if String(condition.get("kind", "")) == "won":
		return won
	return Conditions.is_met(condition, _stats, world.research)


## Пропустить главу, не выполняя задачу. Нужно режиму разработчика: иначе
## поздние главы приходится ждать, даже когда всё нужное уже построено.
func force_advance() -> void:
	if not is_finished():
		_advance()


func _advance() -> void:
	var finished: Dictionary = chapter()
	_grant_reward(finished.get("reward", {}))
	current += 1

	var next_id: StringName = &"" if is_finished() else StringName(chapter()["id"])
	Events.story_advanced.emit(StringName(finished["id"]), next_id)
	if is_finished():
		return
	Events.notify.emit("Новая задача: %s" % hint())


## Награда падает на склад: это ровно то, чем строится следующий шаг, чтобы
## новичок не застрял на нехватке материалов в первые минуты.
func _grant_reward(reward: Dictionary) -> void:
	if reward.is_empty():
		return
	var pool := ResourcePool.new(world.buildings)
	for item_id: StringName in reward:
		pool.give(item_id, int(reward[item_id]))


func _on_game_won() -> void:
	won = true


## --- Сохранение ------------------------------------------------------------

func serialize() -> Dictionary:
	return {"chapter": current, "won": won}


func deserialize(data: Dictionary) -> void:
	current = clampi(int(data.get("chapter", 0)), 0, Story.chapter_count())
	won = bool(data.get("won", false))
