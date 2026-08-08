class_name Conditions
extends RefCounted

## Вычислитель условий для достижений и задач сюжета.
##
## Одна реализация на обе системы: условия описываются одинаковыми словарями,
## и правило «сколько уже сделано» не расходится между экранами.


## Текущее значение и цель условия. По ним рисуются и галочка, и полоска.
static func progress(condition: Dictionary, stats: GameStats, research: ResearchState) -> Vector2i:
	var target: int = maxi(int(condition.get("target", 1)), 1)
	match String(condition.get("kind", "")):
		"item":
			return Vector2i(stats.total_of(StringName(condition.get("item", ""))), target)
		"built":
			return Vector2i(
				stats.get_count(GameStats.built_key(StringName(condition.get("def", "")))),
				target
			)
		"techs":
			return Vector2i(stats.get_count(GameStats.TECHS_KEY), target)
		"tech":
			var tech_id := StringName(condition.get("tech", ""))
			var done: bool = research != null and research.is_completed(tech_id)
			return Vector2i(1 if done else 0, 1)
		_:
			return Vector2i(0, target)


static func is_met(condition: Dictionary, stats: GameStats, research: ResearchState) -> bool:
	var value: Vector2i = progress(condition, stats, research)
	return value.x >= value.y


## Короткая подпись прогресса для интерфейса: «43 / 100».
static func progress_text(condition: Dictionary, stats: GameStats, research: ResearchState) -> String:
	var value: Vector2i = progress(condition, stats, research)
	if value.y <= 1:
		return "готово" if value.x >= value.y else "не выполнено"
	return "%d / %d" % [mini(value.x, value.y), value.y]
