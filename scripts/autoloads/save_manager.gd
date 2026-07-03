extends Node

signal settings_changed(section: StringName, key: StringName, value: Variant)
signal settings_loaded(settings: Dictionary)
signal save_data_loaded(save_data: Dictionary)
signal save_data_written(save_data: Dictionary)

const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_PATH: String = "user://savegame.json"
const SAVE_BACKUP_PATH: String = "user://savegame.backup.json"
const SAVE_TEMP_PATH: String = "user://savegame.tmp.json"
const SAVE_VERSION: int = 1
const DEFAULT_PLAYER_POSITION: Array[float] = [1.0, 0.0, 8.0]
const DEFAULT_PLAYER_YAW: float = PI * 0.25
const DEFAULT_PLAYER_PITCH: float = deg_to_rad(-56.0)
const DEFAULT_PLAYER_ZOOM_DISTANCE: float = 17.0

const DEFAULT_SETTINGS: Dictionary = {
	"general": {
		"language": "system"
	},
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
		"position": DEFAULT_PLAYER_POSITION,
		"yaw": DEFAULT_PLAYER_YAW,
		"pitch": DEFAULT_PLAYER_PITCH,
		"zoom_distance": DEFAULT_PLAYER_ZOOM_DISTANCE
	},
	"inventories": {
		"player": []
	},
	"shelves": [],
	"delivery": {
		"state": "arriving",
		"truck_position": [1.0, 0.0, 25.0],
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


func write_game_data(data: Dictionary, preserve_existing_backup: bool = false) -> void:
	var prepared_save := _prepare_save_for_write(data)
	var serialized_save := JSON.stringify(prepared_save, "\t")

	if not _write_text_file(SAVE_TEMP_PATH, serialized_save):
		push_error("SaveManager failed to write temporary save data.")
		return

	var existing_save_global := ProjectSettings.globalize_path(SAVE_PATH)
	var backup_save_global := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	var temp_save_global := ProjectSettings.globalize_path(SAVE_TEMP_PATH)

	if preserve_existing_backup:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(existing_save_global)
	else:
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.remove_absolute(backup_save_global)
		if FileAccess.file_exists(SAVE_PATH):
			var backup_result := DirAccess.rename_absolute(existing_save_global, backup_save_global)
			if backup_result != OK:
				push_error("SaveManager failed to rotate previous save into backup: %s" % backup_result)
				DirAccess.remove_absolute(temp_save_global)
				return

	var promote_result := DirAccess.rename_absolute(temp_save_global, existing_save_global)
	if promote_result != OK:
		push_error("SaveManager failed to promote temporary save into the primary slot: %s" % promote_result)
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.rename_absolute(backup_save_global, existing_save_global)
		DirAccess.remove_absolute(temp_save_global)
		return

	_save_data = prepared_save
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
	if not FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(SAVE_BACKUP_PATH):
		return _duplicate_dictionary(DEFAULT_SAVE_DATA)

	var primary_save := _read_save_file(SAVE_PATH)
	if not primary_save.is_empty():
		return primary_save

	var backup_save := _read_save_file(SAVE_BACKUP_PATH)
	if not backup_save.is_empty():
		push_warning("SaveManager restored save data from backup after the primary file failed validation.")
		_save_data = backup_save
		write_game_data(backup_save, true)
		return backup_save

	push_warning("SaveManager could not recover the save data. Recreating the default save structure.")
	return _duplicate_dictionary(DEFAULT_SAVE_DATA)


func _stamp_save_time(data: Dictionary) -> void:
	var meta := data.get("meta", {}) as Dictionary
	meta["version"] = SAVE_VERSION
	meta["last_saved_unix"] = Time.get_unix_time_from_system()
	data["meta"] = meta


func _prepare_save_for_write(data: Dictionary) -> Dictionary:
	var prepared_save := _merge_defaults(_duplicate_dictionary(DEFAULT_SAVE_DATA), _duplicate_dictionary(data))
	_stamp_save_time(prepared_save)
	return prepared_save


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveManager failed to open save file for reading: %s" % path)
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager found malformed JSON in %s." % path)
		return {}

	var migrated_save := _migrate_save_data(parsed as Dictionary)
	if migrated_save.is_empty():
		return {}
	if not _is_save_structure_valid(migrated_save):
		push_warning("SaveManager rejected %s because its structure is invalid." % path)
		return {}

	return _merge_defaults(_duplicate_dictionary(DEFAULT_SAVE_DATA), migrated_save)


func _migrate_save_data(data: Dictionary) -> Dictionary:
	var migrated_save := _duplicate_dictionary(data)
	var meta := migrated_save.get("meta", {}) as Dictionary
	var version := int(meta.get("version", 1))

	if version > SAVE_VERSION:
		push_warning("SaveManager found a newer save version (%d) than the runtime supports (%d)." % [version, SAVE_VERSION])
		return {}

	while version < SAVE_VERSION:
		match version:
			_:
				version = SAVE_VERSION

	meta["version"] = SAVE_VERSION
	migrated_save["meta"] = meta
	return migrated_save


func _is_save_structure_valid(data: Dictionary) -> bool:
	return (
		data.get("meta", null) is Dictionary
		and data.get("progress", null) is Dictionary
		and data.get("store", null) is Dictionary
		and data.get("world", null) is Dictionary
		and data.get("player", null) is Dictionary
		and data.get("inventories", null) is Dictionary
		and data.get("shelves", null) is Array
		and data.get("delivery", null) is Dictionary
		and data.get("morning_shift", null) is Dictionary
	)


func _write_text_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true


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
