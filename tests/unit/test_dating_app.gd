extends GutTest

const DATING_APP_SCENE_PATH := "res://features/phone/apps/dating/dating_app.tscn"
const SWIPE_CARD_SCENE_PATH := "res://features/phone/apps/dating/swipe_card.tscn"
const DATE_NIGHT_PATH := "res://data/outings/date_night.tres"

var dating_app_scene: PackedScene
var swipe_card_scene: PackedScene
var date_night: OutingData


func before_each() -> void:
	dating_app_scene = load(DATING_APP_SCENE_PATH) as PackedScene
	swipe_card_scene = load(SWIPE_CARD_SCENE_PATH) as PackedScene
	date_night = load(DATE_NIGHT_PATH) as OutingData

	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	OutingManager.reset_state()


func after_each() -> void:
	GameClock.reset_state()
	StatusManager.reset_state()
	OutingManager.reset_state()


func _create_test_profile(p_id: StringName, name: String, r_flags: Array[String], g_flags: Array[String], match_c: float) -> DatingProfile:
	var p := DatingProfile.new()
	p.id = p_id
	p.display_name = name
	p.age = 26
	p.bio = "Test profile bio"
	p.red_flags = r_flags
	p.green_flags = g_flags
	p.match_chance = match_c
	p.date_outing = date_night
	p.resource_path = "res://data/dating_profiles/%s.tres" % str(p_id)
	return p


func test_authored_profiles_exist_and_valid() -> void:
	var expected_ids: Array[String] = [
		"julian", "leo", "marcus", "sam", "alex", "liam", "oliver", "noah"
	]

	for pid: String in expected_ids:
		var path: String = "res://data/dating_profiles/%s.tres" % pid
		assert_true(ResourceLoader.exists(path), "Authored profile must exist: %s" % path)

		var profile: DatingProfile = load(path) as DatingProfile
		assert_not_null(profile, "Profile %s should load as DatingProfile" % pid)
		assert_eq(str(profile.id), pid, "Profile id matches file name")
		assert_false(profile.display_name.is_empty(), "Profile has display name")
		assert_gt(profile.age, 18, "Profile age is adult")
		assert_false(profile.bio.is_empty(), "Profile has bio")
		assert_not_null(profile.photo, "Profile %s has photo" % pid)
		assert_gt(profile.green_flags.size(), 0, "Profile %s has green flags" % pid)
		assert_gt(profile.red_flags.size(), 0, "Profile %s has red flags" % pid)
		assert_true(profile.match_chance >= 0.0 and profile.match_chance <= 1.0, "match_chance is in [0, 1]")
		assert_not_null(profile.date_outing, "Profile %s has date_outing" % pid)


func test_dating_app_initialization_and_daily_deck() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	assert_eq(app.app_id, &"dating")
	assert_eq(app.display_name, "Cupid")
	assert_not_null(app.icon, "Cupid app should have an icon")

	assert_eq(app.deck_profile_ids.size(), 5, "Daily deck should initialize with 5 profiles")
	assert_not_null(app.current_card_profile, "Top card profile should be loaded")
	assert_true(app.swipe_card.visible, "SwipeCard should be visible")
	assert_false(app.empty_state_panel.visible, "EmptyStatePanel should be hidden")
	assert_false(app.pass_button.disabled, "Pass button enabled")
	assert_false(app.like_button.disabled, "Like button enabled")


func test_red_flag_sanity_penalty_applied_on_right_swipe() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	var p1 := _create_test_profile(&"p1", "Profile 1", ["Red Flag 1", "Red Flag 2"], ["Green 1"], 0.0)
	var p2 := _create_test_profile(&"p2", "Profile 2", ["Red Flag A"], ["Green 1"], 0.0)
	app.set_profiles([p1, p2])
	app.rebuild_daily_deck()

	var initial_sanity: float = StatusManager.get_stat(&"sanity")
	assert_eq(initial_sanity, 80.0)

	# Right swipe on p1 with 2 red flags -> cost is 2 * 5.0 = 10.0
	app.swipe_right(true)

	var new_sanity: float = StatusManager.get_stat(&"sanity")
	assert_eq(new_sanity, 70.0, "Sanity should decrease by 10 for 2 red flags")
	assert_true(app.swiped_ids.has(&"p1"), "p1 marked as swiped")
	assert_eq(app.current_card_profile.id, &"p2", "Deck advanced to p2")


func test_left_swipe_pass_costs_no_sanity_and_no_match() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	var p1 := _create_test_profile(&"p1", "Profile 1", ["Red 1", "Red 2", "Red 3"], ["Green 1"], 1.0)
	var p2 := _create_test_profile(&"p2", "Profile 2", [], ["Green 1"], 0.5)
	app.set_profiles([p1, p2])
	app.rebuild_daily_deck()

	var initial_sanity: float = StatusManager.get_stat(&"sanity")

	# Pass (left swipe)
	app.swipe_left(true)

	assert_eq(StatusManager.get_stat(&"sanity"), initial_sanity, "Passing must not penalize sanity")
	assert_eq(OutingManager.get_scheduled().size(), 0, "Passing must not schedule an outing")
	assert_true(app.swiped_ids.has(&"p1"), "p1 marked as swiped")
	assert_eq(app.current_card_profile.id, &"p2", "Deck advanced to p2")


func test_match_schedules_date_night_with_partner_ref() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	var julian: DatingProfile = load("res://data/dating_profiles/julian.tres") as DatingProfile
	julian.match_chance = 1.0  # Force guaranteed match
	app.set_profiles([julian])
	app.rebuild_daily_deck()

	watch_signals(app)

	# Current time is 07:00 (420 min on Day 1). 20:00 tonight is 1200 min.
	app.swipe_right(true)

	assert_signal_emitted(app, "notification_posted")
	var notif_params: Array = get_signal_parameters(app, "notification_posted")
	assert_eq(notif_params[0], "It's a Match!")
	assert_true(str(notif_params[1]).contains("Julian"))

	var scheduled: Array = OutingManager.get_scheduled()
	assert_eq(scheduled.size(), 1, "Date night should be scheduled in OutingManager")
	assert_eq(scheduled[0]["departure_min"], 1200, "Should be scheduled for 20:00 tonight")

	var expected_ref: String = ResRef.to_ref(julian)
	assert_eq(scheduled[0]["partner_ref"], expected_ref, "Partner ref should match ResRef.to_ref(profile)")


func test_match_schedules_next_available_when_conflict() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	# Block tonight's 20:00 window (1200 min) with Girls' Day Out
	var gdo: OutingData = load("res://data/outings/girls_day_out.tres") as OutingData
	var ok: bool = OutingManager.schedule(gdo, 1200, "Maya")
	assert_true(ok, "Blocking outing scheduled")

	var leo: DatingProfile = load("res://data/dating_profiles/leo.tres") as DatingProfile
	leo.match_chance = 1.0
	app.set_profiles([leo])
	app.rebuild_daily_deck()

	app.swipe_right(true)

	var scheduled: Array = OutingManager.get_scheduled()
	assert_eq(scheduled.size(), 2, "Both outings should be scheduled")
	# First is GDO at 1200; second should be Date Night at Day 2 20:00 = 1440 + 1200 = 2640
	assert_eq(scheduled[1]["departure_min"], 2640, "Date night scheduled for next available 20:00 (Day 2)")
	assert_eq(scheduled[1]["partner_ref"], ResRef.to_ref(leo))


func test_deck_rebuilds_on_game_clock_day_started() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	# Swipe 3 cards on day 1
	app.swipe_left(true)
	app.swipe_left(true)
	app.swipe_left(true)

	assert_eq(app.swiped_ids.size(), 3)
	assert_eq(app.deck_profile_ids.size(), 2)

	# Trigger new day
	GameClock.skip(1440)  # Skips 24 hours, triggering day_started

	# Rebuilt deck should have 5 new cards (or remaining unseen)
	assert_eq(app.deck_profile_ids.size(), 5, "Rebuilt deck has 5 unseen profiles")
	for swiped_id: StringName in app.swiped_ids:
		assert_false(app.deck_profile_ids.has(swiped_id), "Swiped profiles must not appear in rebuilt deck")


func test_empty_deck_handling() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	var p1 := _create_test_profile(&"p1", "Profile 1", [], [], 0.0)
	app.set_profiles([p1])
	app.rebuild_daily_deck()

	assert_eq(app.deck_profile_ids.size(), 1)
	assert_true(app.swipe_card.visible)

	# Swipe the only card
	app.swipe_left(true)

	assert_eq(app.deck_profile_ids.size(), 0, "Deck is now empty")
	assert_null(app.current_card_profile, "Current profile is null")
	assert_false(app.swipe_card.visible, "Swipe card hidden when deck empty")
	assert_true(app.empty_state_panel.visible, "Empty state panel shown")
	assert_true(app.pass_button.disabled, "Pass button disabled")
	assert_true(app.like_button.disabled, "Like button disabled")

	# Swiping when empty is a no-op and doesn't crash
	app.swipe_left(true)
	app.swipe_right(true)
	assert_eq(app.swiped_ids.size(), 1)


func test_to_dict_and_from_dict_json_round_trip() -> void:
	var app: DatingApp = dating_app_scene.instantiate() as DatingApp
	add_child_autoqfree(app)

	# Swipe 2 cards
	app.swipe_left(true)
	app.swipe_right(true)

	var original_swiped: Array[StringName] = app.swiped_ids.duplicate()
	var original_deck: Array[StringName] = app.deck_profile_ids.duplicate()
	var original_current: DatingProfile = app.current_card_profile

	var data: Dictionary = app.to_dict()
	assert_eq(data["swiped_ids"].size(), 2)
	assert_eq(data["deck_profile_ids"].size(), 3)

	# JSON serialization test
	var json_str: String = JSON.stringify(data)
	assert_false(json_str.is_empty())
	var parsed: Variant = JSON.parse_string(json_str)
	assert_not_null(parsed)
	assert_true(parsed is Dictionary)

	# Reset state
	app.reset_state()
	assert_eq(app.swiped_ids.size(), 0)
	assert_eq(app.deck_profile_ids.size(), 5)

	# Restore from parsed JSON
	app.from_dict(parsed as Dictionary)
	assert_eq(app.swiped_ids, original_swiped, "swiped_ids restored")
	assert_eq(app.deck_profile_ids, original_deck, "deck_profile_ids restored")
	assert_eq(app.current_card_profile.id, original_current.id, "current card profile restored")


func test_swipe_card_drag_and_snap_back() -> void:
	var card: SwipeCard = swipe_card_scene.instantiate() as SwipeCard
	add_child_autoqfree(card)

	var p := _create_test_profile(&"p1", "Test Julian", ["Red"], ["Green"], 0.5)
	card.set_profile(p)
	card.snap_back_duration = 0.05
	card.tween_duration = 0.05

	var start_pos: Vector2 = card.position

	# Simulate dragging below threshold
	card._start_drag(Vector2(100, 100))
	card._process_drag(Vector2(130, 100))  # 30px move, threshold is 80px
	assert_gt(card.position.x, start_pos.x)
	assert_gt(card.rotation, 0.0)

	watch_signals(card)

	# Release below threshold
	card._end_drag()
	await wait_seconds(0.1)

	assert_almost_eq(card.position.x, start_pos.x, 1.0, "Card snaps back to initial x")
	assert_almost_eq(card.rotation, 0.0, 0.01, "Rotation resets to 0")
	assert_signal_not_emitted(card, "swiped_left")
	assert_signal_not_emitted(card, "swiped_right")


func test_swipe_card_swipes_emit_signals() -> void:
	var card: SwipeCard = swipe_card_scene.instantiate() as SwipeCard
	add_child_autoqfree(card)

	var p := _create_test_profile(&"p1", "Test Sam", ["Red"], ["Green"], 0.5)
	card.set_profile(p)

	watch_signals(card)

	card.swipe_left(true)
	assert_signal_emitted(card, "swiped_left")
	assert_signal_not_emitted(card, "swiped_right")

	card.reset_card()
	card.swipe_right(true)
	assert_signal_emitted(card, "swiped_right")
