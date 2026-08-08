class_name AchievementSystem
extends GameSystem

## Достижения и накопительная статистика партии.
##
## Статистика набирается по событиям (что произвели, что построили, что
## изучили), а условия проверяются раз в полсекунды, а не на каждое событие:
## печь выдаёт пластины десятки раз в секунду, и гонять по ним весь список
## достижений — впустую жечь батарею.

## Как часто пересчитывать условия, в тиках.
const CHECK_EVERY_TICKS: int = 5

var stats: GameStats = null
var unlocked: Dictionary[StringName, bool] = {}

var _connected: bool = false


func system_name() -> String:
	return "достижения"


func _on_setup() -> void:
	stats = world.stats
	if _connected:
		return
	_connected = true
	Events.items_produced.connect(_on_items_produced)
	Events.items_harvested.connect(_on_items_harvested)
	Events.building_placed.connect(_on_building_placed)
	Events.research_completed.connect(_on_research_completed)


func reset() -> void:
	unlocked.clear()


func tick(_delta: float, context: Dictionary) -> void:
	if int(context.get("tick", 0)) % CHECK_EVERY_TICKS != 0:
		return
	for id: StringName in Achievements.all_ids():
		if unlocked.has(id):
			continue
		if Conditions.is_met(Achievements.condition(id), stats, world.research):
			_unlock(id)


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func unlocked_count() -> int:
	return unlocked.size()


## Текст прогресса достижения для панели.
func progress_text(id: StringName) -> String:
	return Conditions.progress_text(Achievements.condition(id), stats, world.research)


func _unlock(id: StringName) -> void:
	unlocked[id] = true
	var reward: String = _grant_reward(id)
	Events.achievement_unlocked.emit(id)
	Events.notify.emit("Достижение: %s%s" % [
		Achievements.display_name(id), "" if reward.is_empty() else " (+%s)" % reward,
	])


## Награда кладётся на склад тем же путём, что и всё остальное в игре: через
## общее хранилище. Если складов нет или они забиты, награда просто пропадает —
## заводить ради неё отдельный «карман игрока» значило бы завести второй,
## параллельный способ хранить вещи.
func _grant_reward(id: StringName) -> String:
	var reward: Dictionary = Achievements.reward(id)
	if reward.is_empty() or world == null or world.buildings == null:
		return ""
	var pool := ResourcePool.new(world.buildings)
	var delivered: PackedStringArray = PackedStringArray()
	for item_id: StringName in reward:
		var amount: int = int(reward[item_id])
		# give() возвращает остаток, который некуда положить.
		var accepted: int = amount - pool.give(item_id, amount)
		if accepted > 0:
			delivered.append("%s %d" % [Items.display_name(item_id), accepted])
	return ", ".join(delivered)


## --- Сбор статистики -------------------------------------------------------

func _on_items_produced(item_id: StringName, count: int) -> void:
	if stats != null:
		stats.add(GameStats.produced_key(item_id), count)


func _on_items_harvested(item_id: StringName, count: int) -> void:
	if stats != null:
		stats.add(GameStats.mined_key(item_id), count)


func _on_building_placed(building_id: int) -> void:
	if stats == null or world == null or world.buildings == null:
		return
	var building: Building = world.buildings.get_building(building_id)
	if building != null:
		stats.add(GameStats.built_key(building.def_id))


func _on_research_completed(_tech_id: StringName) -> void:
	if stats != null:
		stats.add(GameStats.TECHS_KEY)


## --- Сохранение ------------------------------------------------------------

func serialize() -> Array:
	var list: Array = []
	for id: StringName in unlocked:
		list.append(String(id))
	return list


func deserialize(list: Array) -> void:
	unlocked.clear()
	for entry: Variant in list:
		var id := StringName(entry)
		# Достижение могло исчезнуть после обновления игры — пропускаем.
		if Achievements.exists(id):
			unlocked[id] = true
