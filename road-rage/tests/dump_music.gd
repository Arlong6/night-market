## Render every procedural sound to a .wav so a human can actually hear them, and
## so the music's level can be checked numerically instead of guessed at.
## Each file is written at the level it is PLAYED at in game (volume_db applied),
## so what you hear here is what the game mixes.
##   godot --headless --path road-rage -s res://tests/dump_music.gd -- <outdir>
extends SceneTree

## name -> [stream_factory, volume_db as used in game]
func _initialize() -> void:
	var out: String = "/tmp"
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.size() > 0:
		out = argv[0]
	DirAccess.make_dir_recursive_absolute(out)

	var items: Array = [
		["music", RRAudio.make_music_stream(), -22.0],
		["gunshot", RRAudio._make_gunshot(), -7.0],
		["explosion", RRAudio._make_explosion(), -3.0],
		["impact", RRAudio._make_impact(), -8.0],
	]
	for it in items:
		var name: String = it[0]
		var st: AudioStreamWAV = it[1]
		var db: float = it[2]
		# Raw stream as generated.
		var raw_path: String = "%s/%s_raw.wav" % [out, name]
		st.save_to_wav(raw_path)
		# Same stream scaled by the volume_db the game plays it at.
		var mixed: AudioStreamWAV = _scaled(st, db_to_linear(db))
		var mix_path: String = "%s/%s_asplayed.wav" % [out, name]
		mixed.save_to_wav(mix_path)
		print("DUMP %s samples=%d rate=%d db=%.1f raw=%s mixed=%s"
			% [name, st.data.size() / 2, st.mix_rate, db, raw_path, mix_path])
	print("DUMP DONE")
	quit()

func _scaled(src: AudioStreamWAV, gain: float) -> AudioStreamWAV:
	var out := AudioStreamWAV.new()
	out.format = src.format
	out.mix_rate = src.mix_rate
	out.stereo = src.stereo
	var d: PackedByteArray = src.data.duplicate()
	var n: int = d.size() / 2
	for i in n:
		var v: int = d[i * 2] | (d[i * 2 + 1] << 8)
		if v >= 32768: v -= 65536
		v = int(clampf(float(v) * gain, -32768.0, 32767.0))
		if v < 0: v += 65536
		d[i * 2] = v & 0xFF
		d[i * 2 + 1] = (v >> 8) & 0xFF
	out.data = d
	return out
