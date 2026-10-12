extends GutTest

var vanity_scene: PackedScene
var player_scene: PackedScene


func before_each() -> void:
	vanity_scene = load("res://features/makeup/vanity_station.tscn") as PackedScene
	player_scene = load("res://features/player/player.tscn") as PackedScene


func test_vanity_scene_structure() -> void:
	var vanity: VanityStation = vanity_scene.instantiate() as VanityStation
	add_child_autoqfree(vanity)

	assert_not_null(vanity.interactable, "Interactable exists")
	assert_not_null(vanity.camera_marker, "CameraMarker exists")
	assert_not_null(vanity.makeup_minigame, "MakeupMinigame exists")
	assert_eq(vanity.interactable.collision_layer, 4, "Interactable on layer 3 (mask 4)")
	assert_eq(vanity.interactable.prompt_text, "Use Vanity", "Prompt text matches")


func test_vanity_open_and_close_locks_and_unlocks_input() -> void:
	var vanity: VanityStation = vanity_scene.instantiate() as VanityStation
	var player: PlayerController = player_scene.instantiate() as PlayerController
	add_child_autoqfree(vanity)
	add_child_autoqfree(player)

	assert_false(player.is_input_locked(), "Player not locked initially")
	assert_false(vanity.is_vanity_open(), "Vanity closed initially")

	vanity.open_vanity(player)

	assert_true(vanity.is_vanity_open(), "Vanity is open")
	assert_true(player.is_input_locked(), "Player input locked while vanity open")
	assert_true(player.has_lock_reason(&"vanity"), "Lock reason is &\"vanity\"")

	var rig: CameraRig = player.camera_rig
	if rig:
		assert_true(rig.is_focused(), "CameraRig is focused on vanity camera marker")

	assert_true(vanity.makeup_minigame.is_open, "Makeup minigame UI is open")

	vanity.close_vanity()

	assert_false(vanity.is_vanity_open(), "Vanity is closed")
	assert_false(player.is_input_locked(), "Player input unlocked after vanity closed")
	assert_false(player.has_lock_reason(&"vanity"), "Lock reason cleared")
	if rig:
		assert_false(rig.is_focused(), "CameraRig focus released")
	assert_false(vanity.makeup_minigame.is_open, "Makeup minigame UI closed")


func test_vanity_close_via_ui_cancel() -> void:
	var vanity: VanityStation = vanity_scene.instantiate() as VanityStation
	var player: PlayerController = player_scene.instantiate() as PlayerController
	add_child_autoqfree(vanity)
	add_child_autoqfree(player)

	vanity.open_vanity(player)
	assert_true(vanity.is_vanity_open())
	assert_true(player.is_input_locked())

	# Trigger cancel via ui_cancel input action on minigame
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	vanity.makeup_minigame._unhandled_input(ev)

	assert_false(vanity.is_vanity_open(), "Vanity closed after ui_cancel")
	assert_false(player.is_input_locked(), "Player input unlocked after ui_cancel")
	assert_false(player.has_lock_reason(&"vanity"))
	if player.camera_rig:
		assert_false(player.camera_rig.is_focused())
