extends Node

signal locale_changed(locale_code: StringName, is_rtl: bool)

const MANIFEST_PATH: String = "res://data/localization/manifest.json"
const DEFAULT_LANGUAGE_PREFERENCE: StringName = &"system"
const DEFAULT_FALLBACK_LOCALE: StringName = &"en"

var _initialized: bool = false
var _fallback_locale: StringName = DEFAULT_FALLBACK_LOCALE
var _language_preference: StringName = DEFAULT_LANGUAGE_PREFERENCE
var _current_locale: StringName = DEFAULT_FALLBACK_LOCALE
var _locale_entries: Array[Dictionary] = []
var _translations_by_locale: Dictionary = {}


func initialize() -> void:
	if _initialized:
		return

	_load_manifest()
	_load_translations()
	_initialized = true
	apply_saved_locale()


func apply_saved_locale() -> void:
	var saved_preference := StringName(String(SaveManager.get_setting(&"general", &"language", String(DEFAULT_LANGUAGE_PREFERENCE))))
	_apply_language_preference(saved_preference, false)


func set_language_preference(language_code: StringName) -> void:
	var normalized_preference := _normalize_preference(language_code)
	SaveManager.set_setting(&"general", &"language", String(normalized_preference))
	_apply_language_preference(normalized_preference, true)


func get_language_preference() -> StringName:
	return _language_preference


func get_current_locale() -> StringName:
	return _current_locale


func get_system_locale() -> StringName:
	var raw_locale := String(OS.get_locale())
	return _normalize_locale_code(raw_locale)


func get_supported_locales() -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	for entry in _locale_entries:
		duplicated.append(entry.duplicate(true))
	return duplicated


func get_locale_display_name(locale_code: StringName) -> String:
	for entry in _locale_entries:
		if StringName(String(entry.get("code", ""))) == locale_code:
			return String(entry.get("native_name", entry.get("display_name", String(locale_code))))
	return String(locale_code)


func is_current_locale_rtl() -> bool:
	return is_locale_rtl(_current_locale)


func is_locale_rtl(locale_code: StringName) -> bool:
	for entry in _locale_entries:
		if StringName(String(entry.get("code", ""))) == locale_code:
			return bool(entry.get("rtl", false))
	return String(locale_code).begins_with("ar")


func text(key: StringName, params: Dictionary = {}) -> String:
	var text_value: String = _lookup_translation(_current_locale, key)
	if text_value.is_empty():
		text_value = _lookup_translation(_fallback_locale, key)
	if text_value.is_empty():
		text_value = String(key)
	return _apply_params(text_value, params)


func apply_control_locale(control: Control) -> void:
	if control == null:
		return
	_apply_layout_recursive(control, is_current_locale_rtl())


func _apply_language_preference(language_code: StringName, emit_if_unchanged: bool) -> void:
	if not _initialized:
		return

	_language_preference = _normalize_preference(language_code)
	var resolved_locale: StringName = _resolve_preference(_language_preference)
	var locale_changed_required: bool = resolved_locale != _current_locale or emit_if_unchanged
	_current_locale = resolved_locale
	TranslationServer.set_locale(String(_current_locale))

	if locale_changed_required:
		locale_changed.emit(_current_locale, is_current_locale_rtl())


func _resolve_preference(language_code: StringName) -> StringName:
	if language_code == DEFAULT_LANGUAGE_PREFERENCE:
		var system_locale := get_system_locale()
		if _has_locale(system_locale):
			return system_locale
		return _fallback_locale

	if _has_locale(language_code):
		return language_code
	return _fallback_locale


func _normalize_preference(language_code: StringName) -> StringName:
	if language_code == DEFAULT_LANGUAGE_PREFERENCE:
		return DEFAULT_LANGUAGE_PREFERENCE
	return _normalize_locale_code(String(language_code))


func _normalize_locale_code(raw_locale: String) -> StringName:
	var stripped := raw_locale.strip_edges().to_lower()
	if stripped.is_empty():
		return _fallback_locale
	var locale_without_region := stripped.split(".")[0]
	var locale_root := locale_without_region.split("@")[0]
	var parts := locale_root.split("_")
	if parts.is_empty():
		return StringName(locale_root)
	return StringName(parts[0])


func _has_locale(locale_code: StringName) -> bool:
	return _translations_by_locale.has(String(locale_code))


func _lookup_translation(locale_code: StringName, key: StringName) -> String:
	var table: Variant = _translations_by_locale.get(String(locale_code), null)
	if typeof(table) != TYPE_DICTIONARY:
		return ""
	return String((table as Dictionary).get(String(key), ""))


func _apply_params(template: String, params: Dictionary) -> String:
	var result: String = template
	for key_variant in params.keys():
		var token: String = "{%s}" % str(key_variant)
		result = result.replace(token, str(params[key_variant]))
	return result


func _apply_layout_recursive(node: Node, use_rtl: bool) -> void:
	if node is Control:
		var control := node as Control
		control.layout_direction = Control.LAYOUT_DIRECTION_RTL if use_rtl else Control.LAYOUT_DIRECTION_LTR
	for child in node.get_children():
		_apply_layout_recursive(child, use_rtl)


func _load_manifest() -> void:
	var manifest: Variant = _load_json_file(MANIFEST_PATH)
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("LocalizationManager failed to load manifest from %s." % MANIFEST_PATH)
		_locale_entries = [{
			"code": "en",
			"display_name": "English",
			"native_name": "English",
			"rtl": false,
			"path": "res://data/localization/en.json"
		}]
		_fallback_locale = DEFAULT_FALLBACK_LOCALE
		return

	_fallback_locale = _normalize_locale_code(String((manifest as Dictionary).get("fallback_locale", String(DEFAULT_FALLBACK_LOCALE))))
	_locale_entries.clear()
	var locale_list: Variant = (manifest as Dictionary).get("locales", [])
	if locale_list is Array:
		for raw_entry in locale_list:
			if typeof(raw_entry) != TYPE_DICTIONARY:
				continue
			_locale_entries.append((raw_entry as Dictionary).duplicate(true))


func _load_translations() -> void:
	_translations_by_locale.clear()

	for entry in _locale_entries:
		var locale_code := _normalize_locale_code(String(entry.get("code", "")))
		var path := String(entry.get("path", ""))
		if locale_code == StringName() or path.is_empty():
			continue

		var loaded_translation: Variant = _load_json_file(path)
		if typeof(loaded_translation) != TYPE_DICTIONARY:
			push_warning("LocalizationManager skipped invalid locale file at %s." % path)
			continue
		_translations_by_locale[String(locale_code)] = loaded_translation

	if not _translations_by_locale.has(String(_fallback_locale)):
		_fallback_locale = DEFAULT_FALLBACK_LOCALE


func _load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed
