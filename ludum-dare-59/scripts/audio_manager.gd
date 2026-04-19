extends Node

const SFX_BANK_LABEL := "game_sfx"
const MUSIC_BANK_LABEL := "game_music"

const SFX_CPU_HIT := "cpu_hit"
const SFX_CPU_DEATH := "cpu_death"
const SFX_GATE_PLACE := "gate_place"
const SFX_BRUTE_LASER := "brute_laser"

const MUSIC_MAIN := "main_theme"


func _ready() -> void:
	_setup_sfx_bank()
	_setup_music_bank()


func play_sfx(event_name: String) -> void:
	SoundManager.play(SFX_BANK_LABEL, event_name)


func play_music() -> void:
	_start_music()


func stop_music(fade_time: float = 1.0) -> void:
	MusicManager.stop(fade_time)


func _setup_sfx_bank() -> void:
	var bank := SoundBank.new()
	bank.name = "GameSFXBank"
	bank.label = SFX_BANK_LABEL
	bank.bus = "SFX"
	bank.events = [
		_make_event(SFX_CPU_HIT, [
			preload("res://assets/audio/sfx/zaps/Audio0.wav"),
			preload("res://assets/audio/sfx/zaps/Audio 1.wav"),
			preload("res://assets/audio/sfx/zaps/Audio 2.wav"),
			preload("res://assets/audio/sfx/zaps/Audio 3.wav"),
			preload("res://assets/audio/sfx/zaps/Audio 4.wav"),
			preload("res://assets/audio/sfx/zaps/Audio 5.wav"),
			preload("res://assets/audio/sfx/zaps/Audio 6.wav"),
		], -30.0),
		_make_event(SFX_CPU_DEATH, [preload("res://assets/audio/sfx/destruction_bitcrushed.wav")]),
		_make_event(SFX_GATE_PLACE, [preload("res://assets/audio/sfx/put_down_gate.wav")]),
		_make_event(SFX_BRUTE_LASER, [preload("res://assets/audio/sfx/lasergun_shot.wav")]),
	]
	add_child(bank)


func _setup_music_bank() -> void:
	var stem := MusicStemResource.new()
	stem.name = "main"
	stem.enabled = true
	stem.volume = -20.0
	stem.stream = preload("res://assets/audio/music/slow-moonlight-synthwave.wav")

	var track := MusicTrackResource.new()
	track.name = MUSIC_MAIN
	track.stems = [stem]

	var bank := MusicBank.new()
	bank.name = "GameMusicBank"
	bank.label = MUSIC_BANK_LABEL
	bank.bus = "Music"
	bank.tracks = [track]
	add_child(bank)


func _make_event(event_name: String, streams: Array, volume_db: float = 0.0) -> SoundEventResource:
	var event := SoundEventResource.new()
	event.name = event_name
	event.volume = volume_db
	for s in streams:
		event.streams.append(s)
	return event


func _start_music() -> void:
	if not MusicManager.has_loaded:
		await MusicManager.loaded
	MusicManager.play(MUSIC_BANK_LABEL, MUSIC_MAIN, 0.0, true)
