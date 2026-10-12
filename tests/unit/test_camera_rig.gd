extends GutTest

const CAMERA_RIG_SCENE_PATH := "res://features/player/camera_rig.tscn"

func test_camera_rig_scene_structure() -> void:
	var scene: PackedScene = load(CAMERA_RIG_SCENE_PATH)
	assert_not_null(scene, "camera_rig.tscn should load")

	var rig = scene.instantiate() as CameraRig
	add_child_autoqfree(rig)

	assert_not_null(rig.yaw_pivot, "YawPivot should exist")
	assert_not_null(rig.pitch_pivot, "PitchPivot should exist")
	assert_not_null(rig.spring_arm, "SpringArm3D should exist")
	assert_not_null(rig.camera, "Camera3D should exist")
	assert_eq(rig.spring_arm.collision_mask, 1, "Collision mask should be 1 (world)")

func test_camera_rig_focus_and_release() -> void:
	var rig: CameraRig = load(CAMERA_RIG_SCENE_PATH).instantiate()
	add_child_autoqfree(rig)

	var marker := Marker3D.new()
	marker.position = Vector3(5, 2, -5)
	add_child_autoqfree(marker)

	assert_false(rig.is_focused())
	assert_true(rig.orbit_enabled)

	# Focus instantly (blend_time = 0.0)
	rig.focus(marker, 0.0)
	assert_true(rig.is_focused())
	assert_false(rig.orbit_enabled)
	assert_almost_eq(rig.get_camera().global_position.x, 5.0, 0.05)
	assert_almost_eq(rig.get_camera().global_position.y, 2.0, 0.05)
	assert_almost_eq(rig.get_camera().global_position.z, -5.0, 0.05)

	# Release instantly
	rig.release(0.0)
	assert_false(rig.is_focused())
	assert_true(rig.orbit_enabled)
	assert_false(rig.get_camera().top_level)

func test_camera_rig_zoom_limits() -> void:
	var rig: CameraRig = load(CAMERA_RIG_SCENE_PATH).instantiate()
	add_child_autoqfree(rig)

	# Zoom in multiple times
	var zoom_in_event := InputEventAction.new()
	zoom_in_event.action = "cam_zoom_in"
	zoom_in_event.pressed = true

	for i in range(20):
		rig._unhandled_input(zoom_in_event)

	assert_almost_eq(rig._target_zoom, rig.min_zoom, 0.01, "Target zoom should clamp to min_zoom")

	# Zoom out multiple times
	var zoom_out_event := InputEventAction.new()
	zoom_out_event.action = "cam_zoom_out"
	zoom_out_event.pressed = true

	for i in range(20):
		rig._unhandled_input(zoom_out_event)

	assert_almost_eq(rig._target_zoom, rig.max_zoom, 0.01, "Target zoom should clamp to max_zoom")
