class_name FrontDoor
extends Node3D

@export var fade_duration: float = 0.3

@onready var interactable: Interactable = $Interactable
@onready var departure_summary: DepartureSummary = $DepartureSummary
@onready var fade_rect: ColorRect = get_node_or_null("FadeCanvas/FadeOverlay") as ColorRect

var _current_actor: Node = null
var _is_departing: bool = false


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
