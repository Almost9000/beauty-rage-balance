class_name AppBase
extends Control

signal notification_posted(title: String, body: String, app_id: StringName)

@export var app_id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D = null


func open() -> void:
	show()


func close() -> void:
	hide()


func handle_back() -> bool:
	return false


func post_notification(title: String, body: String) -> void:
	notification_posted.emit(title, body, app_id)


func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary) -> void:
	pass


func reset_state() -> void:
	pass
