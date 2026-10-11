extends Node

signal minute_ticked(now_minute: int)
signal hour_changed(hour: int)
signal day_started(day: int)
signal time_skipped(from_minute: int, to_minute: int)
signal skip_started(minutes: int)
signal skip_finished()
signal paused_changed(paused: bool)
signal countdown_finished(id: StringName, payload: Dictionary)

const MINUTES_PER_DAY: int = 1440

var now_minutes: int = 420
var time_scale: float = 1.0

var minute_of_day: int:
	get:
		return get_minute_of_day()

var hour: int:
	get:
		return get_hour()

var day: int:
	get:
		return get_day()

var is_skipping: bool:
	get:
		return is_skipping_time()

var _minute_accumulator: float = 0.0
var _pause_reasons: Dictionary = {}
var _countdowns: Dictionary = {}
var _is_skipping: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_state()

func _process(delta: float) -> void:
	advance_real_time(delta)

func advance_real_time(delta: float) -> void:
	if is_paused():
		return
	if delta <= 0.0:
		return

	var settings: GameSettings = GameSettings.current()
	var rate: float = settings.minutes_per_real_second * time_scale
	_minute_accumulator += delta * rate

	while _minute_accumulator >= 1.0:
		_minute_accumulator -= 1.0
		_step_minute()

func advance_minutes(n: int) -> void:
	if n <= 0:
		return
	for _i: int in range(n):
		_step_minute()

func skip(minutes: int) -> void:
	if minutes <= 0:
		return
	if _is_skipping:
		push_error("GameClock: Nested skip() call is rejected.")
		return

	_is_skipping = true
	skip_started.emit(minutes)

	var initial_hour: int = get_hour()
	var target_minute: int = now_minutes + minutes

	while now_minutes < target_minute:
		var next_midnight: int = ((now_minutes / MINUTES_PER_DAY) + 1) * MINUTES_PER_DAY
		var next_bound: int = mini(target_minute, next_midnight)

		var min_cd_deadline: int = -1
		for cid: StringName in _countdowns:
			var dl: int = int(_countdowns[cid]["deadline_min"])
			if dl > now_minutes and dl <= target_minute:
				if min_cd_deadline == -1 or dl < min_cd_deadline:
					min_cd_deadline = dl

		if min_cd_deadline != -1 and min_cd_deadline < next_bound:
			next_bound = min_cd_deadline

		var seg_from: int = now_minutes
		var seg_to: int = next_bound
		now_minutes = seg_to

		time_skipped.emit(seg_from, seg_to)

		if seg_to % MINUTES_PER_DAY == 0:
			var day_num: int = seg_to / MINUTES_PER_DAY + 1
			day_started.emit(day_num)

		_fire_due_countdowns()

	var final_hour: int = get_hour()
	if final_hour != initial_hour:
		hour_changed.emit(final_hour)

	_is_skipping = false
	skip_finished.emit()

func _step_minute() -> void:
	var prev_hour: int = get_hour()
	now_minutes += 1
	minute_ticked.emit(now_minutes)

	if now_minutes % MINUTES_PER_DAY == 0:
		var day_num: int = now_minutes / MINUTES_PER_DAY + 1
		day_started.emit(day_num)

	var curr_hour: int = get_hour()
	if curr_hour != prev_hour:
		hour_changed.emit(curr_hour)

	_fire_due_countdowns()

func _fire_due_countdowns() -> void:
	var due: Array[Dictionary] = []
	for cid: StringName in _countdowns:
		var entry: Dictionary = _countdowns[cid]
		var dl: int = int(entry["deadline_min"])
		if dl <= now_minutes:
			due.append({
				"id": cid,
				"deadline_min": dl,
				"payload": entry.get("payload", {})
			})

	if due.is_empty():
		return

	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = a["deadline_min"]
		var db: int = b["deadline_min"]
		if da != db:
			return da < db
		return str(a["id"]) < str(b["id"])
	)

	for item: Dictionary in due:
		var cid: StringName = item["id"]
		if _countdowns.has(cid):
			_countdowns.erase(cid)
			countdown_finished.emit(cid, item["payload"] as Dictionary)

func is_skipping_time() -> bool:
	return _is_skipping

func pause(reason: StringName) -> void:
	var was_paused: bool = is_paused()
	_pause_reasons[reason] = int(_pause_reasons.get(reason, 0)) + 1
	var now_paused: bool = is_paused()
	if not was_paused and now_paused:
		paused_changed.emit(true)

func resume(reason: StringName) -> void:
	if not _pause_reasons.has(reason):
		return
	var was_paused: bool = is_paused()
	var count: int = int(_pause_reasons[reason]) - 1
	if count <= 0:
		_pause_reasons.erase(reason)
	else:
		_pause_reasons[reason] = count
	var now_paused: bool = is_paused()
	if was_paused and not now_paused:
		paused_changed.emit(false)

func is_paused() -> bool:
	return not _pause_reasons.is_empty()

func has_pause_reason(reason: StringName) -> bool:
	return _pause_reasons.has(reason)

func get_pause_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	for r: Variant in _pause_reasons.keys():
		reasons.append(r as StringName)
	return reasons

func create_countdown(id: StringName, deadline_min: int, payload: Dictionary = {}) -> void:
	_countdowns[id] = {
		"deadline_min": deadline_min,
		"payload": payload.duplicate(true)
	}

func cancel_countdown(id: StringName) -> bool:
	return _countdowns.erase(id)

func has_countdown(id: StringName) -> bool:
	return _countdowns.has(id)

func remaining(id: StringName) -> int:
	if not _countdowns.has(id):
		return -1
	var deadline: int = int(_countdowns[id]["deadline_min"])
	return maxi(0, deadline - now_minutes)

func get_countdown(id: StringName) -> Dictionary:
	if not _countdowns.has(id):
		return {}
	return (_countdowns[id] as Dictionary).duplicate(true)

func format_time(mod: int = -1) -> String:
	var m: int = get_minute_of_day() if mod < 0 else (mod % MINUTES_PER_DAY)
	if m < 0:
		m += MINUTES_PER_DAY
	var h: int = m / 60
	var mins: int = m % 60
	return "%02d:%02d" % [h, mins]

func get_minute_of_day() -> int:
	return now_minutes % MINUTES_PER_DAY

func get_hour() -> int:
	return (now_minutes % MINUTES_PER_DAY) / 60

func get_day() -> int:
	return now_minutes / MINUTES_PER_DAY + 1

func reset_state() -> void:
	now_minutes = GameSettings.current().wake_minute_of_day
	_countdowns.clear()
	var was_paused: bool = is_paused()
	_pause_reasons.clear()
	if was_paused:
		paused_changed.emit(false)
	_minute_accumulator = 0.0
	_is_skipping = false
	time_scale = 1.0

func to_dict() -> Dictionary:
	var cds: Dictionary = {}
	for cid: StringName in _countdowns:
		var entry: Dictionary = _countdowns[cid]
		cds[str(cid)] = {
			"deadline_min": int(entry["deadline_min"]),
			"payload": (entry.get("payload", {}) as Dictionary).duplicate(true)
		}
	return {
		"now_minutes": now_minutes,
		"countdowns": cds
	}

func from_dict(data: Dictionary, _version: int = 1) -> void:
	now_minutes = int(data.get("now_minutes", GameSettings.current().wake_minute_of_day))
	_countdowns.clear()
	var cds: Variant = data.get("countdowns", {})
	if cds is Dictionary:
		for k: Variant in (cds as Dictionary).keys():
			var entry: Variant = (cds as Dictionary)[k]
			if entry is Dictionary:
				var payload_val: Variant = (entry as Dictionary).get("payload", {})
				var payload_dict: Dictionary = {}
				if payload_val is Dictionary:
					payload_dict = (payload_val as Dictionary).duplicate(true)
				_countdowns[StringName(str(k))] = {
					"deadline_min": int((entry as Dictionary).get("deadline_min", 0)),
					"payload": payload_dict
				}
	_minute_accumulator = 0.0
	_is_skipping = false
	var was_paused: bool = is_paused()
	_pause_reasons.clear()
	if was_paused:
		paused_changed.emit(false)
