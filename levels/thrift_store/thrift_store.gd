class_name ThriftStore
extends LevelRoot

signal closing_warning_shown()
signal closing_eviction_triggered()

@export var pool_resource: ThriftPool
@export var travel_time_min: int = 20

@onready var exit_door_interactable: Interactable = get_node_or_null("ExitDoor/Interactable") as Interactable
@onready var closing_banner: Control = get_node_or_null("ClosingBannerCanvas/Banner") as Control
@onready var closing_banner_label: Label = get_node_or_null("ClosingBannerCanvas/Banner/Label") as Label

var shared_basket: Array[Dictionary] = []
var racks: Array[Array] = []
var rack_revealed_indices: Array[int] = [0, 0, 0]
var current_day: int = 1

var _closing_warning_issued: bool = false
var _is_evicting: bool = false
var _is_leaving: bool = false


func _ready() -> void:
	super._ready()
	if pool_resource == null:
		pool_resource = load("res://data/thrift_pools/default.tres") as ThriftPool

	_connect_router()
	_connect_clock()

	if exit_door_interactable:
		exit_door_interactable.prompt_text = "Return to Apartment (%d min)" % travel_time_min
		if not exit_door_interactable.interacted.is_connected(_on_exit_door_interacted):
			exit_door_interactable.interacted.connect(_on_exit_door_interacted)

	if closing_banner:
		closing_banner.visible = false

	_restore_or_init_state()
	_setup_features()
	check_closing_hours()


func _connect_router() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router:
		if router.has_signal("flush_level_state"):
			if not router.flush_level_state.is_connected(_on_flush_level_state):
				router.flush_level_state.connect(_on_flush_level_state)
		if router.has_signal("level_changing"):
			if not router.level_changing.is_connected(_on_level_changing):
				router.level_changing.connect(_on_level_changing)


func _connect_clock() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_signal("minute_ticked"):
		if not clock.minute_ticked.is_connected(_on_clock_minute_ticked):
			clock.minute_ticked.connect(_on_clock_minute_ticked)


func _restore_or_init_state() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	var today: int = 1
	if clock and "day" in clock:
		today = int(clock.day)
	current_day = today

	var router: Node = get_node_or_null("/root/SceneRouter")
	var state: Dictionary = {}
	if router and router.has_method("get_level_state"):
		state = router.call("get_level_state", "thrift_store")

	if not state.is_empty() and int(state.get("day", -1)) == today:
		_restore_from_state(state)
	else:
		if pool_resource != null:
			racks = pool_resource.generate_racks(today)
		rack_revealed_indices = [0, 0, 0]
		save_state()


func _restore_from_state(state: Dictionary) -> void:
	current_day = int(state.get("day", 1))

	var raw_indices: Variant = state.get("revealed_indices", [0, 0, 0])
	rack_revealed_indices = [0, 0, 0]
	if raw_indices is Array:
		for i: int in range(mini(3, (raw_indices as Array).size())):
			rack_revealed_indices[i] = int((raw_indices as Array)[i])

	var raw_racks: Variant = state.get("racks", [])
	racks.clear()
	if raw_racks is Array and not (raw_racks as Array).is_empty():
		for r_entry: Variant in (raw_racks as Array):
			var rack_list: Array = []
			if r_entry is Array:
				for itm_entry: Variant in (r_entry as Array):
					if itm_entry is Dictionary:
						var dict: Dictionary = itm_entry as Dictionary
						var ref: String = str(dict.get("item_ref", ""))
						var item: ClothingItem = null
						if not ref.is_empty():
							item = ResRef.load_ref(ref) as ClothingItem
						rack_list.append({
							"item": item,
							"price_cents": int(dict.get("price_cents", 0)),
							"item_ref": ref,
						})
			racks.append(rack_list)
	else:
		if pool_resource != null:
			racks = pool_resource.generate_racks(current_day)


func save_state() -> Dictionary:
	var state: Dictionary = {
		"day": current_day,
		"racks": _serialize_racks(),
		"revealed_indices": rack_revealed_indices.duplicate(),
	}

	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("store_level_state"):
		router.call("store_level_state", "thrift_store", state)

	return state


func _serialize_racks() -> Array:
	var serialized: Array = []
	for r: Array in racks:
		var rack_entries: Array = []
		for e: Variant in r:
			if e is Dictionary:
				var d: Dictionary = e as Dictionary
				var item: ClothingItem = d.get("item") as ClothingItem
				var ref: String = str(d.get("item_ref", ""))
				if ref.is_empty() and item != null:
					ref = ResRef.to_ref(item)
				rack_entries.append({
					"item_ref": ref,
					"price_cents": int(d.get("price_cents", 0)),
				})
		serialized.append(rack_entries)
	return serialized


func _setup_features() -> void:
	var rack_nodes: Array[Node] = []
	var racks_parent: Node = find_child("Racks", true, false)
	if racks_parent:
		rack_nodes = racks_parent.get_children()
	else:
		for c: Node in get_children():
			if c is ClothingRack:
				rack_nodes.append(c)

	for i: int in range(rack_nodes.size()):
		var rack: ClothingRack = rack_nodes[i] as ClothingRack
		if rack:
			var rack_items: Array = racks[i] if i < racks.size() else []
			var rev_idx: int = rack_revealed_indices[i] if i < rack_revealed_indices.size() else 0
			rack.setup(i, rack_items, rev_idx, shared_basket)
			if not rack.item_dug.is_connected(_on_rack_item_dug):
				rack.item_dug.connect(_on_rack_item_dug)

	var counter: CheckoutCounter = find_child("CheckoutCounter", true, false) as CheckoutCounter
	if counter:
		counter.set_basket(shared_basket)


func _on_rack_item_dug(rack_idx: int, new_idx: int, _item_data: Dictionary) -> void:
	if rack_idx >= 0 and rack_idx < rack_revealed_indices.size():
		rack_revealed_indices[rack_idx] = new_idx
	save_state()


func _on_exit_door_interacted(actor: Node) -> void:
	return_to_apartment(actor)


func return_to_apartment(actor: Node = null) -> void:
	if _is_leaving:
		return
	_is_leaving = true

	if is_instance_valid(actor) and actor.has_method("lock_input"):
		actor.lock_input(&"travel")

	save_state()

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("skip"):
		clock.call("skip", travel_time_min)

	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("change_level"):
		if is_inside_tree() and get_tree().current_scene == self:
			router.call("change_level", "res://levels/apartment/apartment.tscn", &"front_door")


func _on_clock_minute_ticked(_now_minutes: int) -> void:
	check_closing_hours()


func check_closing_hours() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock == null:
		return

	var tod: int = 0
	if "time_of_day_minutes" in clock:
		tod = int(clock.time_of_day_minutes)
	else:
		tod = int(clock.now_minutes) % 1440

	var close_min: int = pool_resource.close_minute if pool_resource != null else 1140
	var warn_min: int = close_min - 15

	if tod >= warn_min and tod < close_min:
		if not _closing_warning_issued:
			_closing_warning_issued = true
			show_closing_warning()
	elif tod >= close_min:
		trigger_closing_eviction()
	else:
		_closing_warning_issued = false
		hide_closing_warning()


func show_closing_warning() -> void:
	if closing_banner:
		closing_banner.visible = true
	if closing_banner_label:
		closing_banner_label.text = "Thrift store closing soon! (Closes at 19:00)"
	closing_warning_shown.emit()


func hide_closing_warning() -> void:
	if closing_banner:
		closing_banner.visible = false


func trigger_closing_eviction() -> void:
	if _is_evicting or _is_leaving:
		return
	_is_evicting = true
	closing_eviction_triggered.emit()

	shared_basket.clear()
	save_state()

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("skip"):
		clock.call("skip", travel_time_min)

	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("change_level"):
		if is_inside_tree() and get_tree().current_scene == self:
			router.call("change_level", "res://levels/apartment/apartment.tscn", &"front_door")


func _on_flush_level_state() -> void:
	save_state()


func _on_level_changing(from_id: String, _to_id: String) -> void:
	if from_id == "thrift_store" or from_id.is_empty():
		save_state()
