extends Node

## Autoload: AudioManager
##
## Music and (later) sound effects. Kept as a service rather than a player node
## inside a scene, because the soundtrack must survive the boot -> world scene
## change without a gap, and because muting has to be answerable from anywhere.
##
## Tracks are addressed by key, not by path: gameplay code asks for
## `play_music(&"main")` and never learns which file that is.

const MUSIC := {
	&"main": "res://assets/audio/music/morning_blocks.mp3",
}

## Linear volume, 0..1. Music sits under everything else by design.
## Defaults live in Settings now, because the player owns them. These remain as
## the volume the fade aims for when nothing has been chosen yet.
const MUSIC_VOLUME := 0.55
const SFX_VOLUME := 0.5
## Voices for overlapping effects. Six is enough for a busy city and cheap
## enough that they can all exist from startup rather than being spawned.
const SFX_VOICES := 6
const FADE_SECONDS := 2.0

var muted: bool = false
var current_track: StringName = &""

var _player: AudioStreamPlayer
var _tween: Tween
var _sfx_bank: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = &"Master"
	_player.volume_db = linear_to_db(0.0)
	add_child(_player)

	_sfx_bank = Sfx.bank()
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = linear_to_db(Settings.sfx_volume)
		add_child(voice)
		_sfx_players.append(voice)
	_connect_sounds()
	Settings.changed.connect(apply_volumes)
	apply_volumes()


## Music that is still playing when the tree shuts down leaves its stream and
## playback alive past cleanup, which Godot reports as a leak on exit. Releasing
## them here keeps shutdown clean.
func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _player != null:
		_player.stop()
		_player.stream = null


## Plays one of the generated effects. Voices are used round-robin, so a burst
## of events layers instead of cutting itself off.
func play_sfx(key: StringName, pitch: float = 1.0) -> void:
	if muted or _sfx_players.is_empty() or DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = _sfx_bank.get(key)
	if stream == null:
		return
	var voice := _sfx_players[_sfx_next % _sfx_players.size()]
	_sfx_next += 1
	voice.stream = stream
	voice.pitch_scale = clampf(pitch, 0.5, 2.0)
	voice.play()


## The game speaks for itself: rather than every system remembering to make a
## noise, the sounds hang off the events those systems already emit.
func _connect_sounds() -> void:
	EventBus.furniture_placed.connect(func(_f: Variant) -> void: play_sfx(&"build"))
	EventBus.building_placed.connect(func(_b: Variant) -> void: play_sfx(&"build", 0.8))
	EventBus.furniture_removed.connect(func(_id: int) -> void: play_sfx(&"build", 1.3))
	EventBus.build_rejected.connect(func(_reason: String) -> void: play_sfx(&"reject"))
	EventBus.tool_mode_changed.connect(func(_mode: int) -> void: play_sfx(&"click"))
	EventBus.city_event_started.connect(func(_id: StringName, _name: String) -> void: play_sfx(&"chime", 0.85))
	EventBus.citizen_interaction_started.connect(
			func(_c: int, _f: int, _a: String) -> void: play_sfx(&"use", randf_range(0.9, 1.15)))
	# Only worthwhile amounts are worth a sound; wages arrive a coin at a time.
	EventBus.money_changed.connect(func(_amount: int, delta: int) -> void:
		if absi(delta) >= 100:
			play_sfx(&"cash" if delta > 0 else &"reject", 1.0 if delta > 0 else 0.8))


func play_music(key: StringName, fade: bool = true) -> void:
	# A headless run (CI, --selftest) has no audio device. Starting playback
	# there only produces a stream that is still mixing when the engine shuts
	# down, which is reported as a leak on exit.
	if DisplayServer.get_name() == "headless":
		return
	if current_track == key and _player.playing:
		return
	var path: String = MUSIC.get(key, "")
	if path == "":
		push_warning("AudioManager: unknown music key '%s'" % key)
		return
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("AudioManager: could not load %s" % path)
		return
	# Looping is a property of the stream, not the player, for MP3 and OGG.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	current_track = key
	_player.stream = stream
	_player.volume_db = linear_to_db(0.001 if fade else _target_volume())
	_player.play()
	if fade:
		_fade_to(_target_volume(), FADE_SECONDS)


func stop_music(fade: bool = true) -> void:
	current_track = &""
	if not fade:
		_player.stop()
		return
	_fade_to(0.0, 1.0)
	await get_tree().create_timer(1.0).timeout
	_player.stop()


func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	Settings.set_muted(value)
	apply_volumes()
	EventBus.notify("Sound %s" % ("off" if muted else "on"))


func toggle_mute() -> void:
	set_muted(not muted)


## Pushes whatever the player chose in the settings into the mixer. Called on
## start and whenever a slider moves, so there is one path from preference to
## sound and no volume stored in two places.
func apply_volumes() -> void:
	muted = Settings.muted
	for voice in _sfx_players:
		voice.volume_db = linear_to_db(maxf(0.0 if muted else Settings.sfx_volume, 0.0001))
	_fade_to(_target_volume(), 0.25)


func is_playing() -> bool:
	return _player != null and _player.playing


func _target_volume() -> float:
	return 0.0 if muted else Settings.music_volume


## Fades in decibels via a tween, because a linear ramp on the raw dB value is
## what sounds smooth — jumping volume_db directly clicks.
func _fade_to(linear: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", linear_to_db(maxf(linear, 0.0001)), seconds)
