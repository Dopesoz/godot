class_name Loc
extends RefCounted

## Translation for the parts of the game that are not nodes.
##
## `tr()` is a method on Object, so the model layer — citizens, rooms,
## buildings, the decision maker — cannot call it: those are RefCounted by
## design, because the simulation must run without a scene tree (that is what
## makes the headless self-test possible). They still produce text a player
## reads, so they translate through the server directly.
##
## Same keys as `tr()`: the English string is the key, and an unknown string
## comes back unchanged.
static func t(text: String) -> String:
	return String(TranslationServer.translate(text))
