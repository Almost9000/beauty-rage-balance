extends Node

# NarrativeManager (Autoload Singleton #8)
#
# ADR-09: Social-pressure events fire from data-driven conditions; the player
# answers with Placate, Deflect or Assert. Assert spends Rage into Sanity and
# builds self-respect. Dialogue pauses GameClock time, locks player input, and closes Phone.

signal event_started(event: NarrativeEvent)
signal event_finished(event: NarrativeEvent, choice: NarrativeChoice)
signal flag_changed(flag_name: StringName, value: int)

const DEFAULT_LIBRARY_PATH: String = "res://data/narrative/library.tres"
const DEFAULT_COOLDOWN_MINUTES: int = 60

var library: NarrativeLibrary = null
var active_event: NarrativeEvent = null
var flags: Dictionary = {} # StringName -> int
var fired_events: Array[StringName] = []
var last_event_minute: int = -9999
var cooldown_minutes: int = DEFAULT_COOLDOWN_MINUTES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Autoloads strictly above NarrativeManager (#1-#7)
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus and not bus.is_connected("narrative_requested", _on_narrative_requested):
		bus.connect("narrative_requested", _on_narrative_requested)

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and not clock.is_connected("hour_changed", _on_clock_hour_changed):
		clock.connect("hour_changed", _on_clock_hour_changed)

	# Deferred connection for SceneRouter (#9) to strictly observe initialization order
	_connect_scene_router.call_deferred()

	reset_state()


func _connect_scene_router() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and not router.is_connected("level_changed", _on_level_changed):
		router.connect("level_changed", _on_level_changed)


func reset_state() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("has_pause_reason") and clock.has_method("pop_pause"):
		while clock.has_pause_reason(&"dialogue"):
			clock.pop_pause(&"dialogue")

	_lock_player_input(false)

	active_event = null
	flags.clear()
	fired_events.clear()
	last_event_minute = -9999
	cooldown_minutes = DEFAULT_COOLDOWN_MINUTES

	if ResourceLoader.exists(DEFAULT_LIBRARY_PATH):
		library = load(DEFAULT_LIBRARY_PATH) as NarrativeLibrary
	else:
		library = NarrativeLibrary.new()


func to_dict() -> Dictionary:
	var f_dict: Dictionary = {}
	for k: Variant in flags.keys():
		f_dict[str(k)] = int(flags[k])

	var fired_arr: Array[String] = []
	for fe: Variant in fired_events:
		fired_arr.append(str(fe))

	return {
		"flags": f_dict,
		"fired_events": fired_arr,
		"last_event_minute": last_event_minute,
		"cooldown_minutes": cooldown_minutes,
	}


func from_dict(data: Dictionary, _version: int = 1) -> void:
	reset_state()

	if data.has("flags") and data["flags"] is Dictionary:
		var d: Dictionary = data["flags"] as Dictionary
		for k: Variant in d.keys():
			flags[StringName(str(k))] = int(d[k])

	if data.has("fired_events") and data["fired_events"] is Array:
		var arr: Array = data["fired_events"] as Array
		for item: Variant in arr:
			fired_events.append(StringName(str(item)))

	if data.has("last_event_minute"):
		last_event_minute = int(data["last_event_minute"])

	if data.has("cooldown_minutes"):
		cooldown_minutes = int(data["cooldown_minutes"])


# --- Flags API ---

func get_flag(flag_name: StringName, default_val: int = 0) -> int:
	return int(flags.get(flag_name, default_val))


func set_flag(flag_name: StringName, value: int) -> void:
	var old_val: int = get_flag(flag_name)
	flags[flag_name] = value
	if old_val != value:
		flag_changed.emit(flag_name, value)


func has_flag(flag_name: StringName) -> bool:
	return flags.has(flag_name)


func increment_flag(flag_name: StringName, amount: int = 1) -> void:
	set_flag(flag_name, get_flag(flag_name) + amount)


func clear_flags() -> void:
	flags.clear()


# --- Fired Events API ---

func is_event_fired(id: StringName) -> bool:
	return fired_events.has(id)


func get_fired_events() -> Array[StringName]:
	return fired_events.duplicate()


func reset_fired_events() -> void:
	fired_events.clear()


func get_cooldown_remaining() -> int:
	var now_min: int = _get_current_minute()
	return maxi(0, cooldown_minutes - (now_min - last_event_minute))


# --- Trigger & Choice Resolution ---

func try_trigger() -> bool:
	if active_event != null:
		return false

	var now_min: int = _get_current_minute()
	if now_min - last_event_minute < cooldown_minutes:
		return false

	if library == null or library.events.is_empty():
		return false

	var candidates: Array[NarrativeEvent] = []
	for ev: NarrativeEvent in library.events:
		if ev == null:
			continue
		if ev.once and fired_events.has(ev.id):
			continue
		if ev.evaluate_conditions():
			candidates.append(ev)

	if candidates.is_empty():
		return false

	# Highest priority condition wins. Stable tie-break by earliest in array.
	var best_event: NarrativeEvent = candidates[0]
	for i: int in range(1, candidates.size()):
		if candidates[i].priority > best_event.priority:
			best_event = candidates[i]

	return trigger_event(best_event)


func trigger_event(event_or_id: Variant) -> bool:
	if active_event != null:
		return false

	var ev: NarrativeEvent = null
	if event_or_id is NarrativeEvent:
		ev = event_or_id
	elif event_or_id is String or event_or_id is StringName:
		if library:
			ev = library.get_event(StringName(str(event_or_id)))
	if ev == null:
		return false

	active_event = ev
	if ev.once and not fired_events.has(ev.id):
		fired_events.append(ev.id)

	last_event_minute = _get_current_minute()

	# Pause game time if not already paused for dialogue
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("has_pause_reason") and not clock.has_pause_reason(&"dialogue"):
		if clock.has_method("push_pause"):
			clock.push_pause(&"dialogue")

	# Lock player input
	_lock_player_input(true)

	# Close phone if open
	_close_phone_if_open()

	event_started.emit(active_event)
	return true


func choose(index: int) -> void:
	if active_event == null:
		push_warning("NarrativeManager: choose() called with no active event.")
		return

	if index < 0 or index >= active_event.choices.size():
		push_warning("NarrativeManager: Invalid choice index %d." % index)
		return

	var choice: NarrativeChoice = active_event.choices[index]
	if choice == null:
		return

	# Apply choice modifiers
	var status_mgr: Node = get_node_or_null("/root/StatusManager")
	var has_rage_mod: bool = false
	var has_sanity_mod: bool = false

	for mod: StatModifier in choice.modifiers:
		if mod:
			if mod.source_id.is_empty():
				mod.source_id = &"narrative"
			if mod.stat == Enums.Stat.RAGE:
				has_rage_mod = true
			elif mod.stat == Enums.Stat.SANITY:
				has_sanity_mod = true
			if status_mgr and status_mgr.has_method("add_modifier"):
				status_mgr.add_modifier(mod)

	# Apply choice flags
	for flag_key: Variant in choice.set_flags:
		set_flag(StringName(str(flag_key)), int(choice.set_flags[flag_key]))

	# Stance Assert convention:
	# Assert convention: Rage INSTANT down, Sanity INSTANT up, increments flag self_respect
	if choice.stance == Enums.Stance.ASSERT:
		increment_flag(&"self_respect", 1)
		if not has_rage_mod and status_mgr and status_mgr.has_method("apply_instant_modifier"):
			status_mgr.apply_instant_modifier(Enums.Stat.RAGE, -20.0, &"narrative_assert")
		if not has_sanity_mod and status_mgr and status_mgr.has_method("apply_instant_modifier"):
			status_mgr.apply_instant_modifier(Enums.Stat.SANITY, 15.0, &"narrative_assert")

	var follow_up: Resource = choice.follow_up
	var finished_event: NarrativeEvent = active_event
	active_event = null

	event_finished.emit(finished_event, choice)

	if follow_up != null and (follow_up is NarrativeEvent or (library and library.has_event(follow_up.get("id")))):
		# Follow up event continues dialogue; time stays paused
		trigger_event(follow_up)
	else:
		# End of dialogue: unpause clock and unlock player
		var clock: Node = get_node_or_null("/root/GameClock")
		if clock and clock.has_method("pop_pause"):
			clock.pop_pause(&"dialogue")
		_lock_player_input(false)


# --- Signal Listeners ---

func _on_clock_hour_changed(_hour: int) -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("is_skipping_time") and clock.is_skipping_time():
		return
	try_trigger()


func _on_level_changed(_level_id: String) -> void:
	try_trigger()


func _on_narrative_requested(event_id: StringName) -> void:
	if event_id.is_empty():
		try_trigger()
	elif event_id == &"daily_pressure":
		if not trigger_event(event_id):
			try_trigger()
	else:
		trigger_event(event_id)


# --- Helper Methods ---

func _get_current_minute() -> int:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		return int(clock.get("now_minutes"))
	return 0


func _lock_player_input(lock: bool) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var players: Array[Node] = tree.get_nodes_in_group(&"player")
	for p: Node in players:
		if lock:
			if p.has_method("lock_input"):
				p.call("lock_input", &"dialogue")
		else:
			if p.has_method("unlock_input"):
				p.call("unlock_input", &"dialogue")


func _close_phone_if_open() -> void:
	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.get("is_open"):
		phone.call("close", true)
