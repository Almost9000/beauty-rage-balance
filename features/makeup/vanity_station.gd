class_name VanityStation
extends Node3D

@export var camera_blend_time: float = 0.5

@onready var camera_marker: Marker3D = $CameraMarker
@onready var interactable: Interactable = $Interactable
@onready var makeup_minigame: MakeupMinigame = $MakeupMinigame

var _current_actor: Node = null
var _is_open: bool = false


func _ready() -> void:
	if interactable:
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)
	if makeup_minigame:
		if not makeup_minigame.closed.is_connected(_on_minigame_closed):
			makeup_minigame.closed.connect(_on_minigame_closed)


func _on_interacted(actor: Node) -> void:
	open_vanity(actor)


func open_vanity(actor: Node = null) -> void:
	if _is_open:
		return
	_is_open = true
	_current_actor = actor

	if is_instance_valid(_current_actor):
		if _current_actor.has_method("lock_input"):
			_current_actor.lock_input(&"vanity")

		# Position actor at player marker if present
		if has_node("PlayerMarker"):
			var p_mark: Marker3D = get_node("PlayerMarker") as Marker3D
			if p_mark and _current_actor is Node3D:
				(_current_actor as Node3D).global_position = p_mark.global_position

		# Turn actor to face towards the camera marker so the front is visible
		if _current_actor is Node3D and camera_marker:
			var look_pos: Vector3 = camera_marker.global_position
			look_pos.y = (_current_actor as Node3D).global_position.y
			if not (_current_actor as Node3D).global_position.is_equal_approx(look_pos):
				(_current_actor as Node3D).look_at(look_pos, Vector3.UP)

		var rig: CameraRig = _get_camera_rig(_current_actor)
		if rig and camera_marker:
			rig.focus(camera_marker, camera_blend_time)

	if makeup_minigame:
		makeup_minigame.open(_current_actor)


func close_vanity() -> void:
	if not _is_open:
		return
	_is_open = false

	if makeup_minigame and makeup_minigame.is_open:
		makeup_minigame.close()
	else:
		_finish_closing()


func _on_minigame_closed() -> void:
	_is_open = false
	_finish_closing()


func _finish_closing() -> void:
	if is_instance_valid(_current_actor):
		var rig: CameraRig = _get_camera_rig(_current_actor)
		if rig:
			rig.release(camera_blend_time)
		if _current_actor.has_method("unlock_input"):
			_current_actor.unlock_input(&"vanity")
	_current_actor = null


func is_vanity_open() -> bool:
	return _is_open


func _get_camera_rig(actor: Node) -> CameraRig:
	if actor == null:
		return null
	if "camera_rig" in actor and actor.camera_rig is CameraRig:
		return actor.camera_rig as CameraRig
	if actor.has_node("CameraRig") and actor.get_node("CameraRig") is CameraRig:
		return actor.get_node("CameraRig") as CameraRig
	return null
