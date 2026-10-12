extends Node

signal prep_started(outing: OutingData)
signal departure_deadline_reached(outing: OutingData)
signal outing_departed(outing: OutingData)
signal outing_resolved(outing: OutingData, result: Enums.OutingResult, score: float)
signal outing_missed(outing: OutingData)

var active_outing: OutingData = null
var active_departure_min: int = -1
var active_partner_ref: String = ""

var affinity: Dictionary = {}  # partner_ref (String) -> int

var _scheduled: Array[Dictionary] = []
var _departure_deadline_emitted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("countdown_finished", _on_countdown_finished):
			clock.connect("countdown_finished", _on_countdown_finished)
		if not clock.is_connected("minute_ticked", _on_minute_ticked):
			clock.connect("minute_ticked", _on_minute_ticked)
		if not clock.is_connected("time_skipped", _on_time_skipped):
			clock.connect("time_skipped", _on_time_skipped)
	reset_state()


func reset_state() -> void:
	_scheduled.clear()
	active_outing = null
	active_departure_min = -1
	active_partner_ref = ""
	_departure_deadline_emitted = false
	affinity.clear()

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("cancel_countdown"):
		clock.call("cancel_countdown", &"outing_prep_start")
		clock.call("cancel_countdown", &"outing_departure_deadline")
		clock.call("cancel_countdown", &"outing_late_grace_deadline")


func schedule(outing: OutingData, departure_min: int, partner_ref: String = "") -> bool:
	if outing == null:
		return false

	var current_time: int = _get_current_minute()
	if departure_min <= current_time:
		return false

	var new_start: int = departure_min - outing.prep_window_min
	var new_end: int = departure_min + outing.duration_min

	# Check overlaps against already scheduled outings
	for entry: Dictionary in _scheduled:
		var ex_outing: OutingData = entry["outing"] as OutingData
		if ex_outing == null:
			continue
		var ex_dep: int = int(entry["departure_min"])
		var ex_start: int = ex_dep - ex_outing.prep_window_min
		var ex_end: int = ex_dep + ex_outing.duration_min
		if maxi(new_start, ex_start) < mini(new_end, ex_end):
			return false

	# Check overlap against active prep / outing if any
	if active_outing != null and active_departure_min > 0:
		var act_start: int = active_departure_min - active_outing.prep_window_min
		var act_end: int = active_departure_min + active_outing.duration_min
		if maxi(new_start, act_start) < mini(new_end, act_end):
			return false

	var scheduled_entry: Dictionary = {
		"outing": outing,
		"departure_min": departure_min,
		"partner_ref": partner_ref,
		"prep_started": false,
	}
	_scheduled.append(scheduled_entry)

	var outing_ref: String = ResRef.to_ref(outing)
	if outing_ref.is_empty():
		outing_ref = outing.resource_path if not outing.resource_path.is_empty() else str(outing.id)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("outing_scheduled"):
		bus.emit_signal("outing_scheduled", outing_ref, departure_min, partner_ref)

	if new_start <= current_time:
		_start_prep(scheduled_entry)
	else:
		var clock: Node = get_node_or_null("/root/GameClock")
		if clock and clock.has_method("create_countdown"):
			clock.call(
				"create_countdown",
				&"outing_prep_start",
				new_start,
				{
					"outing_id": str(outing.id),
					"departure_min": departure_min,
					"partner_ref": partner_ref,
				}
			)

	return true


func get_scheduled() -> Array:
	return _scheduled.duplicate(true)


func is_prep_active() -> bool:
	return active_outing != null


func get_checklist() -> Array[Dictionary]:
	if active_outing == null:
		return []

	var items: Array[Dictionary] = []
	for check: PrepCheck in active_outing.checks:
		if check == null:
			continue
		var s: float = check.evaluate()
		items.append({
			"label": check.label,
			"score": s,
			"passed": check.is_passed(s),
			"weight": check.weight,
		})
	return items


func is_late() -> bool:
	if active_outing == null or active_departure_min <= 0:
		return false
	return _get_current_minute() > active_departure_min


func get_lateness_min(departure_min: int = -1, current_min: int = -1) -> int:
	if departure_min < 0:
		departure_min = active_departure_min
	if current_min < 0:
		current_min = _get_current_minute()
	if departure_min <= 0:
		return 0
	return maxi(0, current_min - departure_min)


func calculate_penalty(outing: OutingData = null, lateness_min: int = -1) -> float:
	if outing == null:
		outing = active_outing
	if outing == null:
		return 0.0
	if lateness_min < 0:
		lateness_min = get_lateness_min()
	return (float(lateness_min) / 10.0) * outing.late_penalty_per_10_min


func evaluate(outing: OutingData = null, departure_min: int = -1, current_min: int = -1) -> Dictionary:
	if outing == null:
		outing = active_outing
	if outing == null:
		return {
			"score": 0.0,
			"raw_score": 0.0,
			"result": Enums.OutingResult.FAIL,
			"check_results": [],
			"checklist": [],
			"lateness_min": 0,
			"penalty": 0.0,
		}

	if departure_min < 0:
		departure_min = active_departure_min
	if current_min < 0:
		current_min = _get_current_minute()

	var checklist: Array[Dictionary] = []
	var total_weight: float = 0.0
	var weighted_score: float = 0.0

	for check: PrepCheck in outing.checks:
		if check == null:
			continue
		var s: float = check.evaluate()
		var w: float = check.weight
		var p: bool = check.is_passed(s)
		checklist.append({
			"label": check.label,
			"score": s,
			"passed": p,
			"weight": w,
		})
		weighted_score += s * w
		total_weight += w

	var raw_score: float = (weighted_score / total_weight) if total_weight > 0.0 else 1.0
	var lateness: int = maxi(0, current_min - departure_min) if departure_min > 0 else 0
	var penalty: float = (float(lateness) / 10.0) * outing.late_penalty_per_10_min
	var final_score: float = clampf(raw_score - penalty, 0.0, 1.0)

	var res: Enums.OutingResult = Enums.OutingResult.FAIL
	if final_score >= outing.pass_threshold:
		res = Enums.OutingResult.PASS
	elif final_score >= outing.partial_threshold:
		res = Enums.OutingResult.PARTIAL
	else:
		res = Enums.OutingResult.FAIL

	return {
		"score": final_score,
		"raw_score": raw_score,
		"result": res,
		"check_results": checklist,
		"checklist": checklist,
		"lateness_min": lateness,
		"penalty": penalty,
	}


func depart() -> Dictionary:
	if active_outing == null:
		return {}

	var outing: OutingData = active_outing
	var partner: String = active_partner_ref
	var eval_res: Dictionary = evaluate()
	var res_enum: Enums.OutingResult = eval_res["result"] as Enums.OutingResult

	# 1. Charge bill
	var fm: Node = get_node_or_null("/root/FinanceManager")
	if fm and fm.has_method("charge_bill") and outing.cost_cents > 0:
		fm.call("charge_bill", outing.cost_cents, &"outing", "%s Outing" % outing.display_name)

	# 2. Clear active outing and countdowns before skipping time
	_clear_active_outing()

	# 3. Skip duration
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("skip") and outing.duration_min > 0:
		clock.call("skip", outing.duration_min)

	# 4. Apply modifiers with source_id = "outing:<id>"
	var sm: Node = get_node_or_null("/root/StatusManager")
	var mods: Array[StatModifier] = outing.get_modifiers_for_result(res_enum)
	var source_id: StringName = StringName("outing:%s" % outing.id)
	if sm and sm.has_method("add_modifier"):
		for m: StatModifier in mods:
			if m:
				var copy: StatModifier = m.duplicate() as StatModifier
				copy.source_id = source_id
				sm.call("add_modifier", copy)

	# 5. Affinity update
	var delta: int = outing.get_affinity_delta(res_enum)
	if not partner.is_empty():
		add_affinity(partner, delta)

	# 6. Emit signals
	outing_departed.emit(outing)
	outing_resolved.emit(outing, res_enum, eval_res["score"])

	return eval_res


func _miss_outing() -> void:
	if active_outing == null:
		return

	var outing: OutingData = active_outing
	var partner: String = active_partner_ref

	# Apply FAIL modifiers with source_id = "outing:<id>"
	var sm: Node = get_node_or_null("/root/StatusManager")
	var mods: Array[StatModifier] = outing.get_modifiers_for_result(Enums.OutingResult.FAIL)
	var source_id: StringName = StringName("outing:%s" % outing.id)
	if sm and sm.has_method("add_modifier"):
		for m: StatModifier in mods:
			if m:
				var copy: StatModifier = m.duplicate() as StatModifier
				copy.source_id = source_id
				sm.call("add_modifier", copy)

	# Affinity penalty for FAIL
	var delta: int = outing.get_affinity_delta(Enums.OutingResult.FAIL)
	if not partner.is_empty():
		add_affinity(partner, delta)

	# Clear active outing without time skip and without billing
	_clear_active_outing()

	# Emit signal
	outing_missed.emit(outing)


func _clear_active_outing() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("cancel_countdown"):
		clock.call("cancel_countdown", &"outing_prep_start")
		clock.call("cancel_countdown", &"outing_departure_deadline")
		clock.call("cancel_countdown", &"outing_late_grace_deadline")

	for i: int in range(_scheduled.size() - 1, -1, -1):
		if _scheduled[i].get("outing") == active_outing and int(_scheduled[i].get("departure_min")) == active_departure_min:
			_scheduled.remove_at(i)
			break

	active_outing = null
	active_departure_min = -1
	active_partner_ref = ""
	_departure_deadline_emitted = false


func get_affinity(partner_ref: String) -> int:
	return int(affinity.get(partner_ref, 0))


func set_affinity(partner_ref: String, value: int) -> void:
	affinity[partner_ref] = value


func add_affinity(partner_ref: String, delta: int) -> void:
	set_affinity(partner_ref, get_affinity(partner_ref) + delta)


func to_dict() -> Dictionary:
	var scheduled_list: Array[Dictionary] = []
	for entry: Dictionary in _scheduled:
		var out: OutingData = entry["outing"] as OutingData
		var o_ref: String = ""
		if out != null:
			o_ref = ResRef.to_ref(out)
			if o_ref.is_empty():
				o_ref = out.resource_path if not out.resource_path.is_empty() else str(out.id)
		scheduled_list.append({
			"outing_ref": o_ref,
			"departure_min": int(entry["departure_min"]),
			"partner_ref": str(entry["partner_ref"]),
			"prep_started": bool(entry["prep_started"]),
		})

	var active_ref: String = ""
	if active_outing != null:
		active_ref = ResRef.to_ref(active_outing)
		if active_ref.is_empty():
			active_ref = active_outing.resource_path if not active_outing.resource_path.is_empty() else str(active_outing.id)

	return {
		"affinity": affinity.duplicate(true),
		"scheduled": scheduled_list,
		"active_outing_ref": active_ref,
		"active_departure_min": active_departure_min,
		"active_partner_ref": active_partner_ref,
		"departure_deadline_emitted": _departure_deadline_emitted,
	}


func from_dict(data: Dictionary, _version: int = 1) -> void:
	reset_state()

	if data.has("affinity") and data["affinity"] is Dictionary:
		var aff_data: Dictionary = data["affinity"] as Dictionary
		for k: Variant in aff_data.keys():
			affinity[str(k)] = int(aff_data[k])

	if data.has("scheduled") and data["scheduled"] is Array:
		for raw_item: Variant in (data["scheduled"] as Array):
			if raw_item is Dictionary:
				var d: Dictionary = raw_item as Dictionary
				var o_ref: String = str(d.get("outing_ref", ""))
				var out: OutingData = _resolve_outing_resource(o_ref)
				if out != null:
					_scheduled.append({
						"outing": out,
						"departure_min": int(d.get("departure_min", 0)),
						"partner_ref": str(d.get("partner_ref", "")),
						"prep_started": bool(d.get("prep_started", false)),
					})

	var act_ref: String = str(data.get("active_outing_ref", ""))
	if not act_ref.is_empty():
		active_outing = _resolve_outing_resource(act_ref)
	active_departure_min = int(data.get("active_departure_min", -1))
	active_partner_ref = str(data.get("active_partner_ref", ""))
	_departure_deadline_emitted = bool(data.get("departure_deadline_emitted", false))

	# Restore countdowns on GameClock if needed
	var current_time: int = _get_current_minute()
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("create_countdown"):
		if active_outing != null:
			var grace_end: int = active_departure_min + active_outing.late_grace_min
			if current_time >= grace_end:
				_miss_outing()
			else:
				if active_departure_min > current_time and not _departure_deadline_emitted:
					if not bool(clock.call("has_countdown", &"outing_departure_deadline")):
						clock.call(
							"create_countdown",
							&"outing_departure_deadline",
							active_departure_min,
							{
								"outing_id": str(active_outing.id),
								"departure_min": active_departure_min,
								"partner_ref": active_partner_ref,
							}
						)
				if not bool(clock.call("has_countdown", &"outing_late_grace_deadline")):
					clock.call(
						"create_countdown",
						&"outing_late_grace_deadline",
						grace_end,
						{
							"outing_id": str(active_outing.id),
							"departure_min": active_departure_min,
							"grace_end": grace_end,
						}
					)
		else:
			for entry: Dictionary in _scheduled:
				if not entry["prep_started"]:
					var out: OutingData = entry["outing"] as OutingData
					var prep_min: int = int(entry["departure_min"]) - out.prep_window_min
					if prep_min > current_time and not bool(clock.call("has_countdown", &"outing_prep_start")):
						clock.call(
							"create_countdown",
							&"outing_prep_start",
							prep_min,
							{
								"outing_id": str(out.id),
								"departure_min": entry["departure_min"],
								"partner_ref": entry["partner_ref"],
							}
						)
						break


func _start_prep(entry: Dictionary) -> void:
	if entry.get("prep_started", false):
		return
	entry["prep_started"] = true
	active_outing = entry["outing"] as OutingData
	active_departure_min = int(entry["departure_min"])
	active_partner_ref = str(entry.get("partner_ref", ""))
	_departure_deadline_emitted = false

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("cancel_countdown"):
		clock.call("cancel_countdown", &"outing_prep_start")

	var current_time: int = _get_current_minute()
	if clock and clock.has_method("create_countdown"):
		if active_departure_min > current_time:
			clock.call(
				"create_countdown",
				&"outing_departure_deadline",
				active_departure_min,
				{
					"outing_id": str(active_outing.id),
					"departure_min": active_departure_min,
					"partner_ref": active_partner_ref,
				}
			)
		var grace_end: int = active_departure_min + active_outing.late_grace_min
		if grace_end > current_time:
			clock.call(
				"create_countdown",
				&"outing_late_grace_deadline",
				grace_end,
				{
					"outing_id": str(active_outing.id),
					"departure_min": active_departure_min,
					"grace_end": grace_end,
				}
			)

	prep_started.emit(active_outing)

	if active_departure_min <= current_time and not _departure_deadline_emitted:
		_departure_deadline_emitted = true
		departure_deadline_reached.emit(active_outing)

	if active_departure_min + active_outing.late_grace_min <= current_time:
		_miss_outing()


func _on_countdown_finished(id: StringName, payload: Dictionary) -> void:
	if id == &"outing_prep_start":
		for entry: Dictionary in _scheduled:
			if not entry["prep_started"]:
				var out: OutingData = entry["outing"] as OutingData
				var dep_match: bool = (entry["departure_min"] == payload.get("departure_min", -1))
				var id_match: bool = (out != null and str(out.id) == payload.get("outing_id", ""))
				if dep_match or id_match:
					_start_prep(entry)
					return
		# Fallback to first unstarted:
		for entry: Dictionary in _scheduled:
			if not entry["prep_started"]:
				_start_prep(entry)
				return
	elif id == &"outing_departure_deadline":
		if active_outing != null and not _departure_deadline_emitted:
			_departure_deadline_emitted = true
			departure_deadline_reached.emit(active_outing)
	elif id == &"outing_late_grace_deadline":
		if active_outing != null:
			_miss_outing()


func _on_minute_ticked(now_minute: int) -> void:
	_check_schedule_triggers(now_minute)


func _on_time_skipped(_from_minute: int, to_minute: int) -> void:
	_check_schedule_triggers(to_minute)


func _check_schedule_triggers(now_minute: int) -> void:
	if active_outing == null:
		for entry: Dictionary in _scheduled:
			if not entry["prep_started"]:
				var out: OutingData = entry["outing"] as OutingData
				if out != null:
					var prep_min: int = int(entry["departure_min"]) - out.prep_window_min
					if now_minute >= prep_min:
						_start_prep(entry)
						break

	if active_outing != null:
		if now_minute >= active_departure_min and not _departure_deadline_emitted:
			_departure_deadline_emitted = true
			departure_deadline_reached.emit(active_outing)
		var grace_end: int = active_departure_min + active_outing.late_grace_min
		if now_minute >= grace_end:
			_miss_outing()


func _resolve_outing_resource(ref_str: String) -> OutingData:
	if ref_str.is_empty():
		return null
	var res: Resource = ResRef.load_ref(ref_str)
	if res is OutingData:
		return res as OutingData
	if ResourceLoader.exists(ref_str):
		var loaded: Resource = ResourceLoader.load(ref_str)
		if loaded is OutingData:
			return loaded as OutingData
	# Fallback by known id
	if ref_str == "girls_day_out" or ref_str == "&\"girls_day_out\"":
		return load("res://data/outings/girls_day_out.tres") as OutingData
	if ref_str == "date_night" or ref_str == "&\"date_night\"":
		return load("res://data/outings/date_night.tres") as OutingData
	return null


func _get_current_minute() -> int:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and "now_minutes" in clock:
		return int(clock.get("now_minutes"))
	return 0
