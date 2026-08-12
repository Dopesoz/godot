extends Node2D

## Short-lived text that rises out of the world: wages earned, a friendship
## formed, a skill levelled.
##
## The point is not decoration. Most of what this simulation does is invisible —
## a number moves somewhere in a model — and the player is being asked to care
## about people they can only watch. Floating text is the cheapest way to make
## an internal event legible exactly where it happened.
##
## Everything here is drawn in one canvas item and dies on its own; nothing is
## instanced, so a busy city cannot spawn a thousand nodes.

const LIFETIME := 2.4
const RISE_PIXELS := 46.0
const MAX_ITEMS := 24

class Item:
	var text: String
	var position: Vector2
	var color: Color
	var age: float = 0.0
	var size: int = 14

var _items: Array[Item] = []
var _font: Font
var _citizens: CitizenRegistry


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_citizens = get_parent().get_node_or_null("Citizens") as CitizenRegistry
	EventBus.citizen_interaction_finished.connect(_on_interaction_finished)
	EventBus.relationship_changed.connect(_on_relationship_changed)
	EventBus.notice.connect(_on_notice)


## Adds a line above a world position, in fractional cell coordinates.
func add(text: String, cell: Vector2, color: Color = Color(1, 1, 1), size: int = 14) -> void:
	if _items.size() >= MAX_ITEMS:
		_items.pop_front()
	var item := Item.new()
	item.text = text
	item.position = IsoUtils.cell_to_world_f(cell) + Vector2(0.0, -34.0)
	item.color = color
	item.size = size
	_items.append(item)
	queue_redraw()


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	for i in range(_items.size() - 1, -1, -1):
		_items[i].age += delta
		if _items[i].age >= LIFETIME:
			_items.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for item in _items:
		var t := item.age / LIFETIME
		var offset := Vector2(0.0, -RISE_PIXELS * ease(t, 0.4))
		var color := item.color
		# Fades only in the last third, so it is readable for most of its life.
		color.a = clampf((1.0 - t) * 3.0, 0.0, 1.0)
		# The rise is in screen pixels, so it looks the same at any zoom — and
		# Labels keeps two messages about the same person off each other.
		var scale := maxf(get_global_transform_with_canvas().get_scale().x, 0.001)
		Labels.draw(self, _font, item.text, item.position + offset / scale, color, item.size,
				Color(0, 0, 0, color.a * 0.7))


func _on_interaction_finished(citizen_id: int, _furniture_id: int, action: String) -> void:
	var citizen := _citizen(citizen_id)
	if citizen == null:
		return
	add(tr(action), citizen.position, Color(0.85, 0.92, 1.0), 13)


## Only the milestone is worth showing; the number moves every minute they are
## in the same room.
func _on_relationship_changed(a: int, b: int, value: float) -> void:
	if absf(value - RelationshipRegistry.FRIEND_THRESHOLD) > 0.5:
		return
	var citizen := _citizen(a)
	var other := _citizen(b)
	if citizen == null or other == null:
		return
	add("♥ friends", (citizen.position + other.position) * 0.5, Color(1.0, 0.75, 0.9), 16)


## Skill level-ups and move-ins already announce themselves as notices; showing
## them in the world as well is what makes them feel like events rather than
## log lines.
func _on_notice(text: String) -> void:
	if not text.contains("reached"):
		return
	var name := text.split(" reached ")[0]
	for citizen: Citizen in (_citizens.all() if _citizens != null else []):
		if citizen.citizen_name == name:
			add("★ " + text.split(" reached ")[1], citizen.position, Color(1.0, 0.9, 0.55), 15)
			return


func _citizen(citizen_id: int) -> Citizen:
	if _citizens == null:
		return null
	return _citizens.citizens.get(citizen_id)
