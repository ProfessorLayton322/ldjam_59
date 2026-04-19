extends Node

const SFX_BANK_LABEL := "game_sfx"
const MUSIC_BANK_LABEL := "game_music"
const DEFAULT_LIBRARY := preload("res://scripts/resources/audio_library_default.tres")

const SFX_PAUSE_ACTIVATED := "pause_activated"
const SFX_PAUSE_DEACTIVATED := "pause_deactivated"
const SFX_UI_INTERACTION := "ui_interaction"
const SFX_CPU_DAMAGE := "cpu_damage"
const SFX_CPU_DEATH := "cpu_death"
const SFX_NOT_ENOUGH_TEMPERATURE := "not_enough_temperature"
const SFX_INVALID_GATE_TILE := "invalid_gate_tile"
const SFX_INVALID_GATE_MOVE := "invalid_gate_move"
const SFX_GATE_DELETED := "gate_deleted"
const SFX_LEVEL_BEGINNING := "level_beginning"
const SFX_LEVEL_VICTORY := "level_victory"

@export var library: AudioLibrary = DEFAULT_LIBRARY

var _registered_sfx_events := {}
var _sfx_polyphonic_players := {}
var _music_track_names: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if library == null:
		library = AudioLibrary.new()
	_setup_sfx_bank()
	_setup_music_bank()
	_setup_sfx_polyphony()


func get_library() -> AudioLibrary:
	return library


func play_sfx(event_name: String) -> void:
	if not _registered_sfx_events.has(event_name):
		return

	var player = _get_sfx_polyphonic_player(event_name)
	if player == null:
		return

	player.trigger()


func play_pause_activated() -> void:
	play_sfx(SFX_PAUSE_ACTIVATED)


func play_pause_deactivated() -> void:
	play_sfx(SFX_PAUSE_DEACTIVATED)


func play_ui_interaction() -> void:
	play_sfx(SFX_UI_INTERACTION)


func play_gate_spawn(gate_id: String) -> void:
	play_sfx(_gate_event_name(gate_id, "spawn"))


func play_gate_activation(gate_id: String) -> void:
	play_sfx(_gate_event_name(gate_id, "activation"))


func play_enemy_spawn(enemy_id: String) -> void:
	play_sfx(_enemy_event_name(enemy_id, "spawn"))


func play_enemy_damage(enemy_id: String) -> void:
	play_sfx(_enemy_event_name(enemy_id, "damage"))


func play_enemy_death(enemy_id: String) -> void:
	play_sfx(_enemy_event_name(enemy_id, "death"))


func play_cpu_damage() -> void:
	play_sfx(SFX_CPU_DAMAGE)


func play_cpu_death() -> void:
	play_sfx(SFX_CPU_DEATH)


func play_not_enough_temperature() -> void:
	play_sfx(SFX_NOT_ENOUGH_TEMPERATURE)


func play_invalid_gate_tile() -> void:
	play_sfx(SFX_INVALID_GATE_TILE)


func play_invalid_gate_move() -> void:
	play_sfx(SFX_INVALID_GATE_MOVE)


func play_gate_deleted() -> void:
	play_sfx(SFX_GATE_DELETED)


func play_level_beginning() -> void:
	play_sfx(SFX_LEVEL_BEGINNING)


func play_level_victory() -> void:
	play_sfx(SFX_LEVEL_VICTORY)


func play_music() -> void:
	_start_music()


func stop_music(fade_time: float = 1.0) -> void:
	if MusicManager.is_playing(MUSIC_BANK_LABEL):
		MusicManager.stop(fade_time)


func stop_sfx() -> void:
	for event_name in _sfx_polyphonic_players.keys():
		var player = _sfx_polyphonic_players[event_name]
		if player != null and is_instance_valid(player) and not player.is_null():
			player.release(false)
	_sfx_polyphonic_players.clear()


func stop_level_audio() -> void:
	stop_sfx()
	stop_music(0.0)


func _setup_sfx_bank() -> void:
	_registered_sfx_events.clear()
	_sfx_polyphonic_players.clear()
	var bank := SoundBank.new()
	bank.name = "GameSFXBank"
	bank.label = SFX_BANK_LABEL
	bank.bus = "SFX"

	_register_sfx_event(bank, SFX_PAUSE_ACTIVATED, library.pause_activated_sounds)
	_register_sfx_event(bank, SFX_PAUSE_DEACTIVATED, library.pause_deactivated_sounds)
	_register_sfx_event(bank, SFX_UI_INTERACTION, library.ui_interaction_sounds)
	_register_sfx_event(bank, SFX_CPU_DAMAGE, library.cpu_damage_sounds, -30.0)
	_register_sfx_event(bank, SFX_CPU_DEATH, library.cpu_death_sounds)
	_register_sfx_event(bank, SFX_NOT_ENOUGH_TEMPERATURE, library.not_enough_temperature_sounds)
	_register_sfx_event(bank, SFX_INVALID_GATE_TILE, library.invalid_gate_tile_sounds)
	_register_sfx_event(bank, SFX_INVALID_GATE_MOVE, library.invalid_gate_move_sounds)
	_register_sfx_event(bank, SFX_GATE_DELETED, library.gate_deleted_sounds)
	_register_sfx_event(bank, SFX_LEVEL_BEGINNING, library.level_beginning_sounds)
	_register_sfx_event(bank, SFX_LEVEL_VICTORY, library.level_victory_sounds)

	for definition: GateDefinition in BalanceManager.get_gate_definitions():
		_register_sfx_event(bank, _gate_event_name(definition.id, "spawn"), library.get_gate_spawn_sounds(definition.id))
		_register_sfx_event(bank, _gate_event_name(definition.id, "activation"), library.get_gate_activation_sounds(definition.id))

	for params: EnemyParams in BalanceManager.get_params().enemy_params:
		_register_sfx_event(bank, _enemy_event_name(params.id, "spawn"), library.get_enemy_spawn_sounds(params.id))
		_register_sfx_event(bank, _enemy_event_name(params.id, "damage"), library.get_enemy_damage_sounds(params.id))
		_register_sfx_event(bank, _enemy_event_name(params.id, "death"), library.get_enemy_death_sounds(params.id))

	add_child(bank)


func _setup_sfx_polyphony() -> void:
	if not SoundManager.has_loaded:
		await SoundManager.loaded

	for event_name in _registered_sfx_events:
		_get_sfx_polyphonic_player(event_name)


func _setup_music_bank() -> void:
	_music_track_names.clear()
	var bank := MusicBank.new()
	bank.name = "GameMusicBank"
	bank.label = MUSIC_BANK_LABEL
	bank.bus = "Music"

	for i in library.background_music.size():
		var stream := library.background_music[i]
		if stream == null:
			continue

		var stem := MusicStemResource.new()
		stem.name = "main"
		stem.enabled = true
		stem.volume = -20.0
		stem.stream = stream

		var track_name := "background_music_%d" % i
		var track := MusicTrackResource.new()
		track.name = track_name
		track.stems = [stem]
		bank.tracks.append(track)
		_music_track_names.append(track_name)

	add_child(bank)


func _register_sfx_event(bank: SoundBank, event_name: String, streams: Array[AudioStream], volume_db: float = 0.0) -> void:
	if streams.is_empty():
		return

	var event := SoundEventResource.new()
	event.name = event_name
	event.volume = volume_db
	for stream in streams:
		if stream != null:
			event.streams.append(stream)

	if event.streams.is_empty():
		return

	bank.events.append(event)
	_registered_sfx_events[event_name] = true


func _get_sfx_polyphonic_player(event_name: String) -> Variant:
	if _sfx_polyphonic_players.has(event_name):
		var existing_player = _sfx_polyphonic_players[event_name]
		if existing_player != null and is_instance_valid(existing_player) and not existing_player.is_null():
			return existing_player
		_sfx_polyphonic_players.erase(event_name)

	if not SoundManager.has_loaded:
		return null

	var player = SoundManager.instance_poly(SFX_BANK_LABEL, event_name)
	if player == null or player.is_null():
		return null

	SoundManager.release_on_exit(self, player, true)
	_sfx_polyphonic_players[event_name] = player
	return player


func _gate_event_name(gate_id: String, action: String) -> String:
	return "gate_%s_%s" % [gate_id, action]


func _enemy_event_name(enemy_id: String, action: String) -> String:
	return "enemy_%s_%s" % [enemy_id, action]


func _start_music() -> void:
	if _music_track_names.is_empty():
		return
	if not MusicManager.has_loaded:
		await MusicManager.loaded
	var track_name := _music_track_names[_rng.randi_range(0, _music_track_names.size() - 1)]
	MusicManager.play(MUSIC_BANK_LABEL, track_name, 0.0, true)
