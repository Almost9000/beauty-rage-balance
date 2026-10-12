class_name BedStation
extends Node3D

@export var fade_duration: float = 0.4

@onready var interactable: Interactable = $Interactable
@onready var night_summary: NightSummary = get_node_or_null("NightSummary") as NightSummary
@onready var fade_rect: ColorRect = get_node_or_null("FadeCanvas/FadeOverlay") as ColorRect
@onready var notice_banner: Control = get_node_or_null("NoticeCanvas/NoticeBanner") as Control
@onready var notice_label: Label = get_node_or_null("NoticeCanvas/NoticeBanner/Label") as Label

var _current_actor: Node = null
var _is_sleeping: bool = false


func _ready() -> void:
	if interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_signal("minute_ticked"):
		if not clock.minute_ticked.is_connected(_on_minute_ticked):
			clock.minute_ticked.connect(_on_minute_ticked)

	if fade_rect:
		fade_rect.color.a = 0.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if notice_banner:
		notice_banner.visible = false

	update_prompt()


func _on_minute_ticked(_now: int) -> void:
	update_prompt()


func update_prompt() -> void:
	if not interactable:
		return
	var dd: Node = get_node_or_null("/root/DayDirector")
	var can_sleep_now: bool = dd != null and bool(dd.call("can_sleep"))
	if can_sleep_now:
		interactable.prompt_text = "Go to Sleep"
	else:
		interactable.prompt_text = "Bed (Too early to sleep — available 21:00)"


func show_notice(msg: String = "Too early to sleep (available after 21:00)") -> void:
	if notice_label:
		notice_label.text = msg
	if notice_banner:
		notice_banner.visible = true
		var t := create_tween()
		t.tween_interval(2.5)
		t.tween_callback(func():
			if notice_banner:
				notice_banner.visible = false
		)


func _on_interacted(actor: Node) -> void:
	var dd: Node = get_node_or_null("/root/DayDirector")
	var can_sleep_now: bool = dd != null and bool(dd.call("can_sleep"))

	if not can_sleep_now:
		show_notice("Too early to sleep (available after 21:00)")
		update_prompt()
		return

	_current_actor = actor
	var summary_data: Dictionary = {}
	if dd and dd.has_method("trigger_night_summary"):
		summary_data = dd.call("trigger_night_summary", actor)
	elif dd and dd.has_method("get_night_summary_data"):
		summary_data = dd.call("get_night_summary_data")

	if night_summary:
		night_summary.open(summary_data, actor)
	else:
		start_sleep_flow(actor)


func start_sleep_flow(actor: Node = null) -> void:
	if _is_sleeping:
		return
	_is_sleeping = true

	var act: Node = actor if actor != null else _current_actor
	if is_instance_valid(act) and act.has_method("lock_input"):
		act.lock_input(&"sleep")

	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var fade_out: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_out.tween_property(fade_rect, "color:a", 1.0, fade_duration)
		await fade_out.finished

	var dd: Node = get_node_or_null("/root/DayDirector")
	if dd and dd.has_method("proceed_to_sleep"):
		dd.call("proceed_to_sleep", act)
	elif dd and dd.has_method("sleep"):
		dd.call("sleep", false)

	if fade_rect:
		var fade_in: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade_in.tween_property(fade_rect, "color:a", 0.0, fade_duration)
		await fade_in.finished
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(act) and act.has_method("unlock_input"):
		act.unlock_input(&"sleep")

	_is_sleeping = false
	_current_actor = null
	update_prompt()
