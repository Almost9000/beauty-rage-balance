class_name DatingApp
extends AppBase

@export var daily_deck_size: int = 5
@export var cost_per_red_flag: float = 5.0
@export var profile_resources: Array[DatingProfile] = []

var swiped_ids: Array[StringName] = []
var deck_profile_ids: Array[StringName] = []
var current_card_profile: DatingProfile = null

@onready var back_button: Button = $VBoxContainer/Header/BackButton
@onready var title_label: Label = $VBoxContainer/Header/TitleLabel
@onready var card_area: Control = $VBoxContainer/CardArea
@onready var swipe_card: SwipeCard = $VBoxContainer/CardArea/SwipeCard
@onready var empty_state_panel: PanelContainer = $VBoxContainer/CardArea/EmptyStatePanel
@onready var empty_state_label: Label = $VBoxContainer/CardArea/EmptyStatePanel/MarginContainer/VBoxContainer/EmptyLabel
@onready var pass_button: Button = $VBoxContainer/ActionBar/PassButton
@onready var like_button: Button = $VBoxContainer/ActionBar/LikeButton

var _all_profiles: Dictionary = {}  # id (StringName) -> DatingProfile
var _is_transitioning: bool = false


func _init() -> void:
	app_id = &"dating"
	display_name = "Cupid"
	var icon_path := "res://assets/textures/dating/cupid_icon.png"
	if ResourceLoader.exists(icon_path):
		icon = load(icon_path) as Texture2D


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

	if pass_button:
		pass_button.pressed.connect(func() -> void: swipe_left(false))
	if like_button:
		like_button.pressed.connect(func() -> void: swipe_right(false))

	if swipe_card:
		swipe_card.swiped_left.connect(_on_card_swiped_left)
		swipe_card.swiped_right.connect(_on_card_swiped_right)

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_signal("day_started"):
		if not clock.day_started.is_connected(_on_day_started):
			clock.day_started.connect(_on_day_started)

	_ensure_profiles_loaded()

	if deck_profile_ids.is_empty() and swiped_ids.is_empty():
		rebuild_daily_deck()
	else:
		_show_top_card()


func open() -> void:
	super.open()
	_show_top_card()


func handle_back() -> bool:
	return false


func _on_back_button_pressed() -> void:
	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("handle_back"):
		phone.call("handle_back")


func _on_day_started(_day: int) -> void:
	rebuild_daily_deck()


func set_profiles(profiles: Array[DatingProfile]) -> void:
	profile_resources = profiles
	_all_profiles.clear()
	for p: DatingProfile in profiles:
		if p != null and not p.id.is_empty():
			_all_profiles[p.id] = p


func get_all_profiles() -> Array[DatingProfile]:
	_ensure_profiles_loaded()
	var list: Array[DatingProfile] = []
	if not profile_resources.is_empty():
		for p: DatingProfile in profile_resources:
			if p != null:
				list.append(p)
		return list

	var keys: Array = _all_profiles.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(a) < str(b)
	)
	for k: Variant in keys:
		list.append(_all_profiles[k] as DatingProfile)
	return list


func _ensure_profiles_loaded() -> void:
	if not profile_resources.is_empty():
		_all_profiles.clear()
		for p: DatingProfile in profile_resources:
			if p != null and not p.id.is_empty():
				_all_profiles[p.id] = p
		return

	if not _all_profiles.is_empty():
		return

	var dir := DirAccess.open("res://data/dating_profiles/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path := "res://data/dating_profiles/".path_join(file_name)
				var res := ResourceLoader.load(full_path)
				if res is DatingProfile:
					var p := res as DatingProfile
					if not p.id.is_empty():
						_all_profiles[p.id] = p
			file_name = dir.get_next()
		dir.list_dir_end()


func _get_profile_by_id(id: StringName) -> DatingProfile:
	_ensure_profiles_loaded()
	return _all_profiles.get(id, null) as DatingProfile


func rebuild_daily_deck() -> void:
	deck_profile_ids.clear()
	var candidates: Array[DatingProfile] = get_all_profiles()
	for p: DatingProfile in candidates:
		if p != null and not swiped_ids.has(p.id):
			deck_profile_ids.append(p.id)
			if deck_profile_ids.size() >= daily_deck_size:
				break

	_show_top_card()


func _show_top_card() -> void:
	_is_transitioning = false

	if deck_profile_ids.is_empty():
		current_card_profile = null
		if swipe_card:
			swipe_card.visible = false
		if empty_state_panel:
			empty_state_panel.visible = true
		if pass_button:
			pass_button.disabled = true
		if like_button:
			like_button.disabled = true
		return

	var next_id: StringName = deck_profile_ids[0]
	var p: DatingProfile = _get_profile_by_id(next_id)
	current_card_profile = p

	if empty_state_panel:
		empty_state_panel.visible = false
	if swipe_card:
		swipe_card.visible = true
		swipe_card.set_profile(p)
		swipe_card.reset_card()

	if pass_button:
		pass_button.disabled = false
	if like_button:
		like_button.disabled = false


func swipe_left(immediate: bool = false) -> void:
	if _is_transitioning or swipe_card == null or not swipe_card.visible:
		return
	_is_transitioning = true
	if pass_button:
		pass_button.disabled = true
	if like_button:
		like_button.disabled = true
	swipe_card.swipe_left(immediate)


func swipe_right(immediate: bool = false) -> void:
	if _is_transitioning or swipe_card == null or not swipe_card.visible:
		return
	_is_transitioning = true
	if pass_button:
		pass_button.disabled = true
	if like_button:
		like_button.disabled = true
	swipe_card.swipe_right(immediate)


func _on_card_swiped_left(p: DatingProfile) -> void:
	if p == null:
		p = current_card_profile
	if p != null:
		if not swiped_ids.has(p.id):
			swiped_ids.append(p.id)
		if not deck_profile_ids.is_empty() and deck_profile_ids[0] == p.id:
			deck_profile_ids.remove_at(0)

	_show_top_card()


func _on_card_swiped_right(p: DatingProfile) -> void:
	if p == null:
		p = current_card_profile
	if p != null:
		if not swiped_ids.has(p.id):
			swiped_ids.append(p.id)
		if not deck_profile_ids.is_empty() and deck_profile_ids[0] == p.id:
			deck_profile_ids.remove_at(0)

		# 1. Sanity penalty for red flags
		if not p.red_flags.is_empty():
			var delta: float = -(cost_per_red_flag * float(p.red_flags.size()))
			var sm: Node = get_node_or_null("/root/StatusManager")
			if sm and sm.has_method("apply_instant_modifier"):
				sm.call("apply_instant_modifier", &"sanity", delta, &"dating")

		# 2. Match check
		var roll: float = randf()
		if roll <= p.match_chance:
			post_notification("It's a Match!", "You and %s liked each other." % p.display_name)

			var outing: OutingData = p.date_outing
			if outing == null and ResourceLoader.exists("res://data/outings/date_night.tres"):
				outing = load("res://data/outings/date_night.tres") as OutingData

			if outing != null:
				var dep_min: int = find_next_available_date_time(outing)
				var partner_ref: String = ResRef.to_ref(p)
				if partner_ref.is_empty():
					partner_ref = p.resource_path if not p.resource_path.is_empty() else str(p.id)

				var outing_mgr: Node = get_node_or_null("/root/OutingManager")
				if outing_mgr and outing_mgr.has_method("schedule"):
					outing_mgr.call("schedule", outing, dep_min, partner_ref)

	_show_top_card()


func find_next_available_date_time(outing: OutingData) -> int:
	var clock: Node = get_node_or_null("/root/GameClock")
	var current_min: int = int(clock.get("now_minutes")) if clock else 0
	var current_day: int = int(clock.get("day")) if clock else 1
	var outing_mgr: Node = get_node_or_null("/root/OutingManager")

	var prep_window: int = outing.prep_window_min if outing != null else 120
	var duration: int = outing.duration_min if outing != null else 180

	var scheduled: Array = outing_mgr.get_scheduled() if (outing_mgr and outing_mgr.has_method("get_scheduled")) else []
	var has_active: bool = outing_mgr.is_prep_active() if (outing_mgr and outing_mgr.has_method("is_prep_active")) else false
	var active_out: OutingData = outing_mgr.active_outing if has_active else null
	var act_dep: int = int(outing_mgr.active_departure_min) if has_active else -1

	# Search starting today up to 30 days ahead
	for d: int in range(current_day, current_day + 30):
		var dep: int = (d - 1) * 1440 + 1200  # 20:00 = 1200 min
		if dep <= current_min:
			continue

		var new_start: int = dep - prep_window
		var new_end: int = dep + duration

		var conflict: bool = false
		if has_active and active_out != null and act_dep > 0:
			var act_start: int = act_dep - active_out.prep_window_min
			var act_end: int = act_dep + active_out.duration_min
			if maxi(new_start, act_start) < mini(new_end, act_end):
				conflict = true

		if not conflict:
			for entry: Dictionary in scheduled:
				var ex_out: OutingData = entry.get("outing") as OutingData
				if ex_out == null:
					continue
				var ex_dep: int = int(entry.get("departure_min", 0))
				var ex_start: int = ex_dep - ex_out.prep_window_min
				var ex_end: int = ex_dep + ex_out.duration_min
				if maxi(new_start, ex_start) < mini(new_end, ex_end):
					conflict = true
					break

		if not conflict:
			return dep

	return -1


func reset_state() -> void:
	swiped_ids.clear()
	deck_profile_ids.clear()
	_is_transitioning = false
	_ensure_profiles_loaded()
	rebuild_daily_deck()


func to_dict() -> Dictionary:
	var swiped_str_list: Array[String] = []
	for id: StringName in swiped_ids:
		swiped_str_list.append(str(id))

	var deck_str_list: Array[String] = []
	for id: StringName in deck_profile_ids:
		deck_str_list.append(str(id))

	return {
		"swiped_ids": swiped_str_list,
		"deck_profile_ids": deck_str_list,
	}


func from_dict(data: Dictionary) -> void:
	swiped_ids.clear()
	deck_profile_ids.clear()

	if data.has("swiped_ids") and data["swiped_ids"] is Array:
		for item: Variant in (data["swiped_ids"] as Array):
			swiped_ids.append(StringName(str(item)))

	if data.has("deck_profile_ids") and data["deck_profile_ids"] is Array:
		for item: Variant in (data["deck_profile_ids"] as Array):
			deck_profile_ids.append(StringName(str(item)))

	_show_top_card()
