class_name DogBrain
extends StateMachine

var dog: Node = null


func _ready() -> void:
	super._ready()
	dog = get_parent()
	_connect_clock()


func _connect_clock() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if clock.has_signal("minute_ticked"):
			if not clock.minute_ticked.is_connected(_on_minute_ticked):
				clock.minute_ticked.connect(_on_minute_ticked)
		if clock.has_signal("time_skipped"):
			if not clock.time_skipped.is_connected(_on_time_skipped):
				clock.time_skipped.connect(_on_time_skipped)


func _on_minute_ticked(_now: int = 0) -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and bool(clock.get("is_skipping")):
		return
	_process_elapsed_minutes(1)


func _on_time_skipped(from_min: int, to_min: int) -> void:
	var diff: int = to_min - from_min
	if diff > 0:
		_process_elapsed_minutes(diff)


func _process_elapsed_minutes(minutes: int) -> void:
	if not is_instance_valid(dog):
		return
	if not dog.has_method("integrate_time"):
		return

	dog.integrate_time(minutes)
	_evaluate_urgencies()


func _evaluate_urgencies() -> void:
	if not is_instance_valid(dog) or not ("profile" in dog and dog.profile != null):
		return

	var needs: Dictionary = dog.needs if "needs" in dog else {}
	var profile: DogProfile = dog.profile
	var cur_name: StringName = current_state.name if current_state != null else &""

	# Don't interrupt Cuddle
	if cur_name == &"Cuddle":
		return

	var context: Dictionary = {
		"current_state": cur_name,
		"has_food": dog.is_food_available() if dog.has_method("is_food_available") else false,
	}

	var desired_state: StringName = evaluate_next_state(needs, profile, context)
	if desired_state != cur_name and (desired_state in [&"Request", &"Sleep", &"Eat"]):
		transition_to(desired_state)


# ---------------------------------------------------------
# Pure static decision & simulation functions
# ---------------------------------------------------------

static func evaluate_next_state(needs: Dictionary, profile: DogProfile, context: Dictionary = {}) -> StringName:
	if not profile:
		return &"Idle"

	# 1. Cuddle overrides all
	if bool(context.get("is_cuddling", false)):
		return &"Cuddle"

	var cur: StringName = context.get("current_state", &"")
	if cur == &"Cuddle" and not bool(context.get("cuddle_finished", false)):
		return &"Cuddle"

	# 2. In-progress states that require completion
	if cur == &"Sleep":
		var energy: float = float(needs.get("energy", 0.0))
		if energy < 95.0:
			return &"Sleep"

	if cur == &"Eat":
		var hunger: float = float(needs.get("hunger", 0.0))
		if hunger > 5.0 and bool(context.get("has_food", true)):
			return &"Eat"

	# 3. Low energy -> Sleep
	if float(needs.get("energy", 100.0)) <= profile.energy_threshold:
		return &"Sleep"

	# 4. Hungry -> Eat if food available, else Request
	if float(needs.get("hunger", 0.0)) >= profile.hunger_threshold:
		if bool(context.get("has_food", false)):
			return &"Eat"
		return &"Request"

	# 5. Full bladder -> Request
	if float(needs.get("bladder", 0.0)) >= profile.bladder_threshold:
		return &"Request"

	# 6. Low affection -> Request
	if float(needs.get("affection", 100.0)) <= profile.affection_threshold:
		return &"Request"

	# 7. Forced state or routine behaviors
	if context.has("force_state") and not str(context.get("force_state")).is_empty():
		return StringName(str(context.get("force_state")))

	if bool(context.get("follow_player", false)):
		return &"Follow"

	if bool(context.get("wander", false)):
		return &"Wander"

	if cur == &"Wander" or cur == &"Follow":
		return cur

	return &"Idle"


static func evaluate_request_reason(needs: Dictionary, profile: DogProfile) -> StringName:
	if not profile:
		return &""
	# Check urgent needs by priority: affection > hunger > bladder
	if float(needs.get("affection", 100.0)) <= profile.affection_threshold:
		return &"affection"
	if float(needs.get("hunger", 0.0)) >= profile.hunger_threshold:
		return &"hunger"
	if float(needs.get("bladder", 0.0)) >= profile.bladder_threshold:
		return &"bladder"
	return &""


static func simulate_needs(initial_needs: Dictionary, profile: DogProfile, elapsed_minutes: int) -> Dictionary:
	if not profile:
		return {"needs": initial_needs.duplicate(), "accidents": 0}

	var elapsed_hours: float = float(elapsed_minutes) / 60.0

	var hunger: float = clampf(float(initial_needs.get("hunger", 0.0)) + profile.hunger_decay_per_hour * elapsed_hours, 0.0, 100.0)
	var affection: float = clampf(float(initial_needs.get("affection", 100.0)) - profile.affection_decay_per_hour * elapsed_hours, 0.0, 100.0)
	var energy: float = clampf(float(initial_needs.get("energy", 100.0)) - profile.energy_decay_per_hour * elapsed_hours, 0.0, 100.0)

	var raw_bladder: float = float(initial_needs.get("bladder", 0.0)) + profile.bladder_decay_per_hour * elapsed_hours
	var accidents: int = int(floor(raw_bladder / 100.0))
	var final_bladder: float = fmod(raw_bladder, 100.0)

	return {
		"needs": {
			"hunger": hunger,
			"bladder": final_bladder,
			"affection": affection,
			"energy": energy,
		},
		"accidents": accidents,
	}
