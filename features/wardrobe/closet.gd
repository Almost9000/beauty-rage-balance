class_name Closet
extends Node3D

@export var camera_blend_time: float = 0.4

@onready var camera_marker: Marker3D = $CameraMarker
@onready var interactable: Interactable = $Interactable
@onready var wardrobe_ui: WardrobeUI = $WardrobeUI

var _current_actor: Node = null
var _is_open: bool = false


func _ready() -> void:
	if interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	if wardrobe_ui:
		if not wardrobe_ui.closed.is_connected(_on_wardrobe_ui_closed):
			wardrobe_ui.closed.connect(_on_wardrobe_ui_closed)


func _on_interacted(actor: Node) -> void:
	open_wardrobe(actor)


func open_wardrobe(actor: Node = null) -> void:
	if _is_open:
		return
	_is_open = true
	_current_actor = actor

	if is_instance_valid(_current_actor):
		if _current_actor.has_method("lock_input"):
			_current_actor.lock_input(&"wardrobe")

		# Turn actor to face towards the camera marker so the front is visible
		if _current_actor is Node3D and camera_marker:
			var look_pos: Vector3 = camera_marker.global_position
			look_pos.y = (_current_actor as Node3D).global_position.y
			if not (_current_actor as Node3D).global_position.is_equal_approx(look_pos):
				(_current_actor as Node3D).look_at(look_pos, Vector3.UP)

		var rig: CameraRig = _get_camera_rig(_current_actor)
		if rig and camera_marker:
			rig.focus(camera_marker, camera_blend_time)

	if wardrobe_ui:
		wardrobe_ui.open()


func close_wardrobe() -> void:
	if not _is_open:
		return
	_is_open = false

	if wardrobe_ui and wardrobe_ui.is_open:
		wardrobe_ui.close()
	else:
		_finish_closing()


func _on_wardrobe_ui_closed() -> void:
	_is_open = false
	_finish_closing()


func _finish_closing() -> void:
	if is_instance_valid(_current_actor):
		var rig: CameraRig = _get_camera_rig(_current_actor)
		if rig:
			rig.release(camera_blend_time)
		if _current_actor.has_method("unlock_input"):
			_current_actor.unlock_input(&"wardrobe")
	_current_actor = null


func _get_camera_rig(actor: Node) -> CameraRig:
	if actor == null:
		return null
	if "camera_rig" in actor and actor.camera_rig is CameraRig:
		return actor.camera_rig as CameraRig
	if actor.has_node("CameraRig") and actor.get_node("CameraRig") is CameraRig:
		return actor.get_node("CameraRig") as CameraRig
	return null


func is_wardrobe_open() -> bool:
	return _is_open
