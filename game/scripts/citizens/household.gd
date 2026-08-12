class_name Household
extends RefCounted

## A family (design doc §22): the people, the home they share, and the money
## they make between them.
##
## Households exist so that "who lives here" is a fact about a group rather than
## a property repeated on every resident, and so the game has something to say
## when you look at a house: not "three citizens" but "the Meyers — two adults
## and a child, savings $840, nobody home until six".

var id: int = -1
var family_name: String = "Household"
var home_building_id: int = -1
## Citizen ids, in the order they moved in.
var member_ids: Array[int] = []

## Shared money the family has put aside. Wages go to the player's balance (the
## city budget); this tracks what the household itself has earned and spent, so
## a family can be visibly better or worse off than its neighbours.
var savings: int = 0


func size() -> int:
	return member_ids.size()


func has_member(citizen_id: int) -> bool:
	return member_ids.has(citizen_id)


func add_member(citizen_id: int) -> void:
	if not member_ids.has(citizen_id):
		member_ids.append(citizen_id)


func remove_member(citizen_id: int) -> void:
	member_ids.erase(citizen_id)


## "The Meyers" reads better than "Household 3" everywhere it appears.
func label() -> String:
	return Loc.t("The %ss") % family_name if not family_name.ends_with("s") else Loc.t("The %s") % family_name


func save_data() -> Dictionary:
	return {
		"id": id,
		"family_name": family_name,
		"home": home_building_id,
		"members": member_ids.duplicate(),
		"savings": savings,
	}


static func from_save(entry: Dictionary) -> Household:
	var household := Household.new()
	household.id = int(entry.get("id", -1))
	household.family_name = String(entry.get("family_name", "Household"))
	household.home_building_id = int(entry.get("home", -1))
	household.savings = int(entry.get("savings", 0))
	for value in (entry.get("members", []) as Array):
		household.member_ids.append(int(value))
	return household
