class_name CalendarApp
extends AppBase

@onready var active_card: PanelContainer = $VBoxContainer/ScrollContainer/ContentVBox/ActiveCard
@onready var active_title_label: Label = $VBoxContainer/ScrollContainer/ContentVBox/ActiveCard/MarginContainer/VBoxContainer/ActiveTitleLabel
@onready var active_status_label: Label = $VBoxContainer/ScrollContainer/ContentVBox/ActiveCard/MarginContainer/VBoxContainer/ActiveStatusLabel
@onready var active_checklist_vbox: VBoxContainer = $VBoxContainer/ScrollContainer/ContentVBox/ActiveCard/MarginContainer/VBoxContainer/ChecklistVBox
@onready var scheduled_vbox: VBoxContainer = $VBoxContainer/ScrollContainer/ContentVBox/ScheduledSection/ScheduledListVBox
@onready var empty_label: Label = $VBoxContainer/ScrollContainer/ContentVBox/ScheduledSection/EmptyLabel
@onready var back_button: Button = $VBoxContainer/Header/BackButton


func _init() -> void:
	app_id = &"calendar"
	display_name = "Calendar"


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

	_connect_signals()
	refresh()


func _connect_signals() -> void:
	var outing_mgr: Node = get_node_or_null("/root/OutingManager")
	if outing_mgr:
		if outing_mgr.has_signal("prep_started") and not outing_mgr.is_connected("prep_started", _on_outing_changed):
			outing_mgr.connect("prep_started", _on_outing_changed)
		if outing_mgr.has_signal("outing_departed") and not outing_mgr.is_connected("outing_departed", _on_outing_changed):
			outing_mgr.connect("outing_departed", _on_outing_changed)
		if outing_mgr.has_signal("outing_resolved") and not outing_mgr.is_connected("outing_resolved", _on_outing_changed):
			outing_mgr.connect("outing_resolved", _on_outing_changed)
		if outing_mgr.has_signal("outing_missed") and not outing_mgr.is_connected("outing_missed", _on_outing_changed):
			outing_mgr.connect("outing_missed", _on_outing_changed)

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_signal("minute_ticked"):
		if not clock.is_connected("minute_ticked", _on_minute_ticked):
			clock.connect("minute_ticked", _on_minute_ticked)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("outing_scheduled"):
		if not eb.is_connected("outing_scheduled", _on_outing_scheduled):
			eb.connect("outing_scheduled", _on_outing_scheduled)


func _on_outing_changed(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	if is_visible_in_tree():
		refresh()


func _on_minute_ticked(_minute: int) -> void:
	if is_visible_in_tree():
		refresh()


func _on_outing_scheduled(_outing = null, _dep_min = null, _partner = null) -> void:
	if is_visible_in_tree():
		refresh()


func open() -> void:
	super.open()
	refresh()


func handle_back() -> bool:
	return false


func _on_back_button_pressed() -> void:
	# Inform Phone shell to navigate back
	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("handle_back"):
		phone.call("handle_back")


func refresh() -> void:
	_refresh_active_outing()
	_refresh_scheduled_outings()


func _refresh_active_outing() -> void:
	if not active_card:
		return

	var outing_mgr: Node = get_node_or_null("/root/OutingManager")
	if not outing_mgr or not outing_mgr.get("active_outing"):
		active_card.visible = false
		return

	active_card.visible = true
	var outing: OutingData = outing_mgr.get("active_outing") as OutingData
	var dep_min: int = int(outing_mgr.get("active_departure_min"))
	var partner: String = str(outing_mgr.get("active_partner_ref"))

	var clock: Node = get_node_or_null("/root/GameClock")
	var dep_time_str: String = ""
	if clock and clock.has_method("format_time"):
		dep_time_str = str(clock.call("format_time", dep_min))
	else:
		dep_time_str = "%02d:%02d" % [dep_min / 60, dep_min % 60]

	var title_text: String = outing.display_name
	if not partner.is_empty():
		title_text += " with %s" % partner
	active_title_label.text = title_text

	var is_late: bool = bool(outing_mgr.call("is_late")) if outing_mgr.has_method("is_late") else false
	if is_late:
		var lateness: int = int(outing_mgr.call("get_lateness_min")) if outing_mgr.has_method("get_lateness_min") else 0
		var penalty: float = float(outing_mgr.call("calculate_penalty")) if outing_mgr.has_method("calculate_penalty") else 0.0
		active_status_label.text = "LATE (+%d min, -%.0f%% penalty) | Leaves: %s" % [lateness, penalty * 100.0, dep_time_str]
		active_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		active_status_label.text = "PREPARING | Departure: %s" % dep_time_str
		active_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))

	# Populate checklist
	if active_checklist_vbox:
		for child: Node in active_checklist_vbox.get_children():
			active_checklist_vbox.remove_child(child)
			child.queue_free()

		if outing_mgr.has_method("get_checklist"):
			var items: Array = outing_mgr.call("get_checklist") as Array
			for item: Dictionary in items:
				var lbl := Label.new()
				var passed: bool = bool(item.get("passed", false))
				var prefix: String = "[✓] " if passed else "[✗] "
				lbl.text = prefix + str(item.get("label", ""))
				var col: Color = Color(0.4, 0.9, 0.6) if passed else Color(0.9, 0.5, 0.5)
				lbl.add_theme_color_override("font_color", col)
				lbl.add_theme_font_size_override("font_size", 12)
				active_checklist_vbox.add_child(lbl)


func _refresh_scheduled_outings() -> void:
	if not scheduled_vbox or not empty_label:
		return

	for child: Node in scheduled_vbox.get_children():
		scheduled_vbox.remove_child(child)
		child.queue_free()

	var outing_mgr: Node = get_node_or_null("/root/OutingManager")
	var scheduled: Array = []
	if outing_mgr and outing_mgr.has_method("get_scheduled"):
		scheduled = outing_mgr.call("get_scheduled") as Array

	if scheduled.is_empty():
		empty_label.visible = true
		return

	empty_label.visible = false
	var clock: Node = get_node_or_null("/root/GameClock")

	for entry: Dictionary in scheduled:
		var outing: OutingData = entry.get("outing") as OutingData
		if outing == null:
			continue

		var dep_min: int = int(entry.get("departure_min", 0))
		var partner: String = str(entry.get("partner_ref", ""))
		var dep_str: String = ""
		if clock and clock.has_method("format_time"):
			dep_str = str(clock.call("format_time", dep_min))
		else:
			dep_str = "%02d:%02d" % [dep_min / 60, dep_min % 60]

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.16, 0.19, 0.28, 0.8)
		card_style.set_corner_radius_all(8)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.3, 0.36, 0.5, 0.6)
		card_style.content_margin_left = 10
		card_style.content_margin_top = 8
		card_style.content_margin_right = 10
		card_style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", card_style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)

		var header_hbox := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = outing.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
		header_hbox.add_child(name_lbl)

		var time_lbl := Label.new()
		time_lbl.text = dep_str
		time_lbl.add_theme_font_size_override("font_size", 13)
		time_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		header_hbox.add_child(time_lbl)
		vbox.add_child(header_hbox)

		var details_lbl := Label.new()
		var details: String = "%d min duration" % outing.duration_min
		if not partner.is_empty():
			details += " • with %s" % partner
		details_lbl.text = details
		details_lbl.add_theme_font_size_override("font_size", 11)
		details_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 0.8))
		vbox.add_child(details_lbl)

		card.add_child(vbox)
		scheduled_vbox.add_child(card)


func get_scheduled_count() -> int:
	var outing_mgr: Node = get_node_or_null("/root/OutingManager")
	if outing_mgr and outing_mgr.has_method("get_scheduled"):
		var list: Array = outing_mgr.call("get_scheduled") as Array
		return list.size()
	return 0
