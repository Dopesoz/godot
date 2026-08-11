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
const MUSIC_VOLUME := 0.55
const FADE_SECONDS := 2.0

var muted: bool = false
var current_track: StringName = &""

var _player: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = &"Master"
	_player.volume_db = linear_to_db(0.0)
	add_child(_player)


## Music that is still playing when the tree shuts down leaves its stream and
## playback alive past cleanup, which Godot reports as a leak on exit. Releasing
## them here keeps shutdown clean.
func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _player != null:
		_player.stop()
		_player.stream = null


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
	_fade_to(_target_volume(), 0.4)
	EventBus.notify("Music %s" % ("muted" if muted else "on"))


func toggle_mute() -> void:
	set_muted(not muted)


func is_playing() -> bool:
	return _player != null and _player.playing


func _target_volume() -> float:
	return 0.0 if muted else MUSIC_VOLUME


## Fades in decibels via a tween, because a linear ramp on the raw dB value is
## what sounds smooth — jumping volume_db directly clicks.
func _fade_to(linear: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", linear_to_db(maxf(linear, 0.0001)), seconds)
