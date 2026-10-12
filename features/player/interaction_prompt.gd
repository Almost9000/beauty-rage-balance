class_name InteractionPrompt
extends PanelContainer

@onready var key_badge: Label = $MarginContainer/HBoxContainer/KeyBadge
@onready var action_label: Label = $MarginContainer/HBoxContainer/ActionLabel

func _ready() -> void:
	visible = false

func show_prompt(text: String, key_name: String = "E") -> void:
	set_prompt(text, key_name)
	visible = true

func hide_prompt() -> void:
	visible = false

func set_prompt(text: String, key_name: String = "E") -> void:
	if key_badge:
		key_badge.text = "[%s]" % key_name
	if action_label:
		action_label.text = tr(text) if not text.is_empty() else tr("Interact")
