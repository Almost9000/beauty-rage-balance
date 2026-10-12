class_name DepartureSummary
extends CanvasLayer

signal confirmed()
signal closed()

@onready var modal_center: Control = $ModalCenter
@onready var modal_panel: PanelContainer = $ModalCenter/PanelContainer
@onready var title_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/TitleLabel
@onready var checklist_container: VBoxContainer = $ModalCenter/PanelContainer/MarginContainer/VBox/ChecklistContainer
@onready var raw_score_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/DetailsVBox/RawScoreHBox/ValueLabel
@onready var lateness_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/DetailsVBox/LatenessHBox/ValueLabel
@onready var final_score_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/DetailsVBox/FinalScoreHBox/ValueLabel
@onready var outcome_badge: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/OutcomeContainer/OutcomeBadge
@onready var cost_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/ConsequencesVBox/CostLabel
@onready var duration_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/ConsequencesVBox/DurationLabel
@onready var affinity_label: Label = $ModalCenter/PanelContainer/MarginContainer/VBox/ConsequencesVBox/AffinityLabel
@onready var modifiers_list: VBoxContainer = $ModalCenter/PanelContainer/MarginContainer/VBox/ConsequencesVBox/ModifiersList
@onready var confirm_button: Button = $ModalCenter/PanelContainer/MarginContainer/VBox/ButtonHBox/ConfirmButton
@onready var cancel_button: Button = $ModalCenter/PanelContainer/MarginContainer/VBox/ButtonHBox/CancelButton

var is_open: bool = false
var _actor: Node = null


func _ready() -> void:
	visible = false
	if modal_panel:
		modal_panel.visible = false
	if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button and not cancel_button.pressed.is_connected(_on_cancel_pressed):
		cancel_button.pressed.connect(_on_cancel_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(actor: Node = null) -> void:
	if is_open:
		return
	is_open = true
	_actor = actor

	if is_instance_valid(_actor) and _actor.has_method("lock_input"):
		_actor.lock_input(&"departure_summary")

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("pause"):
		clock.call("pause", &"modal")

	populate()
	visible = true
	if modal_panel:
		modal_panel.visible = true
	if confirm_button:
		confirm_button.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("resume"):
		clock.call("resume", &"modal")

	if is_instance_valid(_actor) and _actor.has_method("unlock_input"):
		_actor.unlock_input(&"departure_summary")
	_actor = null

	visible = false
	if modal_panel:
		modal_panel.visible = false
	closed.emit()


func confirm() -> void:
	if not is_open:
		return
	confirmed.emit()
	close()


func populate() -> void:
	var om: Node = get_node_or_null("/root/OutingManager")
	if om == null or not bool(om.call("is_prep_active")):
		if title_label:
			title_label.text = "NO ACTIVE OUTING"
		if confirm_button:
			confirm_button.disabled = true
		return

	var outing: OutingData = om.get("active_outing") as OutingData
	if outing == null:
		return

	if confirm_button:
		confirm_button.disabled = false

	var eval_res: Dictionary = om.call("evaluate")

	if title_label:
		title_label.text = "%s - DEPARTURE EVALUATION" % outing.display_name.to_upper()

	# Populate check lines
	if checklist_container:
		for child: Node in checklist_container.get_children():
			checklist_container.remove_child(child)
			child.queue_free()

		var check_results: Array = eval_res.get("check_results", [])
		for raw_it: Variant in check_results:
			if not (raw_it is Dictionary):
				continue
			var it: Dictionary = raw_it as Dictionary
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			var passed: bool = bool(it.get("passed", false))
			var icon_label: Label = Label.new()
			icon_label.text = "[✓]" if passed else "[ ]"
			icon_label.add_theme_color_override("font_color", Color("#34d399") if passed else Color("#9ca3af"))
			row.add_child(icon_label)

			var lbl: Label = Label.new()
			lbl.text = str(it.get("label", ""))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_color_override("font_color", Color("#f3f4f6") if passed else Color("#9ca3af"))
			row.add_child(lbl)

			var score_lbl: Label = Label.new()
			var sc: float = float(it.get("score", 0.0))
			score_lbl.text = "%d%%" % int(round(sc * 100.0))
			score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			score_lbl.add_theme_color_override("font_color", Color("#34d399") if passed else Color("#fbbf24"))
			row.add_child(score_lbl)

			checklist_container.add_child(row)

	# Populate score details
	if raw_score_label:
		var raw_sc: float = float(eval_res.get("raw_score", 0.0))
		raw_score_label.text = "%d%%" % int(round(raw_sc * 100.0))

	var late_min: int = int(eval_res.get("lateness_min", 0))
	var penalty: float = float(eval_res.get("penalty", 0.0))
	if lateness_label:
		if late_min > 0:
			lateness_label.text = "+%d min (-%d%% penalty)" % [late_min, int(round(penalty * 100.0))]
			lateness_label.add_theme_color_override("font_color", Color("#f87171"))
		else:
			lateness_label.text = "On time (No penalty)"
			lateness_label.add_theme_color_override("font_color", Color("#34d399"))

	if final_score_label:
		var sc: float = float(eval_res.get("score", 0.0))
		final_score_label.text = "%d%%" % int(round(sc * 100.0))

	# Outcome badge
	var res_enum: Enums.OutingResult = eval_res.get("result", Enums.OutingResult.FAIL) as Enums.OutingResult
	if outcome_badge:
		match res_enum:
			Enums.OutingResult.PASS:
				outcome_badge.text = "OUTCOME: PASS"
				outcome_badge.add_theme_color_override("font_color", Color("#34d399"))
			Enums.OutingResult.PARTIAL:
				outcome_badge.text = "OUTCOME: PARTIAL"
				outcome_badge.add_theme_color_override("font_color", Color("#fbbf24"))
			Enums.OutingResult.FAIL:
				outcome_badge.text = "OUTCOME: FAIL"
				outcome_badge.add_theme_color_override("font_color", Color("#f87171"))

	# Rewards / Consequences
	if cost_label:
		cost_label.text = "Cover charge: %s" % Money.format(outing.cost_cents)
	if duration_label:
		var hrs: float = float(outing.duration_min) / 60.0
		duration_label.text = "Duration: %.1f hours" % hrs

	var partner: String = str(om.get("active_partner_ref"))
	var aff_delta: int = outing.get_affinity_delta(res_enum)
	if affinity_label:
		var prefix: String = "+" if aff_delta > 0 else ""
		var name_str: String = partner if not partner.is_empty() else "Partner"
		affinity_label.text = "Affinity with %s: %s%d" % [name_str, prefix, aff_delta]
		if aff_delta > 0:
			affinity_label.add_theme_color_override("font_color", Color("#34d399"))
		elif aff_delta < 0:
			affinity_label.add_theme_color_override("font_color", Color("#f87171"))
		else:
			affinity_label.add_theme_color_override("font_color", Color("#9ca3af"))

	if modifiers_list:
		for child: Node in modifiers_list.get_children():
			modifiers_list.remove_child(child)
			child.queue_free()

		var mods: Array[StatModifier] = outing.get_modifiers_for_result(res_enum)
		if mods.is_empty():
			var none_lbl: Label = Label.new()
			none_lbl.text = "None"
			none_lbl.add_theme_color_override("font_color", Color("#9ca3af"))
			modifiers_list.add_child(none_lbl)
		else:
			for mod: StatModifier in mods:
				if not mod:
					continue
				var mod_lbl: Label = Label.new()
				mod_lbl.text = mod.describe()
				modifiers_list.add_child(mod_lbl)


func _on_confirm_pressed() -> void:
	confirm()


func _on_cancel_pressed() -> void:
	close()
