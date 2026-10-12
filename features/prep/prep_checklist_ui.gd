class_name PrepChecklistUI
extends PanelContainer

@onready var title_label: Label = $VBox/TitleLabel
@onready var prefix_label: Label = get_node_or_null("VBox/CountdownHBox/PrefixLabel") as Label
@onready var countdown_label: CountdownLabel = $VBox/CountdownHBox/CountdownLabel
@onready var late_banner: Control = get_node_or_null("VBox/LateBanner") as Control
@onready var checklist_container: VBoxContainer = $VBox/ChecklistVBox


func _ready() -> void:
	_connect_signals()
	refresh()


func _connect_signals() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	if om:
		if not om.is_connected("prep_started", _on_prep_started):
			om.connect("prep_started", _on_prep_started)
		if not om.is_connected("departure_deadline_reached", _on_departure_deadline_reached):
			om.connect("departure_deadline_reached", _on_departure_deadline_reached)
		if not om.is_connected("outing_departed", _on_outing_ended):
			om.connect("outing_departed", _on_outing_ended)
		if not om.is_connected("outing_missed", _on_outing_ended):
			om.connect("outing_missed", _on_outing_ended)

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("minute_ticked", _on_minute_ticked):
			clock.connect("minute_ticked", _on_minute_ticked)
		if not clock.is_connected("time_skipped", _on_time_skipped):
			clock.connect("time_skipped", _on_time_skipped)

	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm:
		if not sm.is_connected("stat_changed", _on_stat_changed):
			sm.connect("stat_changed", _on_stat_changed)

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv:
		if not inv.is_connected("outfit_changed", _on_outfit_changed):
			inv.connect("outfit_changed", _on_outfit_changed)
		if not inv.is_connected("look_changed", _on_look_changed):
			inv.connect("look_changed", _on_look_changed)


func refresh() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	if om == null or not bool(om.call("is_prep_active")):
		visible = false
		return

	visible = true
	var active_out: OutingData = om.get("active_outing") as OutingData
	if active_out != null and title_label != null:
		title_label.text = active_out.display_name.to_upper() + " PREP"

	var is_late: bool = bool(om.call("is_late")) if om.has_method("is_late") else false
	if late_banner != null:
		late_banner.visible = is_late

	if is_late:
		if prefix_label:
			prefix_label.text = "Grace expires in:"
		if countdown_label != null:
			countdown_label.set_countdown_id(&"outing_late_grace_deadline")
			countdown_label.update_display()
	else:
		if prefix_label:
			prefix_label.text = "Departing in:"
		if countdown_label != null:
			countdown_label.set_countdown_id(&"outing_departure_deadline")
			countdown_label.update_display()

	if checklist_container == null:
		return

	for child: Node in checklist_container.get_children():
		checklist_container.remove_child(child)
		child.queue_free()

	var items: Array[Dictionary] = om.call("get_checklist")
	for item: Dictionary in items:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var is_passed: bool = bool(item.get("passed", false))

		var status_label: Label = Label.new()
		status_label.text = "[✓]" if is_passed else "[ ]"
		status_label.add_theme_color_override("font_color", Color("#34d399") if is_passed else Color("#9ca3af"))
		row.add_child(status_label)

		var lbl: Label = Label.new()
		lbl.text = str(item.get("label", ""))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color("#f3f4f6") if is_passed else Color("#9ca3af"))
		row.add_child(lbl)

		var score_label: Label = Label.new()
		var sc: float = float(item.get("score", 0.0))
		score_label.text = "%d%%" % int(round(sc * 100.0))
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.add_theme_color_override("font_color", Color("#34d399") if is_passed else Color("#fbbf24"))
		row.add_child(score_label)

		checklist_container.add_child(row)


func _on_prep_started(_outing: OutingData) -> void:
	refresh()


func _on_departure_deadline_reached(_outing: OutingData) -> void:
	refresh()


func _on_minute_ticked(_now_minute: int) -> void:
	if visible:
		refresh()


func _on_time_skipped(_from_min: int, _to_min: int) -> void:
	if visible:
		refresh()


func _on_stat_changed(_stat: Enums.Stat, _val: float, _delta: float) -> void:
	if visible:
		refresh()


func _on_outfit_changed(_slot: Enums.Slot, _item: ClothingItem) -> void:
	if visible:
		refresh()


func _on_look_changed(_look: MakeupLook) -> void:
	if visible:
		refresh()


func _on_outing_ended(_outing: OutingData = null) -> void:
	refresh()
