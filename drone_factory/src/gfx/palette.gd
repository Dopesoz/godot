class_name Palette
extends RefCounted

## Единая палитра проекта. Ограниченный набор цветов — обязательное условие
## цельного пиксель-арта: любой новый спрайт берёт цвет только отсюда.

## --- Земля -----------------------------------------------------------------

const GRASS_DARK := Color8(46, 84, 54)
const GRASS := Color8(62, 106, 63)
const GRASS_LIGHT := Color8(84, 130, 74)

const DIRT_DARK := Color8(84, 62, 44)
const DIRT := Color8(108, 82, 56)
const DIRT_LIGHT := Color8(132, 104, 72)

const SAND_DARK := Color8(150, 128, 82)
const SAND := Color8(178, 156, 102)
const SAND_LIGHT := Color8(200, 180, 126)

const ROCK_DARK := Color8(52, 56, 68)
const ROCK := Color8(76, 82, 96)
const ROCK_LIGHT := Color8(104, 112, 128)

const WATER_DARK := Color8(28, 54, 88)
const WATER := Color8(38, 74, 118)
const WATER_LIGHT := Color8(58, 100, 148)

## --- Руды ------------------------------------------------------------------

const STONE_ORE := Color8(158, 158, 158)
const STONE_ORE_LIGHT := Color8(196, 196, 196)

const IRON_ORE := Color8(126, 142, 166)
const IRON_ORE_LIGHT := Color8(170, 188, 210)

const COPPER_ORE := Color8(176, 104, 56)
const COPPER_ORE_LIGHT := Color8(214, 142, 80)

## --- Конструкции -----------------------------------------------------------

const METAL_DARK := Color8(58, 66, 84)
const METAL := Color8(92, 102, 124)
const METAL_LIGHT := Color8(134, 146, 170)
const METAL_HILIGHT := Color8(186, 196, 214)

const ACCENT := Color8(240, 166, 60)
const ACCENT_DARK := Color8(186, 116, 30)
const GLASS := Color8(143, 214, 255)
const GLASS_DARK := Color8(72, 132, 186)

const ENERGY := Color8(120, 220, 255)
const OK := Color8(108, 192, 108)
const WARN := Color8(232, 196, 76)
const BAD := Color8(214, 84, 76)

const OUTLINE := Color8(20, 24, 36)
const SHADOW := Color8(0, 0, 0, 70)
const TRANSPARENT := Color(0, 0, 0, 0)

## --- Интерфейс -------------------------------------------------------------

const UI_BG := Color8(24, 28, 40)
const UI_PANEL := Color8(36, 42, 58)
const UI_PANEL_LIGHT := Color8(52, 60, 80)
const UI_TEXT := Color8(226, 232, 244)
const UI_TEXT_DIM := Color8(150, 160, 182)


func _init() -> void:
	assert(false, "Palette — статический класс, не создавайте экземпляры.")
