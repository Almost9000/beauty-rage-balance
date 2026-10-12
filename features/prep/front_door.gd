class_name FrontDoor
extends Node3D

@export var fade_duration: float = 0.3
@export var walk_min: int = 20

@onready var interactable: Interactable = $Interactable
@onready var departure_summary: DepartureSummary = $DepartureSummary
@onready var fade_rect: ColorRect = get_node_or_null("FadeCanvas/FadeOverlay") as ColorRect

var _current_actor: Node = null
var _is_departing: bool = false
var _is_walking: bool = false


func _ready() -> void:
	if interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	if departure_summary:
		if not departure_summary.confirmed.is_connected(_on_departure_confirmed):
			departure_summary.confirmed.connect(_on_departure_confirmed)
		if not departure_summary.closed.is_connected(_on_summary_closed):
			departure_summary.closed.connect(_on_summary_closed)

	var om: Node = get_node_or_null("/root/OutingManager")
	if om:
		if not om.is_connected("prep_started", _on_prep_state_changed):
			om.connect("prep_started", _on_prep_state_changed)
		if not om.is_connected("outing_departed", _on_prep_state_changed):
			om.connect("outing_departed", _on_prep_state_changed)
		if not om.is_connected("outing_missed", _on_prep_state_changed):
			om.connect("outing_missed", _on_prep_state_changed)
		if not om.is_connected("departure_deadline_reached", _on_prep_state_changed):
			om.connect("departure_deadline_reached", _on_prep_state_changed)

	if fade_rect:
		fade_rect.color.a = 0.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	update_prompt()


func update_prompt() -> void:
	if not interactable:
		return
	var om: Node = get_node_or_null("/root/OutingManager")
	if om and bool(om.call("is_prep_active")):
		var outing: OutingData = om.get("active_outing") as OutingData
		var name_str: String = outing.display_name if outing != null else "Outing"
		interactable.prompt_text = "Leave for %s" % name_str
	else:
		var dogs: Array[Node] = get_tree().get_nodes_in_group(&"dogs") if is_inside_tree() else []
		if not dogs.is_empty():
			interactable.prompt_text = "Walk the dogs (%d min)" % walk_min
		else:
			interactable.prompt_text = "Nothing planned"


func _on_prep_state_changed(_arg = null, _arg2 = null, _arg3 = null) -> void:
	update_prompt()


func _on_interacted(actor: Node) -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	if om and bool(om.call("is_prep_active")):
		_current_actor = actor
		if departure_summary:
			departure_summary.open(actor)
	else:
		var dogs: Array[Node] = get_tree().get_nodes_in_group(&"dogs") if is_inside_tree() else []
		if not dogs.is_empty():
			start_walk_dogs(actor, walk_min)
		else:
			update_prompt()


func _on_summary_closed() -> void:
	if not _is_departing:
		_current_actor = null
	update_prompt()


func _on_departure_confirmed() -> void:
	start_departure(_current_actor)


func start_departure(actor: Node = null) -> void:
	if _is_departing:
		return
	_is_departing = true

	var act: Node = actor if actor != null else _current_actor
	if is_instance_valid(act) and act.has_method("lock_input"):
		act.lock_input(&"departure")

	# Screen fade out
	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var fade_out: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_out.tween_property(fade_rect, "color:a", 1.0, fade_duration)
		await fade_out.finished

	# Call OutingManager.depart()
	var om: Node = get_node_or_null("/root/OutingManager")
	if om and om.has_method("depart"):
		om.call("depart")

	# Return at spawn front_door
	_place_actor_at_spawn(act)

	# Screen fade in
	if fade_rect:
		var fade_in: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_in.tween_property(fade_rect, "color:a", 0.0, fade_duration)
		await fade_in.finished
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(act) and act.has_method("unlock_input"):
		act.unlock_input(&"departure")

	_is_departing = false
	_current_actor = null
	update_prompt()


func _place_actor_at_spawn(actor: Node) -> void:
	if not is_instance_valid(actor) or not (actor is Node3D):
		return
	var spawns: Array[Node] = get_tree().get_nodes_in_group(&"spawn_points")
	for sp: Node in spawns:
		if sp is Marker3D and sp.name == &"front_door":
			(actor as Node3D).global_transform = (sp as Marker3D).global_transform
			return


func walk_dogs(actor: Node = null, duration_min: int = -1) -> void:
	execute_walk(actor, duration_min)


func execute_walk(_actor: Node = null, duration_min: int = -1) -> void:
	var actual_duration: int = duration_min if duration_min > 0 else walk_min

	# 1. Skip clock
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("skip"):
		clock.call("skip", actual_duration)

	# 2. Reset dogs bladder to 0 and reduce energy
	var dogs: Array[Node] = get_tree().get_nodes_in_group(&"dogs") if is_inside_tree() else []
	for d: Node in dogs:
		if d is Dog and is_instance_valid(d):
			d.walk()
		elif "needs" in d and d.needs is Dictionary:
			d.needs["bladder"] = 0.0
			d.needs["energy"] = maxf(0.0, float(d.needs.get("energy", 100.0)) - 25.0)

	# 3. Modify player stats: Health +15, Hygiene -10
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("add_modifier"):
		var health_mod := StatModifier.new()
		health_mod.stat = Enums.Stat.HEALTH
		health_mod.kind = Enums.ModifierKind.INSTANT
		health_mod.value = 15.0
		health_mod.source_id = &"walk_dogs"
		health_mod.label = "Walked the dogs"
		sm.call("add_modifier", health_mod)

		var hygiene_mod := StatModifier.new()
		hygiene_mod.stat = Enums.Stat.HYGIENE
		hygiene_mod.kind = Enums.ModifierKind.INSTANT
		hygiene_mod.value = -10.0
		hygiene_mod.source_id = &"walk_dogs"
		hygiene_mod.label = "Sweat from dog walk"
		sm.call("add_modifier", hygiene_mod)


func start_walk_dogs(actor: Node = null, duration_min: int = -1) -> void:
	if _is_walking or _is_departing:
		return
	_is_walking = true

	var act: Node = actor if actor != null else _current_actor
	if is_instance_valid(act) and act.has_method("lock_input"):
		act.lock_input(&"dog_walk")

	# Screen fade out
	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var fade_out: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_out.tween_property(fade_rect, "color:a", 1.0, fade_duration)
		await fade_out.finished

	# Apply game action logic
	execute_walk(act, duration_min)

	# Return at spawn front_door
	_place_actor_at_spawn(act)

	# Screen fade in
	if fade_rect:
		var fade_in: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_in.tween_property(fade_rect, "color:a", 0.0, fade_duration)
		await fade_in.finished
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(act) and act.has_method("unlock_input"):
		act.unlock_input(&"dog_walk")

	_is_walking = false
	_current_actor = null
	update_prompt()


func is_walking() -> bool:
	return _is_walking
