extends Node

signal phase_changed(phase: Enums.CyclePhase, data: CyclePhaseData)

const DEFAULT_PHASE_PATHS: Dictionary = {
	Enums.CyclePhase.MENSTRUAL: "res://data/cycle_phases/menstrual.tres",
	Enums.CyclePhase.FOLLICULAR: "res://data/cycle_phases/follicular.tres",
	Enums.CyclePhase.OVULATORY: "res://data/cycle_phases/ovulatory.tres",
	Enums.CyclePhase.LUTEAL: "res://data/cycle_phases/luteal.tres",
}

var current_phase: Enums.CyclePhase = Enums.CyclePhase.FOLLICULAR
var current_data: CyclePhaseData = null
var day_in_phase: int = 1
var days_until_next_phase: int = 7
var cycle_start_day: int = -4

var _phase_data_map: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("day_started", _on_game_clock_day_started):
			clock.connect("day_started", _on_game_clock_day_started)
	_connect_settings()
	reset_state()

func reset_state() -> void:
	_load_phase_data()
	_connect_settings()
	var lengths: Dictionary = get_scaled_phase_lengths()
	cycle_start_day = 1 - int(lengths[Enums.CyclePhase.MENSTRUAL])

	var curr_day: int = _get_current_day()
	var state: Dictionary = _compute_phase_state(curr_day)
	current_phase = state["phase"] as Enums.CyclePhase
	current_data = get_phase_data(current_phase)
	day_in_phase = int(state["day_in_phase"])
	days_until_next_phase = int(state["days_until_next_phase"])

	_apply_cycle_modifiers()

func to_dict() -> Dictionary:
	return {
		"cycle_start_day": cycle_start_day,
		"current_phase": int(current_phase),
	}

func from_dict(data: Dictionary, _version: int = 1) -> void:
	_load_phase_data()
	_connect_settings()
	if data.has("cycle_start_day"):
		cycle_start_day = int(data["cycle_start_day"])

	var curr_day: int = _get_current_day()
	var state: Dictionary = _compute_phase_state(curr_day)
	current_phase = state["phase"] as Enums.CyclePhase
	current_data = get_phase_data(current_phase)
	day_in_phase = int(state["day_in_phase"])
	days_until_next_phase = int(state["days_until_next_phase"])

	_apply_cycle_modifiers()

func has_tag(tag: StringName) -> bool:
	if current_data == null:
		return false
	return current_data.has_tag(tag)

func force_phase(phase: Enums.CyclePhase) -> void:
	var total_days: int = GameSettings.current().cycle_length_days
	var lengths: Dictionary = get_scaled_phase_lengths(total_days)
	var len_m: int = int(lengths[Enums.CyclePhase.MENSTRUAL])
	var len_f: int = int(lengths[Enums.CyclePhase.FOLLICULAR])
	var len_o: int = int(lengths[Enums.CyclePhase.OVULATORY])

	var target_offset: int = 0
	match phase:
		Enums.CyclePhase.MENSTRUAL:
			target_offset = 0
		Enums.CyclePhase.FOLLICULAR:
			target_offset = len_m
		Enums.CyclePhase.OVULATORY:
			target_offset = len_m + len_f
		Enums.CyclePhase.LUTEAL:
			target_offset = len_m + len_f + len_o

	var curr_day: int = _get_current_day()
	cycle_start_day = curr_day - target_offset

	var state: Dictionary = _compute_phase_state(curr_day)
	current_phase = state["phase"] as Enums.CyclePhase
	current_data = get_phase_data(current_phase)
	day_in_phase = int(state["day_in_phase"])
	days_until_next_phase = int(state["days_until_next_phase"])

	_apply_cycle_modifiers()
	phase_changed.emit(current_phase, current_data)

func get_phase_data(phase: Enums.CyclePhase) -> CyclePhaseData:
	if not _phase_data_map.has(phase):
		_load_phase_data()
	return _phase_data_map.get(phase, null)

func get_scaled_phase_lengths(total_days: int = -1) -> Dictionary:
	if total_days <= 0:
		total_days = GameSettings.current().cycle_length_days

	var default_days: Array[int] = [
		_get_default_days(Enums.CyclePhase.MENSTRUAL),
		_get_default_days(Enums.CyclePhase.FOLLICULAR),
		_get_default_days(Enums.CyclePhase.OVULATORY),
		_get_default_days(Enums.CyclePhase.LUTEAL),
	]
	var total_default: int = 0
	for d: int in default_days:
		total_default += d
	if total_default <= 0:
		total_default = 28

	var quotas: Array[float] = []
	var allocated: Array[int] = []
	var remainders: Array[float] = []
	var current_sum: int = 0

	for d: int in default_days:
		var q: float = float(total_days * d) / float(total_default)
		var f: int = maxi(1, int(q))
		quotas.append(q)
		allocated.append(f)
		remainders.append(q - float(int(q)))
		current_sum += f

	var diff: int = total_days - current_sum
	if diff > 0:
		var indices: Array[int] = [0, 1, 2, 3]
		indices.sort_custom(func(a: int, b: int) -> bool:
			if not is_equal_approx(remainders[a], remainders[b]):
				return remainders[a] > remainders[b]
			return default_days[a] > default_days[b]
		)
		for i: int in range(diff):
			allocated[indices[i % 4]] += 1
	elif diff < 0:
		var indices: Array[int] = [0, 1, 2, 3]
		indices.sort_custom(func(a: int, b: int) -> bool:
			if not is_equal_approx(remainders[a], remainders[b]):
				return remainders[a] < remainders[b]
			return default_days[a] < default_days[b]
		)
		var to_reduce: int = -diff
		for idx: int in indices:
			while to_reduce > 0 and allocated[idx] > 1:
				allocated[idx] -= 1
				to_reduce -= 1
			if to_reduce == 0:
				break

	return {
		Enums.CyclePhase.MENSTRUAL: allocated[0],
		Enums.CyclePhase.FOLLICULAR: allocated[1],
		Enums.CyclePhase.OVULATORY: allocated[2],
		Enums.CyclePhase.LUTEAL: allocated[3],
	}

func _compute_phase_state(at_day: int) -> Dictionary:
	var total_days: int = GameSettings.current().cycle_length_days
	var lengths: Dictionary = get_scaled_phase_lengths(total_days)
	var len_m: int = int(lengths[Enums.CyclePhase.MENSTRUAL])
	var len_f: int = int(lengths[Enums.CyclePhase.FOLLICULAR])
	var len_o: int = int(lengths[Enums.CyclePhase.OVULATORY])
	var len_l: int = int(lengths[Enums.CyclePhase.LUTEAL])

	var offset: int = posmod(at_day - cycle_start_day, total_days)

	var phase: Enums.CyclePhase = Enums.CyclePhase.MENSTRUAL
	var d_in_phase: int = 1
	var d_until_next: int = 0

	if offset < len_m:
		phase = Enums.CyclePhase.MENSTRUAL
		d_in_phase = offset + 1
		d_until_next = len_m - d_in_phase
	elif offset < len_m + len_f:
		phase = Enums.CyclePhase.FOLLICULAR
		d_in_phase = (offset - len_m) + 1
		d_until_next = len_f - d_in_phase
	elif offset < len_m + len_f + len_o:
		phase = Enums.CyclePhase.OVULATORY
		d_in_phase = (offset - len_m - len_f) + 1
		d_until_next = len_o - d_in_phase
	else:
		phase = Enums.CyclePhase.LUTEAL
		d_in_phase = (offset - len_m - len_f - len_o) + 1
		d_until_next = len_l - d_in_phase

	return {
		"phase": phase,
		"day_in_phase": d_in_phase,
		"days_until_next_phase": d_until_next,
	}

func _apply_cycle_modifiers() -> void:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if not sm or not sm.has_method("remove_by_source") or not sm.has_method("add_modifier"):
		return

	sm.remove_by_source(&"cycle")

	if current_data == null:
		return

	var intensity: float = GameSettings.current().symptom_intensity
	for mod: StatModifier in current_data.modifiers:
		var scaled_mod: StatModifier = mod.scaled(intensity)
		scaled_mod.source_id = &"cycle"
		scaled_mod.duration_min = -1
		sm.add_modifier(scaled_mod)

func _on_game_clock_day_started(day_num: int) -> void:
	var old_phase: Enums.CyclePhase = current_phase
	var state: Dictionary = _compute_phase_state(day_num)
	var new_phase: Enums.CyclePhase = state["phase"] as Enums.CyclePhase
	day_in_phase = int(state["day_in_phase"])
	days_until_next_phase = int(state["days_until_next_phase"])

	if new_phase != old_phase:
		current_phase = new_phase
		current_data = get_phase_data(new_phase)
		_apply_cycle_modifiers()
		phase_changed.emit(current_phase, current_data)

func _on_game_settings_changed() -> void:
	var curr_day: int = _get_current_day()
	var old_phase: Enums.CyclePhase = current_phase
	var state: Dictionary = _compute_phase_state(curr_day)
	var new_phase: Enums.CyclePhase = state["phase"] as Enums.CyclePhase
	day_in_phase = int(state["day_in_phase"])
	days_until_next_phase = int(state["days_until_next_phase"])

	if new_phase != old_phase:
		current_phase = new_phase
		current_data = get_phase_data(new_phase)
		_apply_cycle_modifiers()
		phase_changed.emit(current_phase, current_data)
	else:
		_apply_cycle_modifiers()

func _connect_settings() -> void:
	var settings: GameSettings = GameSettings.current()
	if settings and not settings.is_connected("changed", _on_game_settings_changed):
		settings.connect("changed", _on_game_settings_changed)

func _get_current_day() -> int:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("get_day"):
		return int(clock.call("get_day"))
	return 1

func _get_default_days(phase: Enums.CyclePhase) -> int:
	var data: CyclePhaseData = get_phase_data(phase)
	if data and data.default_days > 0:
		return data.default_days
	match phase:
		Enums.CyclePhase.MENSTRUAL:
			return 5
		Enums.CyclePhase.FOLLICULAR:
			return 8
		Enums.CyclePhase.OVULATORY:
			return 3
		Enums.CyclePhase.LUTEAL:
			return 12
	return 1

func _load_phase_data() -> void:
	for phase_enum: Enums.CyclePhase in DEFAULT_PHASE_PATHS:
		var path: String = DEFAULT_PHASE_PATHS[phase_enum]
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is CyclePhaseData:
				_phase_data_map[phase_enum] = res
		if not _phase_data_map.has(phase_enum):
			_phase_data_map[phase_enum] = _create_fallback_phase_data(phase_enum)

func _create_fallback_phase_data(phase: Enums.CyclePhase) -> CyclePhaseData:
	var data: CyclePhaseData = CyclePhaseData.new()
	data.phase = phase
	match phase:
		Enums.CyclePhase.MENSTRUAL:
			data.display_name = "CYCLE_PHASE_MENSTRUAL"
			data.default_days = 5
			data.length_days = Vector2i(3, 7)
			data.symptom_tags = [&"cramps", &"fatigue", &"low_energy"]
			data.narrative_tags = [&"menstrual", &"rest_needed"]
		Enums.CyclePhase.FOLLICULAR:
			data.display_name = "CYCLE_PHASE_FOLLICULAR"
			data.default_days = 8
			data.length_days = Vector2i(6, 12)
			data.symptom_tags = [&"energy_boost", &"clear_focus"]
			data.narrative_tags = [&"follicular", &"creative"]
		Enums.CyclePhase.OVULATORY:
			data.display_name = "CYCLE_PHASE_OVULATORY"
			data.default_days = 3
			data.length_days = Vector2i(2, 4)
			data.symptom_tags = [&"peak_confidence", &"social_energy"]
			data.narrative_tags = [&"ovulatory", &"charismatic"]
		Enums.CyclePhase.LUTEAL:
			data.display_name = "CYCLE_PHASE_LUTEAL"
			data.default_days = 12
			data.length_days = Vector2i(10, 16)
			data.symptom_tags = [&"restlessness", &"irritability", &"introspective"]
			data.narrative_tags = [&"luteal", &"boundaries"]
			var luteal_mod: StatModifier = StatModifier.new()
			luteal_mod.stat = Enums.Stat.RAGE
			luteal_mod.kind = Enums.ModifierKind.RATE_MUL
			luteal_mod.value = 1.3
			luteal_mod.source_id = &"cycle"
			luteal_mod.duration_min = -1
			luteal_mod.label = "Luteal irritability"
			data.modifiers = [luteal_mod]
	return data
