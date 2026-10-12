extends Node

signal stat_changed(stat: Enums.Stat, value: float, delta: float)
signal modifiers_changed()
signal stat_depleted(stat: Enums.Stat)
signal stat_maxed(stat: Enums.Stat)

var config: StatusConfig = null

var _values: Dictionary = {}
var _active_modifiers: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("minute_ticked", _on_game_clock_minute_ticked):
			clock.connect("minute_ticked", _on_game_clock_minute_ticked)
		if not clock.is_connected("time_skipped", _on_game_clock_time_skipped):
			clock.connect("time_skipped", _on_game_clock_time_skipped)
	reset_state()

func reset_state() -> void:
	config = StatusConfig.load_default()
	_active_modifiers.clear()
	_values.clear()
	for s: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
		_values[s] = clampf(_get_start_value(s), 0.0, get_max(s))

func to_dict() -> Dictionary:
	var vals: Dictionary = {}
	for s: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
		vals[str(int(s))] = _values.get(s, 0.0)

	var mods: Array[Dictionary] = []
	for entry: Dictionary in _active_modifiers:
		var mod: StatModifier = entry["modifier"] as StatModifier
		var item: Dictionary = mod.to_dict()
		item["expires_at"] = int(entry["expires_at"])
		mods.append(item)

	return {
		"values": vals,
		"modifiers": mods,
	}

func from_dict(data: Dictionary, _version: int = 1) -> void:
	_active_modifiers.clear()
	if data.has("modifiers") and data["modifiers"] is Array:
		for item: Variant in (data["modifiers"] as Array):
			if item is Dictionary:
				var item_dict: Dictionary = item as Dictionary
				var mod: StatModifier = StatModifier.from_dict(item_dict)
				var exp_at: int = int(item_dict.get("expires_at", -1))
				_active_modifiers.append({
					"modifier": mod,
					"expires_at": exp_at,
				})

	if data.has("values") and data["values"] is Dictionary:
		var vals: Dictionary = data["values"] as Dictionary
		for s: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
			var key: String = str(int(s))
			if vals.has(key):
				var max_val: float = get_max(s)
				_values[s] = clampf(float(vals[key]), 0.0, max_val)

func get_value(stat: Enums.Stat) -> float:
	return _values.get(stat, 0.0)

func get_stat(stat: Variant) -> float:
	if stat is String or stat is StringName:
		var s: String = str(stat).to_upper()
		match s:
			"SANITY": return get_value(Enums.Stat.SANITY)
			"HEALTH": return get_value(Enums.Stat.HEALTH)
			"HYGIENE": return get_value(Enums.Stat.HYGIENE)
			"RAGE": return get_value(Enums.Stat.RAGE)
			_: return 0.0
	if stat is int:
		return get_value(stat as Enums.Stat)
	return 0.0

func set_value(stat: Enums.Stat, v: float) -> void:
	if not _values.has(stat):
		return
	var old_val: float = _values[stat]
	var max_val: float = get_max(stat)
	var new_val: float = clampf(v, 0.0, max_val)
	var delta: float = new_val - old_val
	if not is_zero_approx(delta):
		_values[stat] = new_val
		stat_changed.emit(stat, new_val, delta)
		if old_val > 0.0 and is_zero_approx(new_val):
			stat_depleted.emit(stat)
		elif delta > 0.0 and is_equal_approx(new_val, max_val):
			stat_maxed.emit(stat)

func get_max(stat: Enums.Stat) -> float:
	var max_val: float = StatModifier.STAT_MAX
	for entry: Dictionary in _active_modifiers:
		var mod: StatModifier = entry["modifier"] as StatModifier
		if mod.stat == stat and mod.kind == Enums.ModifierKind.CAP:
			max_val = minf(max_val, mod.value)
	return max_val

func get_effective_rate(stat: Enums.Stat) -> float:
	var base_rate: float = _get_base_rate(stat)
	var add_sum: float = 0.0
	var mul_prod: float = 1.0

	for entry: Dictionary in _active_modifiers:
		var mod: StatModifier = entry["modifier"] as StatModifier
		if mod.stat == stat:
			if mod.kind == Enums.ModifierKind.RATE_ADD:
				add_sum += mod.value
			elif mod.kind == Enums.ModifierKind.RATE_MUL:
				mul_prod *= mod.value

	return (base_rate + add_sum) * mul_prod

func add_modifier(mod: StatModifier) -> void:
	if not mod or not mod.is_valid():
		push_warning("StatusManager: Cannot add invalid modifier.")
		return

	if mod.kind == Enums.ModifierKind.INSTANT:
		_apply_instant(mod.stat, mod.value)
		return

	var copy: StatModifier = mod.duplicate() as StatModifier
	var current_min: int = _get_current_minute()
	var expires_at: int = -1
	if copy.duration_min != -1:
		expires_at = current_min + copy.duration_min

	var replaced_idx: int = -1
	for i: int in range(_active_modifiers.size()):
		var existing: StatModifier = _active_modifiers[i]["modifier"] as StatModifier
		if existing.source_id == copy.source_id and existing.stat == copy.stat and existing.kind == copy.kind:
			replaced_idx = i
			break

	if replaced_idx != -1:
		_active_modifiers[replaced_idx] = {
			"modifier": copy,
			"expires_at": expires_at,
		}
	else:
		_active_modifiers.append({
			"modifier": copy,
			"expires_at": expires_at,
		})

	if copy.kind == Enums.ModifierKind.CAP:
		var max_val: float = get_max(copy.stat)
		var curr_val: float = _values.get(copy.stat, 0.0)
		if curr_val > max_val:
			var delta: float = max_val - curr_val
			_values[copy.stat] = max_val
			stat_changed.emit(copy.stat, max_val, delta)
			if is_zero_approx(max_val):
				stat_depleted.emit(copy.stat)

	modifiers_changed.emit()

func remove_by_source(source_id: StringName) -> void:
	if source_id.is_empty():
		return
	var removed: bool = false
	for i: int in range(_active_modifiers.size() - 1, -1, -1):
		var mod: StatModifier = _active_modifiers[i]["modifier"] as StatModifier
		if mod.source_id == source_id:
			_active_modifiers.remove_at(i)
			removed = true
	if removed:
		modifiers_changed.emit()

func get_modifiers(stat: int = -1) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for entry: Dictionary in _active_modifiers:
		var mod: StatModifier = entry["modifier"] as StatModifier
		if stat == -1 or int(mod.stat) == stat:
			result.append(mod)
	return result

func get_modifier_expires_at(mod: StatModifier) -> int:
	for entry: Dictionary in _active_modifiers:
		if entry["modifier"] == mod:
			return int(entry["expires_at"])
	return -1

func _on_game_clock_minute_ticked(now_minute: int) -> void:
	_integrate_decay(now_minute - 1, now_minute)

func _on_game_clock_time_skipped(from_minute: int, to_minute: int) -> void:
	_integrate_decay(from_minute, to_minute)

func _integrate_decay(from_min: int, to_min: int) -> void:
	if from_min >= to_min:
		return

	_purge_expired_modifiers(from_min)

	var splits: Array[int] = []
	for entry: Dictionary in _active_modifiers:
		var exp: int = int(entry["expires_at"])
		if exp > from_min and exp < to_min:
			if not splits.has(exp):
				splits.append(exp)
	splits.sort()

	var curr: int = from_min
	for sp: int in splits:
		_integrate_constant_segment(curr, sp)
		_purge_expired_modifiers(sp)
		curr = sp

	if curr < to_min:
		_integrate_constant_segment(curr, to_min)
		_purge_expired_modifiers(to_min)

func _integrate_constant_segment(sub_from: int, sub_to: int) -> void:
	var dt: int = sub_to - sub_from
	if dt <= 0:
		return

	for s: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
		var rate_per_hour: float = get_effective_rate(s)
		var delta: float = (rate_per_hour / 60.0) * float(dt)
		if is_zero_approx(delta):
			continue

		var old_val: float = _values[s]
		var max_val: float = get_max(s)
		var new_val: float = clampf(old_val + delta, 0.0, max_val)
		var actual_delta: float = new_val - old_val

		if not is_zero_approx(actual_delta):
			_values[s] = new_val
			stat_changed.emit(s, new_val, actual_delta)

			if old_val > 0.0 and is_zero_approx(new_val):
				stat_depleted.emit(s)
			elif actual_delta > 0.0 and is_equal_approx(new_val, max_val):
				stat_maxed.emit(s)

func _purge_expired_modifiers(minute: int) -> void:
	var removed: bool = false
	for i: int in range(_active_modifiers.size() - 1, -1, -1):
		var exp: int = int(_active_modifiers[i]["expires_at"])
		if exp != -1 and exp <= minute:
			_active_modifiers.remove_at(i)
			removed = true
	if removed:
		modifiers_changed.emit()

func _apply_instant(stat: Enums.Stat, value_delta: float) -> void:
	if not _values.has(stat):
		return
	var old_val: float = _values[stat]
	var max_val: float = get_max(stat)
	var new_val: float = clampf(old_val + value_delta, 0.0, max_val)
	var delta: float = new_val - old_val
	if not is_zero_approx(delta):
		_values[stat] = new_val
		stat_changed.emit(stat, new_val, delta)
		if old_val > 0.0 and is_zero_approx(new_val):
			stat_depleted.emit(stat)
		elif delta > 0.0 and is_equal_approx(new_val, max_val):
			stat_maxed.emit(stat)

func _get_current_minute() -> int:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock != null:
		return int(clock.get("now_minutes"))
	return 0

func _get_start_value(stat: Enums.Stat) -> float:
	if config != null:
		return config.get_start_value(stat)
	return 0.0

func _get_base_rate(stat: Enums.Stat) -> float:
	if config != null:
		return config.get_base_rate(stat)
	return 0.0
