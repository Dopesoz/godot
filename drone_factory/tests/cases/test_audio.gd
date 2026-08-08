extends TestCase
## Звук синтезируется кодом, поэтому проверяется как и остальной код.

var world: GameWorld = null
var audio: AudioDirector = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(818)
	audio = AudioDirector.new()
	Engine.get_main_loop().root.add_child(audio)
	audio.setup(world.buildings)


func after_each() -> void:
	for node: Node in [audio, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	audio = null


func test_every_effect_is_generated_and_audible() -> void:
	for id: StringName in SoundBank.effect_ids():
		var stream: AudioStreamWAV = SoundBank.effect(id)
		check(stream != null, "нет звука %s" % id)
		check(stream.data.size() > 1000, "звук %s подозрительно короткий" % id)
		# Тишина вместо звука — самая незаметная поломка синтеза.
		var peak: int = 0
		for i: int in mini(stream.data.size() / 2, 20000):
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		check(peak > 2000, "звук %s почти беззвучный (пик %d)" % [id, peak])


func test_music_loops() -> void:
	var music: AudioStreamWAV = SoundBank.music(0)
	check(music != null)
	check_eq(music.loop_mode, AudioStreamWAV.LOOP_FORWARD, "музыка должна зацикливаться")
	var seconds: float = music.get_length()
	check(seconds > 8.0, "петля слишком короткая: %.1f с" % seconds)
	check(seconds < 60.0, "петля слишком длинная для памяти телефона: %.1f с" % seconds)


func test_samples_stay_in_range() -> void:
	# Перегрузка звучит как треск, поэтому нормализация обязана держать пик.
	var music: AudioStreamWAV = SoundBank.music(0)
	var clipped: int = 0
	for i: int in mini(music.data.size() / 2, 50000):
		if absi(music.data.decode_s16(i * 2)) >= 32760:
			clipped += 1
	check(clipped == 0, "музыка перегружена: %d сэмплов в клиппинге" % clipped)


func test_volume_maps_to_silence_at_zero() -> void:
	check(AudioDirector._to_db(0.0) <= -70.0, "нулевая громкость должна быть тишиной")
	check(AudioDirector._to_db(1.0) >= -0.1, "полная громкость не должна резаться")


func test_muted_music_stops_playing() -> void:
	audio.music_volume = 0.0
	audio.apply_volumes()
	check(not audio._music_player.playing, "при нулевой громкости музыка не играет")
	audio.music_volume = 0.5
	audio.apply_volumes()
	check(audio._music_player.playing, "музыка должна включаться обратно")


func test_repeated_effects_are_throttled() -> void:
	audio.sfx_volume = 1.0
	audio._time = 100.0
	audio.play(SoundBank.BUILD)
	var first: float = audio._last_played[SoundBank.BUILD]
	audio.play(SoundBank.BUILD)
	check_eq(audio._last_played[SoundBank.BUILD], first,
		"одинаковые эффекты подряд должны отсекаться, иначе массовая постройка трещит")
	audio._time += AudioDirector.EFFECT_COOLDOWN * 2.0
	audio.play(SoundBank.BUILD)
	check_ne(audio._last_played[SoundBank.BUILD], first, "после паузы звук снова разрешён")


func test_muted_sfx_plays_nothing() -> void:
	audio.sfx_volume = 0.0
	audio._time = 500.0
	audio.play(SoundBank.CLICK)
	check(not audio._last_played.has(SoundBank.CLICK), "при нулевой громкости эффектов нет")


func test_factory_hum_follows_working_machines() -> void:
	check_almost(audio._hum_target, 0.0, 0.001)
	for i: int in 6:
		var furnace: Building = world.buildings.place(
			BuildingDefs.FURNACE, world.start_cell + Vector2i(i * 3, 8)
		)
		if furnace != null:
			furnace.status = Building.Status.WORKING
	audio._update_hum(1.0)
	var few: float = audio._hum_target
	check(few > 0.0, "работающие машины должны давать гул")

	for i: int in 20:
		var extra: Building = world.buildings.place(
			BuildingDefs.FURNACE, world.start_cell + Vector2i((i % 10) * 3, 12 + (i / 10) * 3)
		)
		if extra != null:
			extra.status = Building.Status.WORKING
	audio._update_hum(1.0)
	# Громкость растёт логарифмически: втрое больше печей — не втрое громче.
	check(audio._hum_target > few, "больше машин — громче гул")
	check(audio._hum_target < few * 2.0, "гул не должен расти линейно с числом машин")
	check(audio._hum_target <= 0.5, "гул не должен перекрывать музыку")


func test_settings_volume_cycle() -> void:
	check_almost(GameSettings.next_volume(0.0), 0.25)
	check_almost(GameSettings.next_volume(0.75), 1.0)
	check_almost(GameSettings.next_volume(1.0), 0.0, 0.001, "после максимума круг замыкается")
	check_almost(GameSettings.next_scale(1.0), 1.25)
	check_almost(GameSettings.next_scale(1.25), 0.75)


func test_settings_persist_audio_and_scale() -> void:
	var settings := GameSettings.new()
	settings.music_volume = 0.25
	settings.sfx_volume = 0.5
	settings.ui_scale = 0.75
	settings.max_fps = 30
	settings.save_settings()

	var restored := GameSettings.new()
	restored.load_settings()
	check_almost(restored.music_volume, 0.25)
	check_almost(restored.sfx_volume, 0.5)
	check_almost(restored.ui_scale, 0.75)
	check_eq(restored.max_fps, 30)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))


func test_several_distinct_music_tracks() -> void:
	check(SoundBank.track_count() >= 4, "одной петли на всю партию мало")
	var seen: Array[String] = []
	for index: int in SoundBank.track_count():
		var track: AudioStreamWAV = SoundBank.music(index)
		check(track != null, "трек %d не собрался" % index)
		check(track.loop_mode != AudioStreamWAV.LOOP_DISABLED, "трек %d должен зацикливаться" % index)
		var length: float = track.get_length()
		check(length > 8.0, "трек %d слишком короткий: %.1f с" % [index, length])
		var signature: String = track.data.slice(0, 4096).hex_encode()
		check(not seen.has(signature), "трек %d звучит так же, как предыдущий" % index)
		seen.append(signature)


func test_track_index_wraps_around() -> void:
	check_eq(SoundBank.music(SoundBank.track_count()), SoundBank.music(0), "индекс должен закольцовываться")
	check_eq(SoundBank.music(-1), SoundBank.music(SoundBank.track_count() - 1))


func test_audio_build_fits_the_startup_budget() -> void:
	# Весь звук считается кодом при запуске. На слабом телефоне это время
	# игрок видит как чёрный экран, поэтому у него есть предел.
	SoundBank.reset()
	var start_usec: int = Time.get_ticks_usec()
	SoundBank.build()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	check(elapsed_ms < 2500.0, "сборка звука заняла %.0f мс" % elapsed_ms)
