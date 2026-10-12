class_name NarrativeCondition
extends Resource

enum Kind {
	DAY_RANGE,
	PHASE_TAG,
	STAT_THRESHOLD,
	LOCATION,
	FLAG_REQUIRED,
	FLAG_FORBIDDEN,
}

@export var kind: Kind = Kind.DAY_RANGE

# Kind.DAY_RANGE
@export var min_day: int = 1
@export var max_day: int = 9999

# Kind.PHASE_TAG
@export var phase_tag: StringName = &""
@export var has_tag: bool = true

# Kind.STAT_THRESHOLD
@export var stat: Enums.Stat = Enums.Stat.SANITY
@export var min_value: float = 0.0
@export var max_value: float = 100.0

# Kind.LOCATION
@export var level_id: StringName = &""

# Kind.FLAG_REQUIRED / FLAG_FORBIDDEN
@export var flag_name: StringName = &""
@export var flag_min_value: int = 1


func evaluate(context: Dictionary = {}) -> bool:
	match kind:
		Kind.DAY_RANGE:
			var day: int = 1
			if context.has("day"):
				day = int(context["day"])
			else:
				var clock: Node = _get_singleton("GameClock")
				if clock:
					day = int(clock.get("day"))
			return day >= min_day and day <= max_day

		Kind.PHASE_TAG:
			var tag_present: bool = false
			if context.has("phase_tags"):
				var tags: Array = context["phase_tags"] as Array
				tag_present = tags.has(phase_tag)
			else:
				var cycle: Node = _get_singleton("CycleManager")
				if cycle and cycle.has_method("has_tag"):
					tag_present = cycle.has_tag(phase_tag)
			return tag_present == has_tag

		Kind.STAT_THRESHOLD:
			var val: float = 0.0
			if context.has("stats") and (context["stats"] as Dictionary).has(stat):
				val = float(context["stats"][stat])
			else:
				var sm: Node = _get_singleton("StatusManager")
				if sm and sm.has_method("get_value"):
					val = sm.get_value(stat)
			return val >= min_value and val <= max_value

		Kind.LOCATION:
			if level_id.is_empty():
				return true
			var loc: String = ""
			if context.has("level_id"):
				loc = str(context["level_id"])
			else:
				var router: Node = _get_singleton("SceneRouter")
				if router:
					loc = str(router.get("current_level_id"))
			return loc == String(level_id)

		Kind.FLAG_REQUIRED:
			var f_val: int = 0
			if context.has("flags") and (context["flags"] as Dictionary).has(flag_name):
				f_val = int(context["flags"][flag_name])
			else:
				var nm: Node = _get_singleton("NarrativeManager")
				if nm and nm.has_method("get_flag"):
					f_val = nm.get_flag(flag_name)
			return f_val >= flag_min_value

		Kind.FLAG_FORBIDDEN:
			var f_val: int = 0
			if context.has("flags") and (context["flags"] as Dictionary).has(flag_name):
				f_val = int(context["flags"][flag_name])
			else:
				var nm: Node = _get_singleton("NarrativeManager")
				if nm and nm.has_method("get_flag"):
					f_val = nm.get_flag(flag_name)
			return f_val <= 0

	return true


static func create_day_range(p_min: int, p_max: int = 9999) -> NarrativeCondition:
	var c := NarrativeCondition.new()
	c.kind = Kind.DAY_RANGE
	c.min_day = p_min
	c.max_day = p_max
	return c


static func create_phase_tag(p_tag: StringName, p_has: bool = true) -> NarrativeCondition:
	var c := NarrativeCondition.new()
	c.kind = Kind.PHASE_TAG
	c.phase_tag = p_tag
	c.has_tag = p_has
	return c


static func create_stat_threshold(p_stat: Enums.Stat, p_min: float, p_max: float = 100.0) -> NarrativeCondition:
	var c := NarrativeCondition.new()
	c.kind = Kind.STAT_THRESHOLD
	c.stat = p_stat
	c.min_value = p_min
	c.max_value = p_max
	return c


static func create_location(p_level_id: StringName) -> NarrativeCondition:
	var c := NarrativeCondition.new()
	c.kind = Kind.LOCATION
	c.level_id = p_level_id
	return c


static func create_flag_required(p_flag: StringName, p_min: int = 1) -> NarrativeCondition:
	var c := NarrativeCondition.new()
	c.kind = Kind.FLAG_REQUIRED
	c.flag_name = p_flag
	c.flag_min_value = p_min
	return c


static func create_flag_forbidden(p_flag: StringName) -> NarrativeCondition:
	var c := NarrativeCondition.new()
	c.kind = Kind.FLAG_FORBIDDEN
	c.flag_name = p_flag
	return c


func _get_singleton(name: String) -> Node:
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root:
		return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(name)
	return null
