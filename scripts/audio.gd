class_name AudioManager
extends Node
## The sounds of the original game: a music track, the click of a wooden track
## piece being placed and the rumble of the locomotive.

const FILES := {
	"place": ["res://assets/audio/placeblock_0.wav", "res://assets/audio/placeblock_1.wav"],
	"place_disabled": ["res://assets/audio/placeblock-disabled.mp3"],
	"hover": ["res://assets/audio/hover_0.wav", "res://assets/audio/hover_1.wav"],
	"delete": ["res://assets/audio/delete-all.mp3"],
	"build_mode": ["res://assets/audio/build-mode.mp3"],
	"camera_mode": ["res://assets/audio/camera-mode.mp3"],
	"camera_spin": ["res://assets/audio/camera-spin_0.mp3", "res://assets/audio/camera-spin_1.mp3",
		"res://assets/audio/camera-spin_2.mp3"],
	"snapshot": ["res://assets/audio/snapshot.mp3"],
	"train_start": ["res://assets/audio/train-start.mp3"],
	"train_reset": ["res://assets/audio/train-reset.mp3"],
	"completed": ["res://assets/audio/completed.mp3"],
	"cricket": ["res://assets/audio/cricket.mp3"],
}

var music_enabled := true
var sfx_enabled := true

var _music: AudioStreamPlayer
var _train: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_music = AudioStreamPlayer.new()
	_music.volume_db = -12.0
	var bgm: AudioStream = _load_stream("res://assets/audio/bgm.mp3")
	if bgm is AudioStreamMP3:
		bgm.loop = true
	_music.stream = bgm
	add_child(_music)

	_train = AudioStreamPlayer.new()
	_train.volume_db = -10.0
	var moving: AudioStream = _load_stream("res://assets/audio/train-moving.mp3")
	if moving is AudioStreamMP3:
		moving.loop = true
	_train.stream = moving
	add_child(_train)

	for i in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)


static func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func play_music() -> void:
	if music_enabled and _music.stream:
		_music.play()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not enabled:
		_music.stop()
	elif _music.stream:
		_music.play()


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx_enabled:
		return
	var paths: Array = FILES.get(name, [])
	if paths.is_empty():
		return
	var stream := _load_stream(paths[_rng.randi_range(0, paths.size() - 1)])
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## The locomotive rumble, tied to how fast the train is going.
func set_train_running(running: bool, speed: float) -> void:
	if not _train.stream:
		return
	if running and speed > 0.001:
		if not _train.playing:
			_train.play()
		_train.pitch_scale = clampf(0.5 + speed * 2.5, 0.5, 3.0)
		_train.volume_db = -18.0 + clampf(speed * 6.0, 0.0, 12.0)
	elif _train.playing:
		_train.stop()
