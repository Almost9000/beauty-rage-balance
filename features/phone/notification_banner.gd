class_name NotificationBanner
extends Control

signal notification_clicked(app_id: StringName)
signal notification_displayed(notification: Dictionary)
signal notification_dismissed(app_id: StringName)

@export var display_duration: float = 4.0

@onready var banner_card: PanelContainer = $BannerCard
@onready var title_label: Label = $BannerCard/MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $BannerCard/MarginContainer/HBoxContainer/VBoxContainer/BodyLabel
@onready var close_button: Button = $BannerCard/MarginContainer/HBoxContainer/CloseButton

var _queue: Array[Dictionary] = []
var _current_notification: Dictionary = {}
var _time_remaining: float = 0.0
var _is_showing: bool = false


func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if banner_card:
		banner_card.gui_input.connect(_on_card_gui_input)


func _process(delta: float) -> void:
	if not _is_showing:
		return
	if display_duration <= 0.0:
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		dismiss_current()


func queue_notification(title: String, body: String, app_id: StringName = &"") -> void:
	var entry: Dictionary = {
		"title": title,
		"body": body,
		"app_id": app_id,
	}
	_queue.append(entry)
	if not _is_showing:
		_show_next_notification()


func dismiss_current() -> void:
	if not _is_showing:
		return
	var dismissed_id: StringName = _current_notification.get("app_id", &"")
	notification_dismissed.emit(dismissed_id)
	_show_next_notification()


func clear_queue() -> void:
	_queue.clear()
	if _is_showing:
		dismiss_current()


func is_banner_visible() -> bool:
	return _is_showing and visible


func get_queue_count() -> int:
	return _queue.size()


func get_current_notification() -> Dictionary:
	return _current_notification.duplicate(true)


func _show_next_notification() -> void:
	if _queue.is_empty():
		_is_showing = false
		_current_notification.clear()
		visible = false
		return

	_current_notification = _queue.pop_front()
	_is_showing = true
	visible = true
	_time_remaining = display_duration

	if title_label:
		title_label.text = _current_notification.get("title", "")
	if body_label:
		body_label.text = _current_notification.get("body", "")

	notification_displayed.emit(_current_notification)


func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_banner_clicked()


func _on_banner_clicked() -> void:
	if not _is_showing:
		return
	var app_id: StringName = _current_notification.get("app_id", &"")
	notification_clicked.emit(app_id)
	dismiss_current()


func _on_close_button_pressed() -> void:
	dismiss_current()
