extends Node
## Автозагрузка `Events` — единственная точка обмена сообщениями между подсистемами.
##
## Правило проекта: системы (симуляция) НЕ знают про UI. Они публикуют события сюда,
## UI подписывается. Это держит зависимости однонаправленными и позволяет
## тестировать симуляцию headless, без сцен.

## --- Мир -------------------------------------------------------------------

signal world_generated(seed_value: int)
## Изменилось содержимое клетки (руда выработана, поставлено/снесено здание).
signal cell_changed(cell: Vector2i)

## --- Здания ----------------------------------------------------------------

signal building_placed(building_id: int)
signal building_removed(building_id: int)
signal building_state_changed(building_id: int)
## Изменился инвентарь здания (или общий склад).
signal inventory_changed(building_id: int)

## --- Электричество ---------------------------------------------------------

signal power_stats_changed(produced: float, consumed: float, satisfaction: float)
## Загрязнение и его влияние на солнечные панели (1.0 — чистое небо).
signal pollution_changed(level: float, solar_factor: float)

## --- Логистика -------------------------------------------------------------

signal drone_count_changed(active: int, total: int)

## --- Статистика ------------------------------------------------------------

## Машина выпустила предметы.
signal items_produced(item_id: StringName, count: int)
## Бур или насос добыл сырьё.
signal items_harvested(item_id: StringName, count: int)
## Открыто достижение.
signal achievement_unlocked(achievement_id: StringName)

## --- Производство и исследования -------------------------------------------

signal production_queue_changed(building_id: int)
signal research_progress_changed(tech_id: StringName, progress: float)
signal research_completed(tech_id: StringName)
signal unlocks_changed()

## --- Сюжет -----------------------------------------------------------------

## Пройдена очередная глава: id завершённой и id следующей (&"" — история кончилась).
signal story_advanced(finished_id: StringName, next_id: StringName)
## Маяк заряжается: 0..1.
signal beacon_progress(progress: float)
## Игра пройдена.
signal game_won()

## --- Игровой цикл / UI -----------------------------------------------------

signal game_saved()
signal game_loaded()
signal game_reset()
## Короткое сообщение игроку (тост).
## --- Оборона ---------------------------------------------------------------

signal building_damaged(building_id: int)
signal wave_started(wave_number: int, size: int)
signal monster_killed(monster_id: int)
signal turret_fired(turret_id: int)
signal nest_evolved(nest_id: int)
signal nest_destroyed(nest_id: int)

signal notify(text: String)
## Игрок выбрал здание на карте (-1 — выбор снят).
## Игрок тапнул по иконке ресурса и хочет о нём почитать.
signal item_inspected(item_id: StringName)

signal selection_changed(building_id: int)
## Игрок выбрал здание для постройки (&"" — режим строительства выключен).
signal build_selection_changed(def_id: StringName)
