class_name GameEnums
extends RefCounted

## Central enum registry.
##
## GDScript has no project-wide enums, so every shared enum lives here and is
## referenced as `GameEnums.RoomType.BEDROOM`. Keeping them in one file means the
## save format (which stores raw ints) has exactly one place to stay in sync.
##
## IMPORTANT: never reorder existing entries — saved games store the integer
## value. Always append new entries at the end of an enum.


## What a building is used for. Drives economy and citizen destinations.
enum BuildingType {
	RESIDENTIAL,
	COMMERCIAL,
	INDUSTRIAL,
	PUBLIC,
}

## Room purpose. Set manually by the player in the MVP; auto-detection from
## furniture comes later (see design doc §9).
enum RoomType {
	UNDEFINED,
	LIVING_ROOM,
	BEDROOM,
	KITCHEN,
	BATHROOM,
	CHILDREN_ROOM,
	OFFICE,
	DINING_ROOM,
	GARAGE,
	HALLWAY,
	STORAGE,
	SHOP,
	RESTAURANT,
	CLASSROOM,
	HOSPITAL_ROOM,
}

## Citizen needs. All values are clamped to 0..100, where 0 is desperate.
enum NeedType {
	HUNGER,
	ENERGY,
	HYGIENE,
	COMFORT,
	ENTERTAINMENT,
	SOCIAL,
	## Not a life need but an obligation, modelled as one so it competes in the
	## same scoring formula instead of needing a parallel system. 0 means a full
	## day's work is still owed, 100 means today's shift is done. It is only
	## made urgent during the hours JobData defines (see Citizen.duty_weight).
	WORK,
}

## Citizen state machine states (design doc §14).
enum CitizenState {
	IDLE,
	WALKING,
	EATING,
	SLEEPING,
	WORKING,
	RELAXING,
	SHOWERING,
	SOCIALIZING,
	GOING_HOME,
}

## What sits on a cell edge. Doors are walkable, walls and windows are not.
enum EdgeType {
	NONE,
	WALL,
	DOOR,
	WINDOW,
}

## Edge orientation. A horizontal edge is the northern border of its cell,
## a vertical edge is the western border. See WorldGrid for the canonical form.
enum EdgeAxis {
	HORIZONTAL,
	VERTICAL,
}

## Simulation detail level, assigned by SimScheduler based on camera distance
## and visibility (design doc §27).
enum SimLOD {
	FULL,     ## On screen: ticked ~10x/second, moves, animates.
	REDUCED,  ## Nearby but off screen: ticked ~1x/second, teleports between goals.
	ABSTRACT, ## Far away: ticked once per game hour, needs resolved statistically.
}

## Currently active build tool. Owned by the build controller (Phase 2).
enum ToolMode {
	NONE,
	WALL,
	DOOR,
	WINDOW,
	FLOOR,
	FURNITURE,
	ASSIGN_ROOM,
	DELETE,
	SPAWN_CITIZEN,
}

## How the player is looking at the world.
enum ViewMode {
	CITY,     ## Zoomed out, roofs on.
	INTERIOR, ## Inside one building: roof hidden, outer walls transparent (§11).
}
