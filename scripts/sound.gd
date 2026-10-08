extends Node

const EFFECT_NAMES := ["jump","dash","hit","hurt","seed","shrine","swing","heavy","magic","ascend","dive","impact","charge","ui","purchase"]
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice: int = 0
var music: AudioStreamPlayer
var battle_music: AudioStreamPlayer
var battle_mix: float = 0
var random := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in EFFECT_NAMES:
		sounds[name] = load("res://assets/audio/%s.wav" % name)
	for i in range(10):
		var audio := AudioStreamPlayer.new()
		audio.bus = "Effects"
		audio.volume_db = -5
		add_child(audio)
		voices.append(audio)
	music = music_voice("gardens")
	battle_music = music_voice("guardian")
	if not Settings.test_mode:
		music.play()
		battle_music.play()

func music_voice(name: String) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.bus = "Music"
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % name).duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	audio.stream = stream
	audio.volume_db = -60
	add_child(audio)
	return audio

func _process(delta: float) -> void:
	var world = get_parent()
	var battle: bool = world.boss_encounter()
	battle_mix = move_toward(battle_mix,1.0 if battle else 0.0,delta*0.8)
	var attenuation := -11.0 if get_tree().paused else -6.0
	music.volume_db = linear_to_db(maxf(0.001,1.0-battle_mix))+attenuation
	battle_music.volume_db = linear_to_db(maxf(0.001,battle_mix))+attenuation

func play(effect: String) -> void:
	if not sounds.has(effect):
		return
	voices[voice].stream = sounds[effect]
	voices[voice].pitch_scale = random.randf_range(0.96,1.04) if effect in ["swing","hit","heavy"] else 1.0
	voices[voice].play()
	voice = (voice+1)%voices.size()

func stop_all() -> void:
	for audio in voices:
		audio.stop()
		audio.stream = null
	for audio in [music,battle_music]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null

func _exit_tree() -> void:
	stop_all()
	sounds.clear()