class_name GameConstants
extends RefCounted

## Tuning values that are not content. Anything that describes a *thing* in the
## world (a bed, a job, a citizen) belongs in a Resource under res://resources/,
## not here. This file is only for engine-level and balance-level constants.


# --- Isometric geometry ---------------------------------------------------

## Width of one tile diamond in pixels. Must be even.
const TILE_W: int = 64
## Height of one tile diamond in pixels. Must be even, and TILE_W / TILE_H == 2
## for the classic 2:1 isometric look.
const TILE_H: int = 32

## Half extents, precomputed because they are used in every coordinate convert.
const TILE_HW: float = TILE_W * 0.5
const TILE_HH: float = TILE_H * 0.5

## Height in pixels of one wall segment when drawn. Also the vertical offset
## between two floors of the same building.
const WALL_HEIGHT: int = 48


# --- Map ------------------------------------------------------------------

## Playfield size in cells. Phase 1 uses a small map; the grid itself has no
## hard limit, so this can grow later without touching the code.
const MAP_SIZE: Vector2i = Vector2i(40, 40)

## Number of buildable floors. 0 is ground level.
const MAX_FLOORS: int = 1


# --- Camera ---------------------------------------------------------------

const CAMERA_ZOOM_MIN: float = 0.5
const CAMERA_ZOOM_MAX: float = 4.0
const CAMERA_ZOOM_DEFAULT: float = 1.0
const CAMERA_ZOOM_STEP: float = 1.15
## Higher is snappier. Used as `weight = 1.0 - exp(-SMOOTH * delta)`.
const CAMERA_PAN_SMOOTHING: float = 12.0
const CAMERA_KEYBOARD_SPEED: float = 700.0


# --- Time -----------------------------------------------------------------

## Design doc §17: one real second is one game minute at normal speed.
const GAME_MINUTES_PER_REAL_SECOND: float = 1.0
## Selectable speeds. Index 0 is pause.
const TIME_SPEEDS: Array[float] = [0.0, 1.0, 4.0, 16.0]
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const DAYS_PER_WEEK: int = 7
const DAY_NAMES: Array[String] = [
	"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
]

## Hour at which outdoor light starts/stops changing (used by the day/night
## shader on Phase 6).
const DAWN_HOUR: float = 6.0
const DUSK_HOUR: float = 20.0


# --- Simulation -------------------------------------------------------------

## Ticks per real second for each LOD (design doc §27).
const SIM_HZ_FULL: float = 10.0
const SIM_HZ_REDUCED: float = 1.0
## ABSTRACT agents are ticked once per game hour instead of on a real-time
## schedule, so they cost nothing while the player is elsewhere.

## Distance in cells from the camera focus at which agents drop a LOD level.
const LOD_FULL_RADIUS: float = 30.0
const LOD_REDUCED_RADIUS: float = 90.0

## Needs decay expressed in points per game hour. Positive means the need drops.
const NEED_DECAY_PER_HOUR: Dictionary = {
	GameEnums.NeedType.HUNGER: 5.0,
	GameEnums.NeedType.ENERGY: 4.0,
	GameEnums.NeedType.HYGIENE: 3.0,
	GameEnums.NeedType.COMFORT: 3.0,
	GameEnums.NeedType.ENTERTAINMENT: 4.0,
	GameEnums.NeedType.SOCIAL: 2.0,
}

## A need at or below this value makes the citizen actively look for a fix.
const NEED_URGENT_THRESHOLD: float = 30.0
const NEED_MAX: float = 100.0
const NEED_MIN: float = 0.0


# --- Economy ----------------------------------------------------------------

const STARTING_MONEY: int = 20000
## Price of one wall segment, one floor tile, etc. Buildings and furniture carry
## their own price in their Resource.
const PRICE_WALL: int = 20
const PRICE_DOOR: int = 120
const PRICE_WINDOW: int = 90
const PRICE_FLOOR: int = 10


# --- Persistence ------------------------------------------------------------

const SAVE_DIR: String = "user://saves"
const SAVE_EXTENSION: String = ".json"
## Bumped whenever the save layout changes in a non-additive way.
const SAVE_FORMAT_VERSION: int = 1
