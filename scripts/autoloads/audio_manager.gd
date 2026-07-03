extends Node

signal master_volume_changed(db: float)
signal music_volume_changed(db: float)
signal sfx_volume_changed(db: float)

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"

var _initialized: bool = false
var _music_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_players()
	_ensure_named_buses()


func initialize_from_settings() -> void:
	_ensure_audio_players()
	_ensure_named_buses()
	set_master_volume_db(float(SaveManager.get_setting(&"audio", &"master_db", -2.0)))
	set_music_volume_db(float(SaveManager.get_setting(&"audio", &"music_db", -6.0)))
	set_sfx_volume_db(float(SaveManager.get_setting(&"audio", &"sfx_db", -3.0)))
	_initialized = true


func play_music(stream: AudioStream) -> void:
	if stream == null:
		return

	_ensure_audio_players()
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()


func play_ui_sound(stream: AudioStream) -> void:
	if stream == null:
		return

	_ensure_audio_players()
	_ui_player.stream = stream
	_ui_player.play()


func set_master_volume_db(db: float) -> void:
	_set_bus_volume(BUS_MASTER, db)
	SaveManager.set_setting(&"audio", &"master_db", db)
	master_volume_changed.emit(db)


func set_music_volume_db(db: float) -> void:
	_set_bus_volume(BUS_MUSIC, db)
	SaveManager.set_setting(&"audio", &"music_db", db)
	music_volume_changed.emit(db)


func set_sfx_volume_db(db: float) -> void:
	_set_bus_volume(BUS_SFX, db)
	_set_bus_volume(BUS_UI, db)
	SaveManager.set_setting(&"audio", &"sfx_db", db)
	sfx_volume_changed.emit(db)


func get_master_volume_db() -> float:
	return float(SaveManager.get_setting(&"audio", &"master_db", -2.0))


func _ensure_audio_players() -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
		_music_player.bus = String(BUS_MUSIC)
		add_child(_music_player)

	if _ui_player == null:
		_ui_player = AudioStreamPlayer.new()
		_ui_player.name = "UiPlayer"
		_ui_player.bus = String(BUS_UI)
		add_child(_ui_player)


func _ensure_named_buses() -> void:
	_ensure_bus(BUS_MUSIC, BUS_MASTER)
	_ensure_bus(BUS_SFX, BUS_MASTER)
	_ensure_bus(BUS_UI, BUS_MASTER)


func _ensure_bus(bus_name: StringName, send_to: StringName) -> void:
	if AudioServer.get_bus_index(String(bus_name)) != -1:
		return

	var position := AudioServer.get_bus_count()
	AudioServer.add_bus(position)
	AudioServer.set_bus_name(position, String(bus_name))
	AudioServer.set_bus_send(position, String(send_to))


func _set_bus_volume(bus_name: StringName, db: float) -> void:
	var bus_index := AudioServer.get_bus_index(String(bus_name))
	if bus_index == -1:
		return

	AudioServer.set_bus_volume_db(bus_index, db)
