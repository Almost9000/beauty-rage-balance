class_name PlayerController
extends CharacterBody3D

signal input_locked_changed(locked: bool)

@export var move_speed: float = 4.0
@export var acceleration: float = 20.0
@export var deceleration: float = 25.0
@export var rotation_speed: float = 12.0
@export var gravity: float = 9.8

@onready var camera_rig: CameraRig = get_node_or_null("CameraRig") as CameraRig
@onready var interaction_probe: InteractionProbe = get_node_or_null("InteractionProbe") as InteractionProbe
@onready var avatar_mount: Node3D = get_node_or_null("AvatarMount") as Node3D

var target_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _lock_reasons: Dictionary = {}

func _ready() -> void:
	add_to_group(&"player")
	if not is_input_locked():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var move_direction := Vector3.ZERO

	if not is_input_locked():
		var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input_vec.length_squared() > 0.001:
			var cam_fwd := Vector3.FORWARD
			var cam_right := Vector3.RIGHT

			if camera_rig and camera_rig.has_method("get_horizontal_forward"):
				cam_fwd = camera_rig.get_horizontal_forward()
				cam_right = camera_rig.get_horizontal_right()
			else:
				var cam := get_viewport().get_camera_3d() if get_viewport() else null
				if cam:
					cam_fwd = -cam.global_transform.basis.z
					cam_fwd.y = 0.0
					if cam_fwd.length_squared() > 0.001:
						cam_fwd = cam_fwd.normalized()
					else:
						cam_fwd = Vector3.FORWARD

					cam_right = cam.global_transform.basis.x
					cam_right.y = 0.0
					if cam_right.length_squared() > 0.001:
						cam_right = cam_right.normalized()
					else:
						cam_right = Vector3.RIGHT

			move_direction = (cam_right * input_vec.x + cam_fwd * -input_vec.y).normalized()

	var target_vel := move_direction * move_speed
	var accel := acceleration if move_direction != Vector3.ZERO else deceleration

	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)

	move_and_slide()

	if move_direction.length_squared() > 0.001:
		var target_angle := atan2(-move_direction.x, -move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func lock_input(reason: StringName) -> void:
	var was_locked: bool = is_input_locked()
	_lock_reasons[reason] = int(_lock_reasons.get(reason, 0)) + 1
	var now_locked: bool = is_input_locked()
	if not was_locked and now_locked:
		input_locked_changed.emit(true)
		_update_mouse_mode()

func unlock_input(reason: StringName) -> void:
	if not _lock_reasons.has(reason):
		return
	var was_locked: bool = is_input_locked()
	var count: int = int(_lock_reasons[reason]) - 1
	if count <= 0:
		_lock_reasons.erase(reason)
	else:
		_lock_reasons[reason] = count
	var now_locked: bool = is_input_locked()
	if was_locked and not now_locked:
		input_locked_changed.emit(false)
		_update_mouse_mode()

func is_input_locked() -> bool:
	return not _lock_reasons.is_empty()

func has_lock_reason(reason: StringName) -> bool:
	return _lock_reasons.has(reason)

func get_lock_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	for r: StringName in _lock_reasons.keys():
		reasons.append(r)
	return reasons

func _update_mouse_mode() -> void:
	if is_input_locked():
		target_mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		target_mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
