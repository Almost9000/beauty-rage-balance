class_name NightSummary
extends CanvasLayer

signal sleep_pressed
signal closed

@onready var modal_center: Control = $ModalCenter
@onready var modal_panel: PanelContainer = $ModalCenter/PanelContainer
@onready var title_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/TitleLabel

# Content labels
@onready var finance_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/Scroll/ContentVBox/FinanceVBox/FinanceLabel
@onready var stats_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/Scroll/ContentVBox/StatsVBox/StatsLabel
@onready var outing_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/Scroll/ContentVBox/OutingVBox/OutingLabel
@onready var narrative_list: VBoxContainer = $ModalCenter/PanelContainer/MarginContainer/VBox/Scroll/ContentVBox/NarrativeVBox/NarrativeList
@onready var care_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/Scroll/ContentVBox/CareVBox/CareLabel

@onready var sleep_button: Button = $ModalCenter/PanelContainer/MarginContainer/VBox/ButtonHBox/SleepButton

var is_open: bool = false
var _actor: Node = null


func _ready() -> void:
	visible = false
	if modal_panel:
		modal_panel.visible = false
	if sleep_button and not sleep_button.pressed.is_connected(_on_sleep_pressed):
		sleep_button.pressed.connect(_on_sleep_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_accept") and not event.is_echo():
		_on_sleep_pressed()
		get_viewport().set_input_as_handled()


func open(summary_data: Dictionary, actor: Node = null) -> void:
	if is_open:
		return
	is_open = true
	_actor = actor

	if is_instance_valid(_actor) and _actor.has_method("lock_input"):
		_actor.lock_input(&"night_summary")

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("push_pause"):
		clock.push_pause(&"night_summary")

	populate(summary_data)
	visible = true
	if modal_panel:
		modal_panel.visible = true
	if sleep_button:
		sleep_button.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if modal_panel:
		modal_panel.visible = false

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("pop_pause"):
		clock.pop_pause(&"night_summary")

	if is_instance_valid(_actor) and _actor.has_method("unlock_input"):
		_actor.unlock_input(&"night_summary")
	_actor = null

	closed.emit()


func _on_sleep_pressed() -> void:
	var act: Node = _actor
	close()
	sleep_pressed.emit()

	var dd: Node = get_node_or_null("/root/DayDirector")
	if dd and dd.has_method("proceed_to_sleep"):
		dd.call("proceed_to_sleep", act)


func populate(data: Dictionary) -> void:
	var day_num: int = int(data.get("day", 1))
	if title_label:
		title_label.text = "Day %d Complete — Night Summary" % day_num

	# 1. Finances
	if finance_label:
		var fin: Dictionary = data.get("finance", {})
		var spent_cents: int = int(fin.get("spent_cents", fin.get("spent", 0)))
		var earned_cents: int = int(fin.get("earned_cents", fin.get("earned", 0)))
		var net_cents: int = int(fin.get("net_cents", earned_cents - spent_cents))
		var end_cents: int = int(fin.get("wallet_end_cents", 0))

		var sign_str: String = "+" if net_cents >= 0 else "-"
		finance_label.text = "Earned: %s  |  Spent: %s  |  Net: %s%s\nFinal Wallet Balance: %s" % [
			_format_cents(earned_cents),
			_format_cents(spent_cents),
			sign_str,
			_format_cents(absi(net_cents)),
			_format_cents(end_cents),
		]

	# 2. Status deltas
	if stats_label:
		var stats_dict: Dictionary = data.get("stats", {})
		var lines: PackedStringArray = []
		for key: String in ["sanity", "health", "hygiene", "rage"]:
			var info: Dictionary = stats_dict.get(key, {})
			var name_str: String = str(info.get("name", key.capitalize()))
			var start_val: float = float(info.get("start", 0.0))
			var end_val: float = float(info.get("end", 0.0))
			var delta_val: float = float(info.get("delta", end_val - start_val))
			var delta_sign: String = "+" if delta_val >= 0.0 else ""
			lines.append("%s: %.0f (%s%.0f)" % [name_str, end_val, delta_sign, delta_val])
		stats_label.text = "  •  ".join(lines)

	# 3. Outing outcome
	if outing_label:
		var out_dict: Dictionary = data.get("outing", {})
		var out_name: String = str(out_dict.get("name", "None"))
		var res_name: String = str(out_dict.get("result_name", "N/A"))
		var score_val: float = float(out_dict.get("score", 0.0))
		if out_name == "None" or out_name == "No Outing" or out_name == "Thrift Store Day":
			outing_label.text = "%s (No scheduled outing)" % out_name
		else:
			outing_label.text = "%s: %s (Score: %.0f%%)" % [out_name, res_name, score_val * 100.0]

	# 4. Narrative choices
	if narrative_list:
		for c: Node in narrative_list.get_children():
			c.queue_free()

		var choices: Array = data.get("narrative", [])
		if choices.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "No confrontations or major pressure events today."
			empty_lbl.modulate = Color(0.7, 0.7, 0.7, 0.9)
			narrative_list.add_child(empty_lbl)
		else:
			for item: Variant in choices:
				if item is Dictionary:
					var d: Dictionary = item as Dictionary
					var speaker: String = str(d.get("speaker", "Unknown"))
					var stance_str: String = str(d.get("stance_name", ""))
					var text_str: String = str(d.get("text", ""))

					var choice_lbl := Label.new()
					choice_lbl.text = "• %s — [%s]: \"%s\"" % [speaker, stance_str, text_str]
					match stance_str:
						"ASSERT":
							choice_lbl.modulate = Color(1.0, 0.45, 0.55, 1.0)
						"DEFLECT":
							choice_lbl.modulate = Color(0.95, 0.75, 0.35, 1.0)
						"PLACATE":
							choice_lbl.modulate = Color(0.45, 0.8, 0.8, 1.0)
					narrative_list.add_child(choice_lbl)

	# 5. Apartment & Pets Care
	if care_label:
		var clutter: Dictionary = data.get("clutter", {})
		var dogs: Dictionary = data.get("dog_care", {})
		var cl_count: int = int(clutter.get("count", 0))
		var cl_weight: float = float(clutter.get("weight", 0.0))

		var walks: int = int(dogs.get("walks", 0))
		var feeds: int = int(dogs.get("feedings", 0))
		var cuddles: int = int(dogs.get("pets", 0))

		care_label.text = "Clutter Cleaned: %d items (weight %.1f)\nDog Care: %d walks, %d meals served, %d cuddles with Maja & Čipa" % [
			cl_count, cl_weight, walks, feeds, cuddles
		]


func _format_cents(cents: int) -> String:
	return "€%.2f" % (float(cents) / 100.0)
