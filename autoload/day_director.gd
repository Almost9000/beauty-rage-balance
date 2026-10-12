extends Node

# DayDirector (Autoload Singleton #10)
#
# ADR-03 / ADR-11: Orchestrates the core daily beat cycle:
# WAKE -> FREE -> PREP -> OUTING -> EVENING -> NIGHT_SUMMARY -> SLEEP
# Manages morning snapshots, pressure events, pass-out times, night summary
# data aggregation, sleep bonuses, and autosaving.

signal beat_changed(new_beat: Beat)
signal day_started(day: int)
signal night_summary_ready(summary_data: Dictionary)
signal sleep_completed(is_passout: bool)

enum Beat {
	WAKE,
	FREE,
	PREP,
	OUTING,
	EVENING,
	NIGHT_SUMMARY,
	SLEEP,
}

var config: DayConfig = null
var current_beat: Beat = Beat.WAKE
var current_day: int = 1
var is_thrift_day: bool = false
var pressure_triggered_today: bool = false

# Daily snapshots and tracking
var morning_stats: Dictionary = {} # Stat (int) -> float
var morning_wallet_cents: int = 0
var clutter_cleaned_count: int = 0
var clutter_cleaned_weight: float = 0.0
var clutter_types_cleaned: Array[StringName] = []
var dog_walks_count: int = 0
var dog_feedings_count: int = 0
var dog_pets_count: int = 0
var narrative_choices_today: Array[Dictionary] = []
var outing_result_today: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config == null:
		config = DayConfig.load_default()

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("minute_ticked", _on_clock_minute_ticked):
			clock.connect("minute_ticked", _on_clock_minute_ticked)
		if not clock.is_connected("time_skipped", _on_clock_time_skipped):
			clock.connect("time_skipped", _on_clock_time_skipped)

	var om: Node = get_node_or_null("/root/OutingManager")
	if om:
		if not om.is_connected("prep_started", _on_outing_prep_started):
			om.connect("prep_started", _on_outing_prep_started)
		if not om.is_connected("outing_departed", _on_outing_departed):
			om.connect("outing_departed", _on_outing_departed)
		if not om.is_connected("outing_resolved", _on_outing_resolved):
			om.connect("outing_resolved", _on_outing_resolved)
		if not om.is_connected("outing_missed", _on_outing_missed):
			om.connect("outing_missed", _on_outing_missed)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus:
		if bus.has_signal("clutter_cleaned") and not bus.is_connected("clutter_cleaned", _on_clutter_cleaned):
			bus.connect("clutter_cleaned", _on_clutter_cleaned)

	var nm: Node = get_node_or_null("/root/NarrativeManager")
	if nm:
		if not nm.is_connected("event_finished", _on_narrative_event_finished):
			nm.connect("event_finished", _on_narrative_event_finished)

	reset_state()


func reset_state() -> void:
	if config == null:
		config = DayConfig.load_default()

	var clock: Node = get_node_or_null("/root/GameClock")
	current_day = clock.get_day() if (clock and clock.has_method("get_day")) else 1
	current_beat = Beat.WAKE
	is_thrift_day = (current_day % 2 == 0)
	pressure_triggered_today = false

	clutter_cleaned_count = 0
	clutter_cleaned_weight = 0.0
	clutter_types_cleaned.clear()
	dog_walks_count = 0
	dog_feedings_count = 0
	dog_pets_count = 0
	narrative_choices_today.clear()
	outing_result_today.clear()

	_snapshot_morning()
	set_beat(Beat.FREE)


func set_beat(new_beat: Beat) -> void:
	if current_beat == new_beat:
		return
	current_beat = new_beat
	beat_changed.emit(current_beat)


func advance_beat() -> void:
	match current_beat:
		Beat.WAKE:
			set_beat(Beat.FREE)
		Beat.FREE:
			var om: Node = get_node_or_null("/root/OutingManager")
			if om and om.get("active_outing") != null:
				set_beat(Beat.PREP)
			else:
				set_beat(Beat.EVENING)
		Beat.PREP:
			var om: Node = get_node_or_null("/root/OutingManager")
			if om and om.has_method("depart") and om.get("active_outing") != null:
				om.call("depart")
			else:
				set_beat(Beat.OUTING)
		Beat.OUTING:
			set_beat(Beat.EVENING)
		Beat.EVENING:
			trigger_night_summary()
		Beat.NIGHT_SUMMARY:
			proceed_to_sleep()
		Beat.SLEEP:
			set_beat(Beat.WAKE)


func start_day(day: int) -> void:
	current_day = day
	set_beat(Beat.WAKE)
	_snapshot_morning()
	day_started.emit(current_day)

	# Reset daily counters
	clutter_cleaned_count = 0
	clutter_cleaned_weight = 0.0
	clutter_types_cleaned.clear()
	dog_walks_count = 0
	dog_feedings_count = 0
	dog_pets_count = 0
	narrative_choices_today.clear()
	outing_result_today.clear()
	pressure_triggered_today = false

	# Schedule outing or notify thrift day on alternating days
	if current_day % 2 != 0:
		is_thrift_day = false
		_schedule_default_outing_if_none()
	else:
		is_thrift_day = true
		_notify_thrift_day()

	set_beat(Beat.FREE)


func can_sleep() -> bool:
	var clock: Node = get_node_or_null("/root/GameClock")
	if not clock or not config:
		return false
	var mod: int = int(clock.get("minute_of_day"))
	return mod >= config.bedtime_earliest_minute or mod < config.wake_minute


func trigger_night_summary(_actor: Node = null) -> Dictionary:
	set_beat(Beat.NIGHT_SUMMARY)
	var summary: Dictionary = get_night_summary_data()
	night_summary_ready.emit(summary)
	return summary


func proceed_to_sleep(_actor: Node = null) -> void:
	sleep(false)


func trigger_passout() -> void:
	if current_beat == Beat.SLEEP:
		return
	sleep(true)


func sleep(is_passout: bool = false) -> void:
	set_beat(Beat.SLEEP)

	var clock: Node = get_node_or_null("/root/GameClock")
	var sm: Node = get_node_or_null("/root/StatusManager")

	if is_passout:
		if sm and sm.has_method("add_modifier"):
			var p_mod := StatModifier.new()
			p_mod.stat = Enums.Stat.HEALTH
			p_mod.kind = Enums.ModifierKind.INSTANT
			p_mod.value = config.passout_health_penalty
			p_mod.source_id = &"passout"
			p_mod.label = "Exhaustion pass-out"
			sm.call("add_modifier", p_mod)

		if clock and clock.has_method("skip"):
			var current_mod: int = int(clock.get("minute_of_day"))
			var skip_min: int = 0
			if current_mod < config.passout_wake_minute:
				skip_min = config.passout_wake_minute - current_mod
			else:
				skip_min = (1440 - current_mod) + config.passout_wake_minute
			if skip_min > 0:
				clock.call("skip", skip_min)
	else:
		if sm and sm.has_method("add_modifier"):
			var h_mod := StatModifier.new()
			h_mod.stat = Enums.Stat.HEALTH
			h_mod.kind = Enums.ModifierKind.INSTANT
			h_mod.value = config.sleep_health_bonus
			h_mod.source_id = &"sleep"
			h_mod.label = "Sleep recovery"
			sm.call("add_modifier", h_mod)

			var s_mod := StatModifier.new()
			s_mod.stat = Enums.Stat.SANITY
			s_mod.kind = Enums.ModifierKind.INSTANT
			s_mod.value = config.sleep_sanity_bonus
			s_mod.source_id = &"sleep"
			s_mod.label = "Restful sleep"
			sm.call("add_modifier", s_mod)

		if clock and clock.has_method("skip"):
			var current_mod: int = int(clock.get("minute_of_day"))
			var skip_min: int = 0
			if current_mod < config.wake_minute:
				skip_min = config.wake_minute - current_mod
			else:
				skip_min = (1440 - current_mod) + config.wake_minute
			if skip_min > 0:
				clock.call("skip", skip_min)

	# Autosave after sleep
	var save_mgr: Node = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("save_game"):
		save_mgr.call("save_game")

	sleep_completed.emit(is_passout)

	var next_day: int = 2
	if clock and clock.has_method("get_day"):
		next_day = clock.call("get_day")
	start_day(next_day)


func get_night_summary_data() -> Dictionary:
	var sm: Node = get_node_or_null("/root/StatusManager")
	var fm: Node = get_node_or_null("/root/FinanceManager")
	var clock: Node = get_node_or_null("/root/GameClock")

	var day_num: int = current_day
	if clock and clock.has_method("get_day"):
		day_num = clock.call("get_day")

	# Financial summary
	var finance_data: Dictionary = {}
	if fm and fm.has_method("totals_for_day"):
		finance_data = fm.call("totals_for_day", day_num)
	else:
		finance_data = {
			"spent": 0, "earned": 0, "spent_cents": 0, "earned_cents": 0, "net_cents": 0
		}
	var current_wallet: int = fm.get("wallet_cents") if fm else 0
	finance_data["wallet_start_cents"] = morning_wallet_cents
	finance_data["wallet_end_cents"] = current_wallet
	finance_data["wallet_delta_cents"] = current_wallet - morning_wallet_cents

	# Stat deltas
	var stats_data: Dictionary = {}
	var stat_names: Dictionary = {
		Enums.Stat.SANITY: "Sanity",
		Enums.Stat.HEALTH: "Health",
		Enums.Stat.HYGIENE: "Hygiene",
		Enums.Stat.RAGE: "Rage",
	}
	for stat: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
		var key: String = stat_names[stat].to_lower()
		var current_val: float = sm.call("get_stat", stat) if sm else 0.0
		var morning_val: float = float(morning_stats.get(int(stat), current_val))
		stats_data[key] = {
			"name": stat_names[stat],
			"start": morning_val,
			"end": current_val,
			"delta": current_val - morning_val,
		}

	# Outing outcome
	var outing_info: Dictionary = outing_result_today.duplicate(true)
	if outing_info.is_empty():
		outing_info = {
			"id": "none",
			"name": "Thrift Store Day" if is_thrift_day else "No Outing",
			"result": -1,
			"result_name": "None",
			"score": 0.0,
		}
	else:
		var res_idx: int = int(outing_info.get("result", 0))
		if res_idx >= 0 and res_idx < Enums.OutingResult.size():
			outing_info["result_name"] = Enums.OutingResult.keys()[res_idx]

	# Dogs care
	var dog_summary: Dictionary = {
		"walks": dog_walks_count,
		"feedings": dog_feedings_count,
		"pets": dog_pets_count,
	}

	# Clutter cleaned
	var clutter_summary: Dictionary = {
		"count": clutter_cleaned_count,
		"weight": clutter_cleaned_weight,
		"types": clutter_types_cleaned.duplicate(),
	}

	return {
		"day": day_num,
		"finance": finance_data,
		"stats": stats_data,
		"outing": outing_info,
		"narrative": narrative_choices_today.duplicate(true),
		"clutter": clutter_summary,
		"dog_care": dog_summary,
		"is_thrift_day": is_thrift_day,
	}


# --- Event / Action Recording Helpers ---

func record_dog_walk() -> void:
	dog_walks_count += 1


func record_dog_feeding() -> void:
	dog_feedings_count += 1


func record_dog_pet() -> void:
	dog_pets_count += 1


# --- Internal Helpers ---

func _snapshot_morning() -> void:
	morning_stats.clear()
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("get_stat"):
		for s: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
			morning_stats[int(s)] = float(sm.call("get_stat", s))

	var fm: Node = get_node_or_null("/root/FinanceManager")
	if fm and "wallet_cents" in fm:
		morning_wallet_cents = int(fm.get("wallet_cents"))
	else:
		morning_wallet_cents = 0


func _schedule_default_outing_if_none() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	if not om:
		return
	if om.get("active_outing") != null:
		return
	var scheduled: Array = om.call("get_scheduled_outings") if om.has_method("get_scheduled_outings") else []
	if not scheduled.is_empty():
		return

	var outing_res: OutingData = load("res://data/outings/girls_day_out.tres") as OutingData
	if outing_res:
		var dep_min: int = (current_day - 1) * 1440 + config.default_outing_departure_minute
		om.call("schedule", outing_res, dep_min, "Chloe")


func _notify_thrift_day() -> void:
	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("post_notification"):
		phone.call("post_notification", "Thrift Day", "New inventory at the Thrift Store! Open 10:00-19:00.", &"calendar")


# --- Signal Listeners ---

func _on_clock_minute_ticked(now_minute: int) -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("is_skipping_time") and clock.is_skipping_time():
		return
	_check_minute(now_minute)


func _on_clock_time_skipped(_from_minute: int, _to_minute: int) -> void:
	pass


func _check_minute(now_minute: int) -> void:
	if current_beat == Beat.SLEEP:
		return

	var mod: int = now_minute % 1440

	# Pressure trigger
	if mod >= config.pressure_minute and not pressure_triggered_today:
		if current_beat == Beat.FREE or current_beat == Beat.WAKE:
			_trigger_daily_pressure()

	# Pass-out check
	if mod == config.passout_minute_of_day:
		trigger_passout()


func _trigger_daily_pressure() -> void:
	pressure_triggered_today = true
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("narrative_requested"):
		bus.emit_signal("narrative_requested", &"daily_pressure")


func _on_outing_prep_started(_outing: OutingData) -> void:
	set_beat(Beat.PREP)


func _on_outing_departed(_outing: OutingData) -> void:
	set_beat(Beat.OUTING)


func _on_outing_resolved(outing: OutingData, result: Enums.OutingResult, score: float) -> void:
	outing_result_today = {
		"id": str(outing.id),
		"name": outing.display_name,
		"result": int(result),
		"score": score,
	}
	set_beat(Beat.EVENING)


func _on_outing_missed(outing: OutingData) -> void:
	outing_result_today = {
		"id": str(outing.id),
		"name": outing.display_name,
		"result": int(Enums.OutingResult.FAIL),
		"score": 0.0,
	}
	set_beat(Beat.EVENING)


func _on_clutter_cleaned(clutter_type: StringName, weight: float) -> void:
	clutter_cleaned_count += 1
	clutter_cleaned_weight += weight
	if not clutter_types_cleaned.has(clutter_type):
		clutter_types_cleaned.append(clutter_type)


func _on_narrative_event_finished(event: NarrativeEvent, choice: NarrativeChoice) -> void:
	if event == null or choice == null:
		return
	narrative_choices_today.append({
		"event_id": str(event.id),
		"speaker": event.speaker,
		"stance": int(choice.stance),
		"stance_name": Enums.Stance.keys()[choice.stance] if choice.stance < Enums.Stance.size() else "UNKNOWN",
		"text": choice.text,
	})


# --- Manager Contract Serialization ---

func to_dict() -> Dictionary:
	var m_stats: Dictionary = {}
	for k: Variant in morning_stats:
		m_stats[str(k)] = float(morning_stats[k])

	var cl_types: Array[String] = []
	for t: StringName in clutter_types_cleaned:
		cl_types.append(String(t))

	return {
		"current_beat": int(current_beat),
		"current_day": current_day,
		"is_thrift_day": is_thrift_day,
		"pressure_triggered_today": pressure_triggered_today,
		"morning_stats": m_stats,
		"morning_wallet_cents": morning_wallet_cents,
		"clutter_cleaned_count": clutter_cleaned_count,
		"clutter_cleaned_weight": clutter_cleaned_weight,
		"clutter_types_cleaned": cl_types,
		"dog_walks_count": dog_walks_count,
		"dog_feedings_count": dog_feedings_count,
		"dog_pets_count": dog_pets_count,
		"narrative_choices_today": narrative_choices_today.duplicate(true),
		"outing_result_today": outing_result_today.duplicate(true),
	}


func from_dict(data: Dictionary, _version: int = 1) -> void:
	current_beat = int(data.get("current_beat", Beat.WAKE)) as Beat
	current_day = int(data.get("current_day", 1))
	is_thrift_day = bool(data.get("is_thrift_day", false))
	pressure_triggered_today = bool(data.get("pressure_triggered_today", false))

	morning_stats.clear()
	var m_stats: Variant = data.get("morning_stats", {})
	if m_stats is Dictionary:
		for k: Variant in (m_stats as Dictionary).keys():
			morning_stats[int(str(k))] = float((m_stats as Dictionary)[k])

	morning_wallet_cents = int(data.get("morning_wallet_cents", 0))
	clutter_cleaned_count = int(data.get("clutter_cleaned_count", 0))
	clutter_cleaned_weight = float(data.get("clutter_cleaned_weight", 0.0))

	clutter_types_cleaned.clear()
	var cl_types: Variant = data.get("clutter_types_cleaned", [])
	if cl_types is Array:
		for t: Variant in (cl_types as Array):
			clutter_types_cleaned.append(StringName(str(t)))

	dog_walks_count = int(data.get("dog_walks_count", 0))
	dog_feedings_count = int(data.get("dog_feedings_count", 0))
	dog_pets_count = int(data.get("dog_pets_count", 0))

	narrative_choices_today.clear()
	var narr: Variant = data.get("narrative_choices_today", [])
	if narr is Array:
		for item: Variant in (narr as Array):
			if item is Dictionary:
				var item_dict: Dictionary = (item as Dictionary).duplicate(true)
				if item_dict.has("stance"):
					item_dict["stance"] = int(item_dict["stance"])
				narrative_choices_today.append(item_dict)

	outing_result_today.clear()
	var out: Variant = data.get("outing_result_today", {})
	if out is Dictionary:
		var out_dict: Dictionary = (out as Dictionary).duplicate(true)
		if out_dict.has("result"):
			out_dict["result"] = int(out_dict["result"])
		if out_dict.has("score"):
			out_dict["score"] = float(out_dict["score"])
		outing_result_today = out_dict
