extends Node

## Autoload: SimScheduler
##
## Owns the simulation heartbeat (design doc §27). No citizen ever implements
## `_process`; they implement SimAgent.sim_tick and register here.
##
## Three things this buys us:
##   1. Level of detail — agents near the camera think 10x a second, distant
##      ones once a second, off-screen ones once a game hour.
##   2. Load spreading — FULL agents are ticked round-robin across frames, so
##      200 citizens never all think on the same frame.
##   3. One pause switch — when the clock is paused, nothing simulates.
##
## Because every tick receives *elapsed game minutes* rather than a fixed step,
## changing the game speed or the LOD never changes how fast a citizen gets
## hungry. Only how smoothly you see it happen.

class Entry:
	var agent: SimAgent
	var lod: GameEnums.SimLOD = GameEnums.SimLOD.FULL
	var last_minutes: float = 0.0

	func _init(a: SimAgent, now: float) -> void:
		agent = a
		last_minutes = now

var _entries: Array[Entry] = []
## Round-robin cursors, one per real-time LOD bucket.
var _cursor_full: int = 0
var _cursor_reduced: int = 0
## Fractional carry so a small per-frame budget still adds up to the right rate.
var _budget_full: float = 0.0
var _budget_reduced: float = 0.0

## Camera focus in cells, set by the camera rig each frame.
var _focus_cell: Vector2i = Vector2i.ZERO
var _lod_refresh_timer: float = 0.0
## Cached once: the radii depend on the device, not on the frame.
var _full_radius: float = GameConstants.LOD_FULL_RADIUS
var _reduced_radius: float = GameConstants.LOD_REDUCED_RADIUS

## Diagnostics for the debug overlay.
var counts: Dictionary = {
	GameEnums.SimLOD.FULL: 0,
	GameEnums.SimLOD.REDUCED: 0,
	GameEnums.SimLOD.ABSTRACT: 0,
}


func _ready() -> void:
	EventBus.hour_passed.connect(_on_hour_passed)
	_full_radius = Platform.full_detail_radius()
	_reduced_radius = Platform.reduced_detail_radius()


func register(agent: SimAgent) -> void:
	if agent == null:
		return
	for entry in _entries:
		if entry.agent == agent:
			return
	_entries.append(Entry.new(agent, GameClock.total_minutes))


func unregister(agent: SimAgent) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i].agent == agent:
			_entries.remove_at(i)


func clear() -> void:
	_entries.clear()
	_cursor_full = 0
	_cursor_reduced = 0


func set_focus_cell(cell: Vector2i) -> void:
	_focus_cell = cell


func agent_count() -> int:
	return _entries.size()


func _process(delta: float) -> void:
	_lod_refresh_timer -= delta
	if _lod_refresh_timer <= 0.0:
		_lod_refresh_timer = 0.5
		_refresh_lods()
	if GameClock.is_paused():
		return
	_tick_bucket(GameEnums.SimLOD.FULL, GameConstants.SIM_HZ_FULL, delta)
	_tick_bucket(GameEnums.SimLOD.REDUCED, GameConstants.SIM_HZ_REDUCED, delta)


## Ticks a slice of one bucket. The slice size is chosen so that, over one
## second, every agent in the bucket is visited `hz` times — regardless of how
## many agents there are or what the frame rate is.
func _tick_bucket(lod: GameEnums.SimLOD, hz: float, delta: float) -> void:
	var bucket: Array[Entry] = []
	for entry in _entries:
		if entry.lod == lod:
			bucket.append(entry)
	if bucket.is_empty():
		return

	var wanted := float(bucket.size()) * hz * delta
	var cursor := _cursor_full if lod == GameEnums.SimLOD.FULL else _cursor_reduced
	var budget := _budget_full if lod == GameEnums.SimLOD.FULL else _budget_reduced
	budget += wanted
	var steps := int(budget)
	budget -= float(steps)
	# Never spend more than one full pass in a single frame, even after a hitch.
	steps = mini(steps, bucket.size())

	var now := GameClock.total_minutes
	for i in steps:
		var entry := bucket[cursor % bucket.size()]
		cursor += 1
		var elapsed := now - entry.last_minutes
		entry.last_minutes = now
		if elapsed > 0.0:
			entry.agent.sim_tick(elapsed, lod)

	if lod == GameEnums.SimLOD.FULL:
		_cursor_full = cursor % maxi(bucket.size(), 1)
		_budget_full = budget
	else:
		_cursor_reduced = cursor % maxi(bucket.size(), 1)
		_budget_reduced = budget


## ABSTRACT agents are not on a real-time schedule at all: they get one tick per
## game hour, which is why a thousand distant citizens cost almost nothing.
func _on_hour_passed(_hour: int) -> void:
	var now := GameClock.total_minutes
	for entry in _entries:
		if entry.lod != GameEnums.SimLOD.ABSTRACT:
			continue
		var elapsed := now - entry.last_minutes
		entry.last_minutes = now
		if elapsed > 0.0:
			entry.agent.sim_tick(elapsed, GameEnums.SimLOD.ABSTRACT)


## Reassigns detail levels from camera distance and drops dead agents. Runs at
## 2 Hz — LOD does not need frame accuracy, and this pass is O(n).
func _refresh_lods() -> void:
	counts[GameEnums.SimLOD.FULL] = 0
	counts[GameEnums.SimLOD.REDUCED] = 0
	counts[GameEnums.SimLOD.ABSTRACT] = 0
	for i in range(_entries.size() - 1, -1, -1):
		var entry := _entries[i]
		if not entry.agent.is_sim_alive():
			_entries.remove_at(i)
			continue
		var distance := float(IsoUtils.cell_distance(entry.agent.get_sim_cell(), _focus_cell))
		var new_lod := GameEnums.SimLOD.ABSTRACT
		if distance <= _full_radius:
			new_lod = GameEnums.SimLOD.FULL
		elif distance <= _reduced_radius:
			new_lod = GameEnums.SimLOD.REDUCED
		if new_lod != entry.lod:
			var old_lod := entry.lod
			entry.lod = new_lod
			# Settle the agent's outstanding time before it changes rhythm, so
			# no game minutes are lost or double-counted at the boundary.
			var now := GameClock.total_minutes
			var elapsed := now - entry.last_minutes
			entry.last_minutes = now
			if elapsed > 0.0:
				entry.agent.sim_tick(elapsed, old_lod)
			entry.agent.on_lod_changed(old_lod, new_lod)
		counts[entry.lod] = int(counts[entry.lod]) + 1
