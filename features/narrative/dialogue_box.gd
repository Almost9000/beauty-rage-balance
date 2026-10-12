class_name DialogueBox
extends CanvasLayer

const CHOICE_BUTTON_SCENE := preload("res://features/narrative/choice_button.tscn")

@onready var root_control: Control = $RootControl
@onready var channel_badge: Label = $RootControl/PanelCenter/MarginContainer/VBox/HeaderHBox/ChannelBadge
@onready var speaker_label: Label = $RootControl/PanelCenter/MarginContainer/VBox/HeaderHBox/SpeakerLabel
@onready var line_label: Label = $RootControl/PanelCenter/MarginContainer/VBox/LineLabel
@onready var footer_hbox: HBoxContainer = $RootControl/PanelCenter/MarginContainer/VBox/FooterHBox
@onready var page_label: Label = $RootControl/PanelCenter/MarginContainer/VBox/FooterHBox/PageLabel
@onready var next_button: Button = $RootControl/PanelCenter/MarginContainer/VBox/FooterHBox/NextButton
@onready var choices_container: VBoxContainer = $RootControl/PanelCenter/MarginContainer/VBox/ChoicesContainer

var current_event: NarrativeEvent = null
var current_line_index: int = 0


func _ready() -> void:
	visible = false
	if next_button and not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

	var nm: Node = get_node_or_null("/root/NarrativeManager")
	if nm:
		if not nm.is_connected("event_started", _on_event_started):
			nm.connect("event_started", _on_event_started)
		if not nm.is_connected("event_finished", _on_event_finished):
			nm.connect("event_finished", _on_event_finished)
		if nm.get("active_event") != null:
			_on_event_started(nm.get("active_event") as NarrativeEvent)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or current_event == null:
		return

	if next_button and next_button.visible:
		if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
			_on_next_pressed()
			get_viewport().set_input_as_handled()


func _on_event_started(event: NarrativeEvent) -> void:
	if event == null:
		return

	current_event = event
	current_line_index = 0
	visible = true

	if speaker_label:
		speaker_label.text = event.speaker

	if channel_badge:
		var is_phone: bool = event.channel == &"PHONE_CALL"
		channel_badge.text = "[ PHONE CALL ]" if is_phone else "[ IN PERSON ]"
		if is_phone:
			channel_badge.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
		else:
			channel_badge.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))

	_clear_choices()
	_update_line_display()


func _update_line_display() -> void:
	if current_event == null or current_event.lines.is_empty():
		return

	if line_label:
		line_label.text = tr(current_event.lines[current_line_index])

	var total_lines: int = current_event.lines.size()
	if page_label:
		page_label.text = "%d / %d" % [current_line_index + 1, total_lines]

	if current_line_index < total_lines - 1:
		if footer_hbox:
			footer_hbox.visible = true
		if next_button:
			next_button.visible = true
			next_button.grab_focus()
		if choices_container:
			choices_container.visible = false
	else:
		if next_button:
			next_button.visible = false
		if total_lines <= 1 and footer_hbox:
			footer_hbox.visible = false
		if choices_container:
			choices_container.visible = true
		_populate_choices()


func _populate_choices() -> void:
	_clear_choices()
	if current_event == null or choices_container == null:
		return

	for i: int in range(current_event.choices.size()):
		var choice: NarrativeChoice = current_event.choices[i]
		if choice == null:
			continue
		var btn: ChoiceButton = CHOICE_BUTTON_SCENE.instantiate() as ChoiceButton
		choices_container.add_child(btn)
		btn.setup(choice, i)

	if choices_container.get_child_count() > 0:
		var first_btn: Control = choices_container.get_child(0) as Control
		if first_btn:
			first_btn.grab_focus()


func _clear_choices() -> void:
	if choices_container:
		for child: Node in choices_container.get_children():
			child.queue_free()


func _on_next_pressed() -> void:
	if current_event and current_line_index < current_event.lines.size() - 1:
		current_line_index += 1
		_update_line_display()


func _on_event_finished(_event: NarrativeEvent, _choice: NarrativeChoice) -> void:
	var nm: Node = get_node_or_null("/root/NarrativeManager")
	# If NarrativeManager triggered a follow_up event, active_event is already set
	if nm and nm.get("active_event") != null:
		return

	visible = false
	current_event = null
	_clear_choices()
