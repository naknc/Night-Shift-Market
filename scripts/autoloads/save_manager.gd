extends Node

signal settings_changed(section: StringName, key: StringName, value: Variant)
signal settings_loaded(settings: Dictionary)
signal save_data_loaded(save_data: Dictionary)
signal save_data_written(save_data: Dictionary)

const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1

const DEFAULT_SETTINGS: Dictionary = {
	"audio": {
		"master_db": -2.0,
		"music_db": -6.0,
		"sfx_db": -3.0
	},
	"input": {
		"look_sensitivity": 0.18,
		"invert_y": false
	},
	"ui": {
		"show_fps": false
	}
}

const DEFAULT_SAVE_DATA: Dictionary = {
	"meta": {
		"version": SAVE_VERSION,
		"last_saved_unix": 0
	},
	"progress": {
		"current_day": 1,
		"time_of_day": 18.0,
		"money": 0,
		"has_started": false
	},
	"store": {
		"xp": 0,
		"level": 1,
		"reputation": 50.0
	},
	"world": {
		"scene_id": "market_preview"
	},
	"player": {
		"position": [0.0, 0.0, 5.2],
		"yaw": PI,
		"pitch": 0.0
	},
	"inventories": {
		"player": []
	},
	"shelves": [],
	"delivery": {
		"state": "arriving",
		"truck_position": [24.0, 0.0, -8.0],
		"boxes": []
	},
	"morning_shift": {
		"phase": "truck_arrival"
	}
}

var _initialized: bool = false
var _settings: Dictionary = {}
var _save_data: Dictionary = {}


func initialize() -> void:
	if _initialized:
		return

	_settings = _load_settings_from_disk()
	_save_data = _load_save_data_from_disk()
	_initialized = true
	settings_loaded.emit(get_settings_copy())
	save_data_loaded.emit(get_save_data())


func reset_settings_to_default() -> void:
	_settings = _duplicate_dictionary(DEFAULT_SETTINGS)
	save_settings()
	settings_loaded.emit(get_settings_copy())


func save_settings() -> void:
	var config := ConfigFile.new()

	for section_variant in _settings.keys():
		var section_name := str(section_variant)
		var section_data := _settings.get(section_name, {}) as Dictionary

		for key_variant in section_data.keys():
			var key_name := str(key_variant)
			config.set_value(section_name, key_name, section_data[key_name])

	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("SaveManager failed to save settings: %s" % error)


func get_setting(section: StringName, key: StringName, default_value: Variant = null) -> Variant:
	var section_name := String(section)
	if not _settings.has(section_name):
		return default_value

	var section_data := _settings[section_name] as Dictionary
	return section_data.get(String(key), default_value)


func set_setting(section: StringName, key: StringName, value: Variant) -> void:
	var section_name := String(section)
	var key_name := String(key)

	if not _settings.has(section_name):
		_settings[section_name] = {}

	var section_data := _settings[section_name] as Dictionary
	section_data[key_name] = value
	_settings[section_name] = section_data
	save_settings()
	settings_changed.emit(section, key, value)


func get_settings_copy() -> Dictionary:
	return _duplicate_dictionary(_settings)


func has_save_data() -> bool:
	var progress := _save_data.get("progress", {}) as Dictionary
	return bool(progress.get("has_started", false))


func create_new_game_save() -> Dictionary:
	_save_data = _duplicate_dictionary(DEFAULT_SAVE_DATA)
	var progress := _save_data["progress"] as Dictionary
	progress["has_started"] = true
	_save_data["progress"] = progress
	_stamp_save_time(_save_data)
	write_game_data(_save_data)
	return get_save_data()


func load_game_data() -> Dictionary:
	if not has_save_data():
		return create_new_game_save()
	return get_save_data()


func write_game_data(data: Dictionary) -> void:
	_save_data = _duplicate_dictionary(data)
	_stamp_save_time(_save_data)

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager failed to open save file for writing.")
		return

	file.store_string(JSON.stringify(_save_data, "\t"))
	file.close()
	save_data_written.emit(get_save_data())


func get_save_data() -> Dictionary:
	return _duplicate_dictionary(_save_data)


func _load_settings_from_disk() -> Dictionary:
	var merged_settings := _duplicate_dictionary(DEFAULT_SETTINGS)
	var config := ConfigFile.new()
	var load_result := config.load(SETTINGS_PATH)

	if load_result != OK:
		var default_settings := _duplicate_dictionary(DEFAULT_SETTINGS)
		_settings = default_settings
		save_settings()
		return default_settings

	for section in config.get_sections():
		if not merged_settings.has(section):
			merged_settings[section] = {}

		var section_data := merged_settings[section] as Dictionary
		for key in config.get_section_keys(section):
			section_data[key] = config.get_value(section, key)
		merged_settings[section] = section_data

	return merged_settings


func _load_save_data_from_disk() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _duplicate_dictionary(DEFAULT_SAVE_DATA)

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager failed to open save file for reading.")
		return _duplicate_dictionary(DEFAULT_SAVE_DATA)

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager found malformed save data. Recreating save structure.")
		return _duplicate_dictionary(DEFAULT_SAVE_DATA)

	return _merge_defaults(_duplicate_dictionary(DEFAULT_SAVE_DATA), parsed as Dictionary)


func _stamp_save_time(data: Dictionary) -> void:
	var meta := data.get("meta", {}) as Dictionary
	meta["version"] = SAVE_VERSION
	meta["last_saved_unix"] = Time.get_unix_time_from_system()
	data["meta"] = meta


func _merge_defaults(base: Dictionary, incoming: Dictionary) -> Dictionary:
	var result := _duplicate_dictionary(base)

	for key in incoming.keys():
		var incoming_value: Variant = incoming[key]

		if result.has(key) and result[key] is Dictionary and incoming_value is Dictionary:
			result[key] = _merge_defaults(result[key] as Dictionary, incoming_value as Dictionary)
		else:
			result[key] = incoming_value

	return result


func _duplicate_dictionary(source: Dictionary) -> Dictionary:
	return source.duplicate(true)
