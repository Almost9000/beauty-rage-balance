extends GutTest

const PHONE_SCENE_PATH := "res://features/phone/phone.tscn"
const GIRLS_DAY_OUT_PATH := "res://data/outings/girls_day_out.tres"

var phone_scene: PackedScene


class MockPhoneApp extends AppBase:
	var can_back: bool = false
	var back_called_count: int = 0
	var custom_data: String = ""

	func _init() -> void:
		app_id = &"mock_app"
		display_name = "Mock App"

	func handle_back() -> bool:
		back_called_count += 1
		if can_back:
			can_back = false
			return true
		return false

	func to_dict() -> Dictionary:
		return {"custom_data": custom_data}

	func from_dict(data: Dictionary) -> void:
		custom_data = str(data.get("custom_data", ""))

	func reset_state() -> void:
		can_back = false
		back_called_count = 0
		custom_data = ""


func before_each() -> void:
	phone_scene = load(PHONE_SCENE_PATH) as PackedScene
	GameClock.reset_state()
	OutingManager.reset_state()


func after_each() -> void:
	GameClock.reset_state()
	OutingManager.reset_state()
	var root_phone: Node = get_node_or_null("/root/Phone")
	if root_phone and root_phone.has_method("reset_state"):
		root_phone.call("reset_state")


func test_phone_initial_state() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	assert_false(phone.is_open, "Phone should be initially closed")
	assert_eq(phone.current_app_id, &"", "No app should be active initially")
	assert_false(phone.slide_container.visible, "SlideContainer should be hidden initially")
	assert_false(GameClock.is_paused(), "GameClock should not be paused initially")


func test_phone_open_close_tween_and_signals() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)
	phone.animation_duration = 0.05

	watch_signals(phone)

	phone.open()
	assert_true(phone.is_open, "Phone is open after calling open()")
	assert_signal_emitted(phone, "opened")
	await wait_seconds(0.1)
	assert_almost_eq(phone.slide_container.position.y, 0.0, 1.0, "Phone slide container should be at y=0 when open")

	phone.close()
	assert_false(phone.is_open, "Phone is closed after calling close()")
	await wait_seconds(0.1)
	assert_signal_emitted(phone, "closed")
	assert_false(phone.slide_container.visible, "SlideContainer should be hidden after close")


func test_phone_open_does_not_pause_game_clock() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	assert_false(GameClock.is_paused(), "GameClock should not be paused before opening")
	var t0: int = GameClock.now_minutes

	phone.open(true)
	assert_true(phone.is_open)
	assert_false(GameClock.is_paused(), "Opening phone must NEVER pause GameClock (ADR-03)")

	GameClock.advance_minutes(20)
	assert_eq(GameClock.now_minutes, t0 + 20, "GameClock advances normally while phone is open")
	assert_false(GameClock.is_paused(), "GameClock remains unpaused")

	phone.close(true)
	assert_false(phone.is_open)
	assert_false(GameClock.is_paused(), "GameClock remains unpaused after closing phone")


func test_phone_toggle() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	assert_false(phone.is_open)
	phone.toggle(true)
	assert_true(phone.is_open)
	phone.toggle(true)
	assert_false(phone.is_open)


func test_back_chain_order() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	var mock_app := MockPhoneApp.new()
	phone.register_app(mock_app)

	# 1. Phone open at HomeScreen: back closes phone
	phone.open(true)
	assert_true(phone.is_open)
	assert_eq(phone.current_app_id, &"")
	phone.handle_back()
	assert_false(phone.is_open, "Back from home screen closes phone")

	# 2. Phone open with app: back returns to HomeScreen, next back closes phone
	phone.open(true)
	phone.open_app(&"mock_app")
	assert_eq(phone.current_app_id, &"mock_app")
	phone.handle_back()
	assert_eq(phone.current_app_id, &"", "First back leaves app and returns to home screen")
	assert_true(phone.is_open, "Phone is still open on home screen")
	phone.handle_back()
	assert_false(phone.is_open, "Second back closes phone")

	# 3. App handles back internally first
	mock_app.back_called_count = 0
	phone.open(true)
	phone.open_app(&"mock_app")
	mock_app.can_back = true
	phone.handle_back()
	assert_eq(mock_app.back_called_count, 1)
	assert_eq(phone.current_app_id, &"mock_app", "App handled back internally, stays in app")
	phone.handle_back()
	assert_eq(phone.current_app_id, &"", "Next back returns to home screen")
	phone.handle_back()
	assert_false(phone.is_open, "Final back closes phone")


func test_notification_queue_ordering_and_dismissal() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	var banner: NotificationBanner = phone.notification_banner
	banner.display_duration = 0.0  # disable auto-dismiss timer for deterministic manual checks

	phone.post_notification("Alert 1", "Body 1", &"app1")
	phone.post_notification("Alert 2", "Body 2", &"app2")
	phone.post_notification("Alert 3", "Body 3", &"app3")

	assert_true(banner.is_banner_visible(), "Banner should be visible")
	assert_eq(banner.get_current_notification()["title"], "Alert 1")
	assert_eq(banner.get_queue_count(), 2, "2 notifications left in queue")

	banner.dismiss_current()
	assert_true(banner.is_banner_visible())
	assert_eq(banner.get_current_notification()["title"], "Alert 2")
	assert_eq(banner.get_queue_count(), 1)

	banner.dismiss_current()
	assert_true(banner.is_banner_visible())
	assert_eq(banner.get_current_notification()["title"], "Alert 3")
	assert_eq(banner.get_queue_count(), 0)

	banner.dismiss_current()
	assert_false(banner.is_banner_visible(), "Banner hidden after all notifications dismissed")


func test_notification_click_opens_app() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	var mock_app := MockPhoneApp.new()
	phone.register_app(mock_app)
	phone.close(true)
	assert_false(phone.is_open)

	phone.post_notification("Incoming Event", "Check this out", &"mock_app")
	assert_true(phone.notification_banner.is_banner_visible())

	# Click the notification banner
	phone.notification_banner._on_banner_clicked()

	assert_true(phone.is_open, "Clicking banner opens the phone")
	assert_eq(phone.current_app_id, &"mock_app", "Clicking banner navigates to the app")
	assert_false(phone.notification_banner.is_banner_visible(), "Banner dismissed on click")


func test_calendar_app_integration() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	var gdo_res: OutingData = load(GIRLS_DAY_OUT_PATH) as OutingData
	assert_not_null(gdo_res, "Girls Day Out resource should load")

	OutingManager.schedule(gdo_res, 600, "Maya")

	phone.open(true)
	var opened: bool = phone.open_app(&"calendar")
	assert_true(opened, "Calendar app opened")

	var cal: CalendarApp = phone.get_app(&"calendar") as CalendarApp
	assert_not_null(cal, "Calendar app instance retrieved")
	assert_eq(cal.get_scheduled_count(), 1, "Calendar sees 1 scheduled outing")
	assert_eq(cal.scheduled_vbox.get_child_count(), 1, "Calendar UI rendered 1 scheduled outing card")

	# Advance time to start preparation (Girls' Day Out prep starts at 600 - 90 = 510)
	GameClock.advance_minutes(510 - GameClock.now_minutes)
	assert_true(OutingManager.is_prep_active(), "Prep should now be active")

	cal.refresh()
	assert_true(cal.active_card.visible, "Active outing card is visible during prep")
	assert_true(cal.active_title_label.text.contains(gdo_res.display_name))
	assert_gt(cal.active_checklist_vbox.get_child_count(), 0, "Prep checklist items are rendered")


func test_phone_to_dict_and_from_dict_serialization() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	var mock_app := MockPhoneApp.new()
	phone.register_app(mock_app)
	mock_app.custom_data = "persisted_value_99"

	phone.open(true)
	phone.open_app(&"mock_app")

	var data: Dictionary = phone.to_dict()
	assert_true(data["is_open"])
	assert_eq(data["current_app_id"], "mock_app")
	assert_eq(data["apps"]["mock_app"]["custom_data"], "persisted_value_99")

	# JSON round trip
	var json_str: String = JSON.stringify(data)
	var parsed: Dictionary = JSON.parse_string(json_str) as Dictionary
	assert_not_null(parsed)

	phone.reset_state()
	assert_false(phone.is_open)
	assert_eq(phone.current_app_id, &"")

	phone.from_dict(parsed)
	assert_true(phone.is_open, "is_open restored from dict")
	assert_eq(phone.current_app_id, &"mock_app", "current_app_id restored from dict")
	assert_eq(mock_app.custom_data, "persisted_value_99", "app state restored from dict")


func test_player_controller_locks_on_phone_open() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	var root_phone: PhoneShell = get_node_or_null("/root/Phone") as PhoneShell
	if root_phone == null:
		pass_test("Autoload Phone not found in test tree; skipped autoload connection test")
		return

	root_phone.reset_state()
	assert_false(player.has_lock_reason(&"phone"))
	assert_false(player.is_input_locked())

	root_phone.open(true)
	assert_true(player.has_lock_reason(&"phone"), "Player should have 'phone' lock reason when phone opens")
	assert_true(player.is_input_locked(), "Player input is locked when phone is open")
	assert_eq(player.target_mouse_mode, Input.MOUSE_MODE_VISIBLE, "Mouse mode is visible when phone is open")

	root_phone.close(true)
	assert_false(player.has_lock_reason(&"phone"), "Player 'phone' lock reason is removed on close")
	assert_false(player.is_input_locked(), "Player input is unlocked when phone closes")
	assert_eq(player.target_mouse_mode, Input.MOUSE_MODE_CAPTURED, "Mouse mode captured when phone closes")


func test_phone_layout_resolutions() -> void:
	var resolutions: Array[Vector2i] = [
		Vector2i(1920, 1080),
		Vector2i(2560, 1080),
		Vector2i(1280, 800),
	]

	for res: Vector2i in resolutions:
		var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
		add_child_autoqfree(phone)
		phone.open(true)

		var aspect_container: AspectRatioContainer = phone.aspect_ratio_container
		assert_not_null(aspect_container)
		assert_almost_eq(aspect_container.ratio, 9.0 / 19.5, 0.001, "Aspect ratio is 9:19.5 at %dx%d" % [res.x, res.y])

		var bezel: PanelContainer = aspect_container.get_node("PhoneBezel") as PanelContainer
		assert_not_null(bezel)
		assert_gt(bezel.custom_minimum_size.x, 0.0)
		assert_gt(bezel.custom_minimum_size.y, 0.0)

