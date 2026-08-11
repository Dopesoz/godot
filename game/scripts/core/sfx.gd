class_name Sfx
extends RefCounted

## Procedurally generated placeholder sound effects.
##
## The project has no sound files and, per §28, should not wait for them. These
## are synthesised at startup from a handful of envelopes and frequencies — a
## few kilobytes of maths instead of a few megabytes of assets — and they give
## the game the one thing silence cannot: confirmation that something happened.
##
## Replacing them later means dropping .ogg files in and changing `bank()`. The
## call sites ask for `&"build"`, never for a file.

const SAMPLE_RATE := 22050

enum Wave { SINE, SQUARE, NOISE }


## key -> AudioStreamWAV, built once and shared.
static func bank() -> Dictionary:
	return {
		# Short, dry, low: something was placed in the world.
		&"build": _tone([440.0, 330.0], 0.12, Wave.SQUARE, 0.22, 0.02),
		# A tick with no pitch drop: a tool or a button.
		&"click": _tone([880.0], 0.05, Wave.SQUARE, 0.14, 0.005),
		# Falling minor second: the universal "no".
		&"reject": _tone([300.0, 220.0], 0.18, Wave.SQUARE, 0.20, 0.01),
		# Two rising notes: money in.
		&"cash": _tone([784.0, 1046.0], 0.16, Wave.SINE, 0.24, 0.01),
		# Rising triad: a level, a friendship, something earned.
		&"chime": _tone([523.0, 659.0, 784.0], 0.34, Wave.SINE, 0.22, 0.02),
		# Soft noise burst: a door, a footstep, an object being used.
		&"use": _tone([0.0], 0.09, Wave.NOISE, 0.10, 0.005),
	}


## Builds one sound: a sequence of frequencies played in equal slices with a
## short attack and an exponential decay, which is enough shape to stop a tone
## sounding like a test signal.
static func _tone(frequencies: Array, seconds: float, wave: Wave, volume: float, attack: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var slice := maxi(frames / maxi(frequencies.size(), 1), 1)
	var phase := 0.0

	for i in frames:
		var frequency: float = float(frequencies[mini(i / slice, frequencies.size() - 1)])
		phase += TAU * frequency / float(SAMPLE_RATE)
		var sample := 0.0
		match wave:
			Wave.SINE:
				sample = sin(phase)
			Wave.SQUARE:
				sample = 1.0 if sin(phase) >= 0.0 else -1.0
			Wave.NOISE:
				sample = randf_range(-1.0, 1.0)

		# Attack keeps the start from clicking; the decay keeps it from ringing.
		var t := float(i) / float(frames)
		var attack_gain: float = minf(float(i) / maxf(attack * float(SAMPLE_RATE), 1.0), 1.0)
		var envelope := attack_gain * pow(1.0 - t, 2.2)
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
