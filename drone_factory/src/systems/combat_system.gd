class_name CombatSystem
extends GameSystem

## Жуки, волны и турели.
##
## Это намеренно не главная механика. Игра про постройку фабрики, которая
## работает сама, поэтому оборона устроена так, чтобы её можно было решить
## один раз и вернуться к производству:
##
##   * волны редкие и предупреждаются заранее — игрок не обязан сидеть у экрана;
##   * жуки идут к ближайшей постройке по прямой, без хитростей;
##   * стена и турель полностью закрывают вопрос, если их построили;
##   * гнёзда можно снести, и тогда оттуда никто больше не придёт.
##
## Из этого следует важное свойство баланса: наказание за отсутствие обороны
## — потеря нескольких зданий на краю базы, а не проигрыш. Проиграть в этой
## игре нельзя, и добавление жуков этого не меняет.

## Первая волна не раньше этого времени, секунды. Игроку нужно успеть
## разобраться с производством, прежде чем к нему придут.
const GRACE_PERIOD: float = 600.0
## Средний промежуток между волнами, секунды.
const MEAN_INTERVAL: float = 420.0
## Сколько жуков в первой волне и насколько каждая следующая больше.
const BASE_WAVE_SIZE: int = 3
const WAVE_GROWTH: float = 0.6
## Предел жуков в волне: телефон должен пережить и двадцатую волну.
const MAX_WAVE_SIZE: int = 24
## Предел живых жуков одновременно.
const MAX_ALIVE: int = 60

## Гнёзда ставятся не ближе этого расстояния от базы, в клетках.
const NEST_MIN_DISTANCE: int = 34
const NEST_MAX_DISTANCE: int = 70
## Сколько гнёзд появляется на карте при старте партии.
const NEST_COUNT: int = 4

## Как часто жуки пересматривают цель, в тиках. Каждый тик искать заново
## слишком дорого, а раз в две секунды глазу незаметно.
const RETARGET_TICKS: int = 20

var monsters: Array[Monster] = []
var wave_number: int = 0
var next_wave_at: float = GRACE_PERIOD

var _next_monster_id: int = 1
var _rng: RandomNumberGenerator = null
var _ticks: int = 0


func system_name() -> String:
	return "жуки"


func reset() -> void:
	monsters.clear()
	wave_number = 0
	next_wave_at = GRACE_PERIOD
	_next_monster_id = 1
	_ticks = 0


func _on_setup() -> void:
	_rng = Rng.stream(world.world_seed + 5501)


## Расставляет гнёзда вокруг базы. Вызывается при создании новой игры —
## в сохранении гнёзда лежат обычными зданиями и заново не создаются.
func populate_nests() -> int:
	if world == null or world.buildings == null:
		return 0
	var rng: RandomNumberGenerator = Rng.stream(world.world_seed + 991)
	var placed: int = 0
	for i: int in NEST_COUNT:
		for attempt: int in 40:
			var angle: float = rng.randf() * TAU
			var distance: float = rng.randf_range(
				float(NEST_MIN_DISTANCE), float(NEST_MAX_DISTANCE)
			)
			var cell: Vector2i = world.start_cell + Vector2i(
				int(cos(angle) * distance), int(sin(angle) * distance)
			)
			if world.buildings.can_place(BuildingDefs.NEST, cell):
				world.buildings.place(BuildingDefs.NEST, cell)
				placed += 1
				break
	return placed


func tick(delta: float, context: Dictionary) -> void:
	var registry: BuildingRegistry = context["registry"]
	var research: ResearchState = context.get("research")
	_ticks += 1

	_advance_monsters(registry, delta)
	_fire_turrets(registry, research, delta)
	_maybe_start_wave(registry, float(context.get("time", 0.0)))
	_cleanup()


func alive_count() -> int:
	var count: int = 0
	for monster: Monster in monsters:
		if monster.is_alive():
			count += 1
	return count


## Сколько секунд осталось до следующей волны. Отрицательное — уже идёт.
func seconds_to_wave(game_time: float) -> float:
	return next_wave_at - game_time


## --- Волны -----------------------------------------------------------------

func _maybe_start_wave(registry: BuildingRegistry, game_time: float) -> void:
	if game_time < next_wave_at:
		return
	var nests: Array[Building] = registry.of_kind(BuildingDefs.Kind.NEST)
	# Снесли все гнёзда — волн больше нет. Это и есть награда за зачистку.
	if nests.is_empty():
		next_wave_at = game_time + MEAN_INTERVAL
		return

	wave_number += 1
	var size: int = mini(
		BASE_WAVE_SIZE + int(float(wave_number) * WAVE_GROWTH), MAX_WAVE_SIZE
	)
	var spawned: int = 0
	for i: int in size:
		if alive_count() >= MAX_ALIVE:
			break
		var nest: Building = nests[_rng.randi() % nests.size()]
		_spawn(nest, wave_number)
		spawned += 1

	next_wave_at = game_time + MEAN_INTERVAL * _rng.randf_range(0.75, 1.25)
	Events.wave_started.emit(wave_number, spawned)
	Events.notify.emit("Волна %d: жуков %d" % [wave_number, spawned])


func _spawn(nest: Building, wave: int) -> void:
	var monster := Monster.new()
	monster.id = _next_monster_id
	_next_monster_id += 1
	# Жуки поздних волн крепче, но не быстрее: скорость — это время на реакцию,
	# и отнимать его у игрока нечестно.
	monster.max_health = 60 + wave * 8
	monster.health = monster.max_health
	monster.position = nest.center() + Vector2(
		_rng.randf_range(-24.0, 24.0), _rng.randf_range(-24.0, 24.0)
	)
	monster.previous_position = monster.position
	monsters.append(monster)


## --- Движение и атака ------------------------------------------------------

func _advance_monsters(registry: BuildingRegistry, delta: float) -> void:
	var retarget: bool = _ticks % RETARGET_TICKS == 0
	for monster: Monster in monsters:
		if not monster.is_alive():
			continue
		var target: Building = registry.get_building(monster.target_id)
		if target == null or retarget:
			target = _pick_target(registry, monster)
			monster.target_id = 0 if target == null else target.id
		if target == null:
			continue

		monster.attack_cooldown = maxf(monster.attack_cooldown - delta, 0.0)
		if not monster.advance_to(target.center(), delta):
			monster.state = Monster.State.WALKING
			continue

		monster.state = Monster.State.ATTACKING
		if monster.attack_cooldown > 0.0:
			continue
		monster.attack_cooldown = Monster.ATTACK_INTERVAL
		if target.take_damage(Monster.DAMAGE):
			_destroy(registry, target)
			monster.target_id = 0


## Цель жука — ближайшая постройка игрока. Стены при равном расстоянии
## предпочтительнее: иначе забор бесполезен, жуки просто обтекали бы его.
func _pick_target(registry: BuildingRegistry, monster: Monster) -> Building:
	var best: Building = null
	var best_score: float = INF
	for building: Building in registry.all():
		if BuildingDefs.kind(building.def_id) == BuildingDefs.Kind.NEST:
			continue
		if not BuildingDefs.is_player_built(building.def_id):
			continue
		var score: float = monster.position.distance_to(building.center())
		if BuildingDefs.blocks_monsters(building.def_id):
			score *= 0.75
		if score < best_score:
			best_score = score
			best = building
	return best


func _destroy(registry: BuildingRegistry, building: Building) -> void:
	Events.notify.emit("Жуки разрушили: %s" % building.display_name())
	registry.remove(building.id)


## --- Турели ----------------------------------------------------------------

func _fire_turrets(
	registry: BuildingRegistry, research: ResearchState, delta: float
) -> void:
	var turrets: Array[Building] = registry.of_kind(BuildingDefs.Kind.TURRET)
	if turrets.is_empty():
		return
	var bonus: float = 1.0 if research == null else research.multiplier(
		Technologies.BONUS_TURRET_DAMAGE
	)
	for building: Building in turrets:
		var turret: Turret = building
		turret.damage_multiplier = bonus
		turret.reload_left = maxf(turret.reload_left - delta, 0.0)
		if not turret.can_fire():
			continue
		var victim: Monster = _closest_monster(turret)
		if victim == null:
			continue
		if victim.take_damage(turret.fire()):
			Events.monster_killed.emit(victim.id)
		Events.turret_fired.emit(turret.id)


func _closest_monster(turret: Turret) -> Monster:
	var reach: float = turret.range_cells() * float(Constants.TILE_SIZE)
	var reach_squared: float = reach * reach
	var centre: Vector2 = turret.center()
	var best: Monster = null
	var best_distance: float = INF
	for monster: Monster in monsters:
		if not monster.is_alive():
			continue
		var distance: float = centre.distance_squared_to(monster.position)
		if distance <= reach_squared and distance < best_distance:
			best_distance = distance
			best = monster
	return best


func _cleanup() -> void:
	var alive: Array[Monster] = []
	for monster: Monster in monsters:
		if monster.is_alive():
			alive.append(monster)
	if alive.size() != monsters.size():
		monsters = alive


## --- Сохранение ------------------------------------------------------------

func serialize() -> Dictionary:
	var list: Array = []
	for monster: Monster in monsters:
		list.append(monster.serialize())
	return {
		"wave": wave_number,
		"next": next_wave_at,
		"next_id": _next_monster_id,
		"monsters": list,
	}


func deserialize(data: Dictionary) -> void:
	monsters.clear()
	for entry: Variant in data.get("monsters", []):
		var monster := Monster.new()
		monster.deserialize(entry)
		monsters.append(monster)
	wave_number = int(data.get("wave", 0))
	next_wave_at = float(data.get("next", GRACE_PERIOD))
	_next_monster_id = int(data.get("next_id", monsters.size() + 1))
