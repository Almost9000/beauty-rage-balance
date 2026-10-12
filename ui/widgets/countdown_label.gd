class_name CountdownLabel
extends Label

@export var countdown_id: StringName = &""
@export var prefix: String = ""
@export var suffix: String = ""
@export var default_text: String = "00:00"
@export var hide_when_empty: bool = false


func _ready() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("minute_ticked", _on_minute_ticked):
			clock.connect("minute_ticked", _on_minute_ticked)
		if not clock.is_connected("time_skipped", _on_time_skipped):
			clock.connect("time_skipped", _on_time_skipped)
	update_display()


func set_countdown_id(id: StringName) -> void:
	countdown_id = id
	update_display()


func update_display() -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	if countdown_id.is_empty() or clock == null:
		text = prefix + default_text + suffix
		if hide_when_empty:
			visible = false
		return

	if not bool(clock.call("has_countdown", countdown_id)):
		text = prefix + default_text + suffix
		if hide_when_empty:
			visible = false
		return

	if hide_when_empty:
		visible = true

	var rem: int = int(clock.call("remaining", countdown_id))
	if rem < 0:
		rem = 0

	var hours: int = rem / 60
	var mins: int = rem % 60
	text = "%s%02d:%02d%s" % [prefix, hours, mins, suffix]


func _on_minute_ticked(_now_minute: int) -> void:
	update_display()


func _on_time_skipped(_from_min: int, _to_min: int) -> void:
	update_display()
