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

## --- Логистика -------------------------------------------------------------

signal drone_count_changed(active: int, total: int)

## --- Производство и исследования -------------------------------------------

signal production_queue_changed(building_id: int)
signal research_progress_changed(tech_id: StringName, progress: float)
signal research_completed(tech_id: StringName)
signal unlocks_changed()

## --- Игровой цикл / UI -----------------------------------------------------

signal game_saved()
signal game_loaded()
signal game_reset()
## Короткое сообщение игроку (тост).
signal notify(text: String)
## Игрок выбрал здание на карте (-1 — выбор снят).
signal selection_changed(building_id: int)
## Игрок выбрал здание для постройки (&"" — режим строительства выключен).
signal build_selection_changed(def_id: StringName)
