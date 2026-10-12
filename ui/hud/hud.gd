class_name HUD
extends CanvasLayer

const PHASE_COLORS: Dictionary = {
	Enums.CyclePhase.MENSTRUAL: Color("#fb7185"),  # Rose
	Enums.CyclePhase.FOLLICULAR: Color("#34d399"), # Mint
	Enums.CyclePhase.OVULATORY: Color("#fbbf24"),  # Amber
	Enums.CyclePhase.LUTEAL: Color("#c084fc"),     # Amethyst
}

const PHASE_NAMES: Dictionary = {
	Enums.CyclePhase.MENSTRUAL: "Menstrual",
	Enums.CyclePhase.FOLLICULAR: "Follicular",
	Enums.CyclePhase.OVULATORY: "Ovulatory",
	Enums.CyclePhase.LUTEAL: "Luteal",
}

@onready var sanity_bar: StatBar = $RootControl/TopLeftContainer/PanelContainer/StatsVBox/SanityBar
@onready var health_bar: StatBar = $RootControl/TopLeftContainer/PanelContainer/StatsVBox/HealthBar
@onready var hygiene_bar: StatBar = $RootControl/TopLeftContainer/PanelContainer/StatsVBox/HygieneBar
@onready var rage_bar: StatBar = $RootControl/TopLeftContainer/PanelContainer/StatsVBox/RageBar

@onready var clock_label: Label = $RootControl/TopRightContainer/RightVBox/TimeMoneyPanel/HBox/ClockLabel
@onready var wallet_label: Label = $RootControl/TopRightContainer/RightVBox/TimeMoneyPanel/HBox/WalletLabel

@onready var phase_button: Button = $RootControl/TopRightContainer/RightVBox/PhaseContainer/PhaseButton
@onready var modifiers_panel: PanelContainer = $RootControl/TopRightContainer/RightVBox/PhaseContainer/ModifiersPanel
@onready var modifiers_title_label: Label = $RootControl/TopRightContainer/RightVBox/PhaseContainer/ModifiersPanel/VBox/ModifiersTitleLabel
@onready var modifiers_list: VBoxContainer = $RootControl/TopRightContainer/RightVBox/PhaseContainer/ModifiersPanel/VBox/ModifiersList
@onready var prep_checklist_ui: PrepChecklistUI = get_node_or_null("RootControl/TopRightContainer/RightVBox/PrepChecklistUI") as PrepChecklistUI
@onready var late_banner: PanelContainer = get_node_or_null("RootControl/LateBanner") as PanelContainer

var _modifiers_expanded: bool = false

func _ready() -> void:
	sanity_bar.stat_type = Enums.Stat.SANITY
	health_bar.stat_type = Enums.Stat.HEALTH
	hygiene_bar.stat_type = Enums.Stat.HYGIENE
	rage_bar.stat_type = Enums.Stat.RAGE

	phase_button.pressed.connect(_on_phase_button_pressed)

	_connect_signals()

	_update_clock()
	_update_wallet()
	_update_all_stats(false)
	_update_phase_badge()
	_update_modifiers_list()
	_update_late_banner()

func _connect_signals() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("minute_ticked", _on_clock_minute_ticked):
			clock.connect("minute_ticked", _on_clock_minute_ticked)
		if not clock.is_connected("time_skipped", _on_clock_time_skipped):
			clock.connect("time_skipped", _on_clock_time_skipped)
		if not clock.is_connected("day_started", _on_clock_day_started):
			clock.connect("day_started", _on_clock_day_started)

	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm:
		if not sm.is_connected("stat_changed", _on_stat_changed):
			sm.connect("stat_changed", _on_stat_changed)
		if not sm.is_connected("modifiers_changed", _on_modifiers_changed):
			sm.connect("modifiers_changed", _on_modifiers_changed)

	var fm: Node = get_node_or_null("/root/FinanceManager")
	if fm:
		if not fm.is_connected("wallet_changed", _on_wallet_changed):
			fm.connect("wallet_changed", _on_wallet_changed)

	var cm: Node = get_node_or_null("/root/CycleManager")
	if cm:
		if not cm.is_connected("phase_changed", _on_phase_changed):
			cm.connect("phase_changed", _on_phase_changed)

	var om: Node = get_node_or_null("/root/OutingManager")
	if om:
		if not om.is_connected("departure_deadline_reached", _on_departure_deadline_reached):
			om.connect("departure_deadline_reached", _on_departure_deadline_reached)
		if not om.is_connected("outing_departed", _on_outing_ended):
			om.connect("outing_departed", _on_outing_ended)
		if not om.is_connected("outing_missed", _on_outing_ended):
			om.connect("outing_missed", _on_outing_ended)
		if not om.is_connected("prep_started", _on_prep_started):
			om.connect("prep_started", _on_prep_started)

func toggle_modifiers_expanded() -> void:
	set_modifiers_expanded(not _modifiers_expanded)

func set_modifiers_expanded(expanded: bool) -> void:
	_modifiers_expanded = expanded
	if modifiers_panel:
		modifiers_panel.visible = _modifiers_expanded
	_update_phase_badge()

func is_modifiers_expanded() -> bool:
	return _modifiers_expanded

func get_active_modifier_descriptions() -> Array[String]:
	var result: Array[String] = []
	if modifiers_list:
		for child: Node in modifiers_list.get_children():
			if child is Label and not child.is_queued_for_deletion():
				result.append((child as Label).text)
	return result

func get_stat_bar(stat: Enums.Stat) -> StatBar:
	match stat:
		Enums.Stat.SANITY:
			return sanity_bar
		Enums.Stat.HEALTH:
			return health_bar
		Enums.Stat.HYGIENE:
			return hygiene_bar
		Enums.Stat.RAGE:
			return rage_bar
	return null

func get_clock_text() -> String:
	return clock_label.text if clock_label else ""

func get_wallet_text() -> String:
	return wallet_label.text if wallet_label else ""

func get_phase_badge_text() -> String:
	return phase_button.text if phase_button else ""

func is_late_banner_visible() -> bool:
	return late_banner.visible if late_banner else false

func _update_late_banner() -> void:
	if not late_banner:
		return
	var om: Node = get_node_or_null("/root/OutingManager")
	if om and bool(om.call("is_prep_active")) and bool(om.call("is_late")):
		late_banner.visible = true
	else:
		late_banner.visible = false

func _on_departure_deadline_reached(_outing: OutingData = null) -> void:
	_update_late_banner()

func _on_outing_ended(_outing: OutingData = null, _arg2 = null, _arg3 = null) -> void:
	_update_late_banner()

func _on_prep_started(_outing: OutingData = null) -> void:
	_update_late_banner()

func _on_clock_minute_ticked(_minute: int) -> void:
	_update_clock()
	_update_late_banner()

func _on_clock_time_skipped(_from_minute: int, _to_minute: int) -> void:
	_update_clock()
	_update_late_banner()

func _on_clock_day_started(_day: int) -> void:
	_update_clock()

func _on_stat_changed(stat: Enums.Stat, new_value: float, _delta: float) -> void:
	var bar: StatBar = get_stat_bar(stat)
	if bar:
		var max_val: float = _get_stat_max(stat)
		bar.set_value(new_value, max_val, true)
		bar.set_effective_rate(_get_stat_effective_rate(stat))

func _on_modifiers_changed() -> void:
	_update_all_stat_trends()
	_update_modifiers_list()

func _on_wallet_changed(cents: int, _delta: int) -> void:
	_update_wallet(cents)

func _on_phase_changed(phase: Enums.CyclePhase, data: CyclePhaseData) -> void:
	_update_phase_badge(int(phase), data)
	_update_modifiers_list()

func _on_phase_button_pressed() -> void:
	toggle_modifiers_expanded()

func _update_clock() -> void:
	if not clock_label:
		return
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		var day: int = int(clock.get("day"))
		var time_str: String = str(clock.call("format_time"))
		clock_label.text = tr("Day %d · %s") % [day, time_str]
	else:
		clock_label.text = tr("Day 1 · 07:00")

func _update_wallet(cents: int = -999999999) -> void:
	if not wallet_label:
		return
	if cents == -999999999:
		var fm: Node = get_node_or_null("/root/FinanceManager")
		if fm:
			cents = int(fm.get("wallet_cents"))
		else:
			cents = 0

	wallet_label.text = Money.format(cents)
	if cents < 0:
		wallet_label.add_theme_color_override("font_color", Color("#f87171"))
	else:
		wallet_label.add_theme_color_override("font_color", Color("#fbbf24"))

func _update_all_stats(animate: bool = true) -> void:
	for stat: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
		var bar: StatBar = get_stat_bar(stat)
		if bar:
			var val: float = _get_stat_value(stat)
			var max_val: float = _get_stat_max(stat)
			bar.set_value(val, max_val, animate)
			bar.set_effective_rate(_get_stat_effective_rate(stat))

func _update_all_stat_trends() -> void:
	for stat: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
		var bar: StatBar = get_stat_bar(stat)
		if bar:
			bar.set_effective_rate(_get_stat_effective_rate(stat))

func _update_phase_badge(phase: int = -1, data: CyclePhaseData = null) -> void:
	if not phase_button:
		return

	var cm: Node = get_node_or_null("/root/CycleManager")
	var current_p: Enums.CyclePhase = Enums.CyclePhase.FOLLICULAR
	var current_d: CyclePhaseData = data

	if phase >= 0:
		current_p = phase as Enums.CyclePhase
	elif cm:
		current_p = cm.get("current_phase") as Enums.CyclePhase

	if current_d == null and cm:
		current_d = cm.get("current_data") as CyclePhaseData

	var phase_str: String = _get_phase_display_name(current_p, current_d)
	var chevron: String = "▲" if _modifiers_expanded else "▼"
	phase_button.text = "%s  %s" % [phase_str, chevron]

	var col: Color = PHASE_COLORS.get(current_p, Color("#34d399"))
	phase_button.add_theme_color_override("font_color", col)
	phase_button.add_theme_color_override("font_hover_color", col.lightened(0.2))
	phase_button.add_theme_color_override("font_pressed_color", col.darkened(0.2))

	if current_d and not current_d.description.is_empty():
		phase_button.tooltip_text = tr(current_d.description)
	else:
		phase_button.tooltip_text = tr("Click to toggle active modifiers")

func _get_phase_display_name(phase: Enums.CyclePhase, data: CyclePhaseData) -> String:
	if data and not data.display_name.is_empty():
		var localized: String = tr(data.display_name)
		if localized != data.display_name:
			return localized
	var default_name: String = PHASE_NAMES.get(phase, "Unknown")
	return tr(default_name)

func _update_modifiers_list() -> void:
	if not modifiers_list:
		return

	for child: Node in modifiers_list.get_children():
		modifiers_list.remove_child(child)
		child.queue_free()

	if modifiers_title_label:
		modifiers_title_label.text = tr("ACTIVE MODIFIERS")

	var sm: Node = get_node_or_null("/root/StatusManager")
	var mods: Array[StatModifier] = []
	if sm and sm.has_method("get_modifiers"):
		mods = sm.get_modifiers()

	if mods.is_empty():
		var none_label: Label = Label.new()
		none_label.text = tr("None")
		none_label.add_theme_color_override("font_color", Color("#9ca3af"))
		modifiers_list.add_child(none_label)
		return

	for mod: StatModifier in mods:
		if not mod:
			continue
		var mod_label: Label = Label.new()
		mod_label.text = mod.describe()
		if not mod.label.is_empty():
			mod_label.tooltip_text = tr(mod.label)
		modifiers_list.add_child(mod_label)

func _get_stat_value(stat: Enums.Stat) -> float:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("get_value"):
		return float(sm.call("get_value", stat))
	return 0.0

func _get_stat_max(stat: Enums.Stat) -> float:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("get_max"):
		return float(sm.call("get_max", stat))
	return 100.0

func _get_stat_effective_rate(stat: Enums.Stat) -> float:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("get_effective_rate"):
		return float(sm.call("get_effective_rate", stat))
	return 0.0
