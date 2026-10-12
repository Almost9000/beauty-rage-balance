extends Node

# SaveManager (Autoload Singleton #11)
#
# ADR-02 / ADR-03: Coordinates full JSON serialization and deserialization of the game state.
# Save pipeline: request_flush() -> collect manager dictionaries in autoload order ->
# write to user://save_01.json.tmp -> atomic rename to user://save_01.json.
# Load pipeline: read & parse JSON -> rename corrupt file to .bak -> reset_state() on everything ->
# from_dict() in autoload order -> route to saved level/spawn.

signal game_saved
signal game_loaded
signal save_corrupted

const SAVE_PATH: String = "user://save_01.json"
const TEMP_PATH: String = "user://save_01.json.tmp"
const BAK_PATH: String = "user://save_01.json.bak"
const CURRENT_SAVE_VERSION: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func save_game() -> bool:
	# 1. Flush transient level state into SceneRouter
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("request_flush"):
		router.call("request_flush")

	# 2. Collect state in autoload order
	var save_data: Dictionary = {
		"version": CURRENT_SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
		"settings": GameSettings.current().to_dict(),
		"game_clock": GameClock.to_dict(),
		"status_manager": StatusManager.to_dict(),
		"cycle_manager": CycleManager.to_dict(),
		"finance_manager": FinanceManager.to_dict(),
		"inventory_manager": InventoryManager.to_dict(),
		"outing_manager": OutingManager.to_dict(),
		"narrative_manager": NarrativeManager.to_dict(),
		"scene_router": SceneRouter.to_dict(),
		"day_director": DayDirector.to_dict(),
	}

	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("to_dict"):
		save_data["phone"] = phone.call("to_dict")

	# 3. Serialize to formatted JSON string
	var json_text: String = JSON.stringify(save_data, "\t")

	# 4. Atomic file write via temp file and rename
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open temp save file '%s' for write: %d" % [TEMP_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(json_text)
	file.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: Failed to open user:// directory")
		return false

	if dir.file_exists("save_01.json"):
		dir.remove("save_01.json")

	var err: Error = dir.rename("save_01.json.tmp", "save_01.json")
	if err != OK:
		push_error("SaveManager: Failed to rename temp save file to save_01.json: %d" % err)
		return false

	game_saved.emit()
	return true


func load_game(route_scene: bool = true) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("SaveManager: Save file '%s' does not exist." % SAVE_PATH)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file '%s' for reading." % SAVE_PATH)
		return false

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("version"):
		push_error("SaveManager: Corrupt or invalid JSON save file detected. Renaming to .bak")
		_handle_corrupt_file()
		return false

	var data: Dictionary = parsed as Dictionary
	var version: int = int(data.get("version", 1))
	var migrated_data: Dictionary = _migrate(data, version)

	# 1. Reset state on all managers in autoload order
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()
	NarrativeManager.reset_state()
	SceneRouter.reset_state()
	DayDirector.reset_state()

	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("reset_state"):
		phone.call("reset_state")

	# 2. Deserialization from dictionary in autoload order
	GameSettings.current().from_dict(migrated_data.get("settings", {}), version)
	GameClock.from_dict(migrated_data.get("game_clock", {}), version)
	StatusManager.from_dict(migrated_data.get("status_manager", {}), version)
	CycleManager.from_dict(migrated_data.get("cycle_manager", {}), version)
	FinanceManager.from_dict(migrated_data.get("finance_manager", {}), version)
	InventoryManager.from_dict(migrated_data.get("inventory_manager", {}), version)
	OutingManager.from_dict(migrated_data.get("outing_manager", {}), version)
	NarrativeManager.from_dict(migrated_data.get("narrative_manager", {}), version)
	SceneRouter.from_dict(migrated_data.get("scene_router", {}), version)
	DayDirector.from_dict(migrated_data.get("day_director", {}), version)

	if phone and phone.has_method("from_dict"):
		phone.call("from_dict", migrated_data.get("phone", {}))

	# 3. Route to saved level if requested
	if route_scene:
		var router_data: Dictionary = migrated_data.get("scene_router", {})
		var level_id: String = str(router_data.get("current_level_id", "apartment"))
		var target_path: String = "res://levels/apartment/apartment.tscn"
		if level_id == "thrift_store":
			target_path = "res://levels/thrift_store/thrift_store.tscn"
		SceneRouter.change_level(target_path, &"default")

	game_loaded.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		if dir.file_exists("save_01.json"):
			dir.remove("save_01.json")
		if dir.file_exists("save_01.json.tmp"):
			dir.remove("save_01.json.tmp")


func _handle_corrupt_file() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		if dir.file_exists("save_01.json.bak"):
			dir.remove("save_01.json.bak")
		if dir.file_exists("save_01.json"):
			dir.rename("save_01.json", "save_01.json.bak")
	save_corrupted.emit()


func _migrate(data: Dictionary, _from_version: int) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	# Migration hooks for future versions can be placed here
	return migrated


# --- Manager Contract ---

func reset_state() -> void:
	pass


func to_dict() -> Dictionary:
	return {
		"save_version": CURRENT_SAVE_VERSION,
	}


func from_dict(_data: Dictionary, _version: int = 1) -> void:
	pass
