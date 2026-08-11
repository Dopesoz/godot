class_name SimAgent
extends RefCounted

## Anything the SimScheduler can tick: a citizen, a shop, a family budget.
##
## Deliberately a plain RefCounted and not a Node. A simulated citizen exists
## whether or not their building is currently instantiated as a scene, which is
## what lets the city keep living while the player looks at one house
## (design doc §27).


## Advance this agent by `minutes` of game time at the given detail level.
## `minutes` is the real elapsed game time since this agent's previous tick, not
## a fixed step, so an agent that drops to a coarse LOD still ages correctly.
func sim_tick(_minutes: float, _lod: GameEnums.SimLOD) -> void:
	pass


## Where the agent is, for LOD selection. Off-map agents return a far-away cell.
func get_sim_cell() -> Vector2i:
	return Vector2i.ZERO


## False lets the scheduler drop the agent without an explicit unregister.
func is_sim_alive() -> bool:
	return true


## Called when the scheduler moves the agent between detail levels, e.g. so a
## citizen can snap its visual position after running in ABSTRACT mode.
func on_lod_changed(_old_lod: GameEnums.SimLOD, _new_lod: GameEnums.SimLOD) -> void:
	pass
