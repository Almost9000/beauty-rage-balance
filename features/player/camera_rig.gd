class_name CameraRig
extends Node3D

@export var target: Node3D
@export var follow_offset: Vector3 = Vector3(0.0, 1.4, 0.0)

@export var min_pitch: float = deg_to_rad(-70.0)
@export var max_pitch: float = deg_to_rad(45.0)
@export var mouse_sensitivity: float = 0.003
@export var gamepad_sensitivity: float = 2.5

@export var min_zoom: float = 1.5
@export var max_zoom: float = 6.0
@export var default_zoom: float = 3.5
@export var zoom_step: float = 0.5
@export var zoom_smoothness: float = 10.0

@export var orbit_enabled: bool = true

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D

var _target_zoom: float = 3.5
var _is_focused: bool = false
var _focus_target: Node3D = null
var _tween: Tween = null

func _ready() -> void:
	set_as_top_level(true)

	if not target and get_parent() is Node3D:
		target = get_parent() as Node3D

	if target:
		global_position = target.global_position + follow_offset

	_target_zoom = default_zoom
	if spring_arm:
		spring_arm.spring_length = default_zoom
		spring_arm.collision_mask = 1 # layer 1: world

func _process(delta: float) -> void:
	if target and not _is_focused:
		global_position = target.global_position + follow_offset

	if spring_arm and not _is_focused:
		spring_arm.spring_length = lerp(spring_arm.spring_length, _target_zoom, zoom_smoothness * delta)

	if not _is_orbit_allowed():
		return

	# Right-stick orbit
	var stick_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var stick_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var deadzone: float = 0.15
	if abs(stick_x) > deadzone or abs(stick_y) > deadzone:
		if yaw_pivot:
			yaw_pivot.rotate_y(-stick_x * gamepad_sensitivity * delta)
		if pitch_pivot:
			pitch_pivot.rotate_x(-stick_y * gamepad_sensitivity * delta)
			pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, min_pitch, max_pitch)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_orbit_allowed():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		if yaw_pivot:
			yaw_pivot.rotate_y(-motion.relative.x * mouse_sensitivity)
		if pitch_pivot:
			pitch_pivot.rotate_x(-motion.relative.y * mouse_sensitivity)
			pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, min_pitch, max_pitch)
	elif event.is_action_pressed("cam_zoom_in"):
		_target_zoom = clamp(_target_zoom - zoom_step, min_zoom, max_zoom)
	elif event.is_action_pressed("cam_zoom_out"):
		_target_zoom = clamp(_target_zoom + zoom_step, min_zoom, max_zoom)

func _is_orbit_allowed() -> bool:
	if not orbit_enabled or _is_focused:
		return false
	if target and target.has_method("is_input_locked") and bool(target.call("is_input_locked")):
		return false
	return true

func focus(focus_target: Node3D, blend_time: float = 0.4) -> void:
	if not focus_target or not camera:
		return

	_is_focused = true
	orbit_enabled = false
	_focus_target = focus_target

	var target_transform: Transform3D = focus_target.global_transform
	if focus_target.has_node("CameraMarker"):
		var marker: Node3D = focus_target.get_node("CameraMarker") as Node3D
		if marker:
			target_transform = marker.global_transform
	elif focus_target.has_node("camera"):
		var marker: Node3D = focus_target.get_node("camera") as Node3D
		if marker:
			target_transform = marker.global_transform
	elif target_transform.origin.y <= 0.2:
		target_transform.origin.y += 1.3

	if _tween:
		_tween.kill()

	if camera.get_parent() != self:
		camera.reparent(self)

	var start_transform: Transform3D = camera.global_transform

	if blend_time <= 0.0:
		camera.global_transform = target_transform
		return

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		camera.global_transform = start_transform.interpolate_with(target_transform, t)
	, 0.0, 1.0, blend_time)

func release(blend_time: float = 0.4) -> void:
	if not _is_focused and camera.get_parent() == spring_arm:
		return

	_is_focused = false
	_focus_target = null

	if _tween:
		_tween.kill()

	var start_transform: Transform3D = camera.global_transform

	if blend_time <= 0.0:
		if spring_arm and camera.get_parent() != spring_arm:
			camera.reparent(spring_arm)
			camera.transform = Transform3D.IDENTITY
		orbit_enabled = true
		return

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		var current_dest: Transform3D = spring_arm.global_transform if spring_arm else global_transform
		camera.global_transform = start_transform.interpolate_with(current_dest, t)
	, 0.0, 1.0, blend_time)
	_tween.tween_callback(func() -> void:
		if spring_arm and camera.get_parent() != spring_arm:
			camera.reparent(spring_arm)
			camera.transform = Transform3D.IDENTITY
		orbit_enabled = true
	)

func is_focused() -> bool:
	return _is_focused

func get_camera() -> Camera3D:
	return camera

func get_horizontal_forward() -> Vector3:
	if yaw_pivot:
		var fwd: Vector3 = -yaw_pivot.global_transform.basis.z
		fwd.y = 0.0
		return fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD
	return -global_transform.basis.z

func get_horizontal_right() -> Vector3:
	if yaw_pivot:
		var r: Vector3 = yaw_pivot.global_transform.basis.x
		r.y = 0.0
		return r.normalized() if r.length_squared() > 0.001 else Vector3.RIGHT
	return global_transform.basis.x
