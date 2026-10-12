class_name ComfortScore
extends Node

@export var tolerance: float = 8.0
@export var tidy_rate: float = 1.0
@export var messy_rate: float = -2.0

var current_comfort: float = 1.0
var _last_weight: float = -1.0
var _last_count: int = -1

static func compute_comfort(total_weight: float, tol: float) -> float:
	if tol <= 0.0:
		return 0.0
	return clampf(1.0 - (total_weight / tol), 0.0, 1.0)

static func compute_rate(comfort: float, messy: float = -2.0, tidy: float = 1.0) -> float:
	return lerp(messy, tidy, clampf(comfort, 0.0, 1.0))

func _ready() -> void:
	if not is_in_group(&"comfort_score"):
		add_to_group(&"comfort_score")

	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_signal("level_changing"):
		if not router.level_changing.is_connected(_on_level_changing):
			router.level_changing.connect(_on_level_changing)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus and bus.has_signal("clutter_cleaned"):
		if not bus.clutter_cleaned.is_connected(_on_clutter_cleaned):
			bus.clutter_cleaned.connect(_on_clutter_cleaned)

	update_comfort()

func _exit_tree() -> void:
	remove_modifier()

func _process(_delta: float) -> void:
	var count: int = 0
	var w: float = 0.0
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"clutter"):
			if node is Clutter and not node.is_queued_for_deletion():
				count += 1
				w += (node as Clutter).weight

	if count != _last_count or not is_equal_approx(w, _last_weight):
		_last_count = count
		_last_weight = w
		update_comfort()

func get_total_clutter_weight() -> float:
	var total: float = 0.0
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"clutter"):
			if node is Clutter and not node.is_queued_for_deletion():
				total += (node as Clutter).weight
	return total

func calculate_comfort() -> float:
	return compute_comfort(get_total_clutter_weight(), tolerance)

func get_current_rate() -> float:
	return compute_rate(current_comfort, messy_rate, tidy_rate)

func update_comfort() -> float:
	current_comfort = calculate_comfort()
	_apply_modifier(current_comfort)
	return current_comfort

func _apply_modifier(comfort: float) -> void:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if not sm or not sm.has_method("add_modifier"):
		return

	var mod := StatModifier.new()
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.RATE_ADD
	mod.value = compute_rate(comfort, messy_rate, tidy_rate)
	mod.source_id = &"apartment_comfort"
	mod.duration_min = -1
	mod.label = "Apartment Tidiness"
	sm.call("add_modifier", mod)

func remove_modifier() -> void:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("remove_by_source"):
		sm.call("remove_by_source", &"apartment_comfort")

func _on_level_changing(_from_id: String, _to_id: String) -> void:
	remove_modifier()

func _on_clutter_cleaned(_clutter_type: StringName, _weight: float) -> void:
	call_deferred("update_comfort")
