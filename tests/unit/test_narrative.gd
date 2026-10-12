extends GutTest

const DIALOGUE_BOX_SCENE_PATH := "res://features/narrative/dialogue_box.tscn"
const RAGE_FX_SCENE_PATH := "res://features/narrative/rage_release_fx.tscn"
const LIBRARY_PATH := "res://data/narrative/library.tres"


func before_each() -> void:
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	SceneRouter.reset_state()
	NarrativeManager.reset_state()


func after_each() -> void:
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	SceneRouter.reset_state()
	NarrativeManager.reset_state()


func test_condition_day_range() -> void:
	var cond := NarrativeCondition.create_day_range(3, 7)

	# Context override test
	assert_false(cond.evaluate({"day": 2}))
	assert_true(cond.evaluate({"day": 3}))
	assert_true(cond.evaluate({"day": 5}))
	assert_true(cond.evaluate({"day": 7}))
	assert_false(cond.evaluate({"day": 8}))

	# GameClock integration test
	GameClock.now_minutes = 0 # Day 1
	assert_false(cond.evaluate())
	GameClock.now_minutes = 3 * 1440 # Day 4
	assert_true(cond.evaluate())


func test_condition_phase_tag() -> void:
	var cond_cramps := NarrativeCondition.create_phase_tag(&"cramps", true)
	var cond_no_cramps := NarrativeCondition.create_phase_tag(&"cramps", false)

	# Context evaluation
	assert_true(cond_cramps.evaluate({"phase_tags": [&"cramps", &"fatigue"]}))
	assert_false(cond_cramps.evaluate({"phase_tags": [&"social", &"confident"]}))
	assert_false(cond_no_cramps.evaluate({"phase_tags": [&"cramps"]}))
	assert_true(cond_no_cramps.evaluate({"phase_tags": [&"social"]}))

	# CycleManager integration
	CycleManager.force_phase(Enums.CyclePhase.MENSTRUAL)
	assert_true(cond_cramps.evaluate(), "Menstrual phase should have cramps tag")

	CycleManager.force_phase(Enums.CyclePhase.OVULATORY)
	assert_false(cond_cramps.evaluate(), "Ovulatory phase should not have cramps tag")


func test_condition_stat_threshold() -> void:
	var cond_rage := NarrativeCondition.create_stat_threshold(Enums.Stat.RAGE, 40.0, 100.0)

	# Context evaluation
	assert_false(cond_rage.evaluate({"stats": {Enums.Stat.RAGE: 30.0}}))
	assert_true(cond_rage.evaluate({"stats": {Enums.Stat.RAGE: 50.0}}))

	# StatusManager integration
	StatusManager.set_value(Enums.Stat.RAGE, 20.0)
	assert_false(cond_rage.evaluate())
	StatusManager.set_value(Enums.Stat.RAGE, 60.0)
	assert_true(cond_rage.evaluate())


func test_condition_location() -> void:
	var cond_apt := NarrativeCondition.create_location(&"apartment")

	# Context evaluation
	assert_true(cond_apt.evaluate({"level_id": "apartment"}))
	assert_false(cond_apt.evaluate({"level_id": "thrift_store"}))

	# SceneRouter integration
	SceneRouter.current_level_id = "apartment"
	assert_true(cond_apt.evaluate())
	SceneRouter.current_level_id = "thrift_store"
	assert_false(cond_apt.evaluate())


func test_condition_flags() -> void:
	var req_cond := NarrativeCondition.create_flag_required(&"work_boundary_set", 1)
	var for_cond := NarrativeCondition.create_flag_forbidden(&"work_boundary_set")

	# NarrativeManager integration
	assert_false(req_cond.evaluate(), "Required flag not yet set")
	assert_true(for_cond.evaluate(), "Forbidden flag not yet set passes")

	NarrativeManager.set_flag(&"work_boundary_set", 1)
	assert_true(req_cond.evaluate(), "Required flag set passes")
	assert_false(for_cond.evaluate(), "Forbidden flag set fails")


func test_once_prevention() -> void:
	var ev := NarrativeEvent.new()
	ev.id = &"test_once_event"
	ev.once = true

	var lib := NarrativeLibrary.new()
	lib.events.append(ev)
	NarrativeManager.library = lib

	assert_true(NarrativeManager.try_trigger(), "First trigger succeeds")
	assert_eq(NarrativeManager.active_event, ev)
	assert_true(NarrativeManager.is_event_fired(&"test_once_event"))

	NarrativeManager.active_event = null # finish event
	NarrativeManager.last_event_minute = -9999 # reset cooldown

	assert_false(NarrativeManager.try_trigger(), "Second trigger rejected due to once = true")

	NarrativeManager.reset_fired_events()
	assert_true(NarrativeManager.try_trigger(), "Trigger succeeds after resetting fired events")


func test_cooldown_enforcement() -> void:
	var ev1 := NarrativeEvent.new()
	ev1.id = &"test_ev1"
	var ev2 := NarrativeEvent.new()
	ev2.id = &"test_ev2"

	var lib := NarrativeLibrary.new()
	lib.events.append_array([ev1, ev2])
	NarrativeManager.library = lib

	GameClock.now_minutes = 100
	assert_true(NarrativeManager.try_trigger(), "Triggers at minute 100")
	NarrativeManager.active_event = null # end dialogue

	GameClock.now_minutes = 130
	assert_eq(NarrativeManager.get_cooldown_remaining(), 30)
	assert_false(NarrativeManager.try_trigger(), "Rejected during 60 min cooldown")

	GameClock.now_minutes = 160
	assert_eq(NarrativeManager.get_cooldown_remaining(), 0)
	assert_true(NarrativeManager.try_trigger(), "Allowed once cooldown expires at minute 160")


func test_priority_resolution() -> void:
	var ev_low := NarrativeEvent.new()
	ev_low.id = &"low_prio"
	ev_low.priority = 5

	var ev_high := NarrativeEvent.new()
	ev_high.id = &"high_prio"
	ev_high.priority = 25

	var lib := NarrativeLibrary.new()
	lib.events.append_array([ev_low, ev_high])
	NarrativeManager.library = lib

	assert_true(NarrativeManager.try_trigger())
	assert_eq(NarrativeManager.active_event.id, &"high_prio", "Higher priority event wins")


func test_choices_apply_modifiers_and_flags_assert_convention() -> void:
	var ev := NarrativeEvent.new()
	ev.id = &"event_stances"

	var c_placate := NarrativeChoice.new(Enums.Stance.PLACATE, "I will accommodate you.")
	var mod_placate_rage := StatModifier.new()
	mod_placate_rage.stat = Enums.Stat.RAGE
	mod_placate_rage.kind = Enums.ModifierKind.INSTANT
	mod_placate_rage.value = 15.0
	mod_placate_rage.source_id = &"test"
	c_placate.modifiers.append(mod_placate_rage)
	c_placate.set_flags = {"placated": 1}

	var c_assert := NarrativeChoice.new(Enums.Stance.ASSERT, "No, I am holding my boundary.")
	var mod_assert_rage := StatModifier.new()
	mod_assert_rage.stat = Enums.Stat.RAGE
	mod_assert_rage.kind = Enums.ModifierKind.INSTANT
	mod_assert_rage.value = -25.0
	mod_assert_rage.source_id = &"test"
	var mod_assert_sanity := StatModifier.new()
	mod_assert_sanity.stat = Enums.Stat.SANITY
	mod_assert_sanity.kind = Enums.ModifierKind.INSTANT
	mod_assert_sanity.value = 20.0
	mod_assert_sanity.source_id = &"test"
	c_assert.modifiers.append_array([mod_assert_rage, mod_assert_sanity])
	c_assert.set_flags = {"boundary_firm": 1}

	ev.choices.append_array([c_placate, c_assert])

	# Test Placate choice
	StatusManager.set_value(Enums.Stat.RAGE, 20.0)
	StatusManager.set_value(Enums.Stat.SANITY, 50.0)

	NarrativeManager.trigger_event(ev)
	NarrativeManager.choose(0) # Placate

	assert_almost_eq(StatusManager.get_value(Enums.Stat.RAGE), 35.0, 1e-4, "Rage increases on Placate")
	assert_eq(NarrativeManager.get_flag(&"placated"), 1)
	assert_eq(NarrativeManager.get_flag(&"self_respect"), 0, "No self_respect gained on Placate")

	# Test Assert choice
	StatusManager.set_value(Enums.Stat.RAGE, 60.0)
	StatusManager.set_value(Enums.Stat.SANITY, 50.0)

	NarrativeManager.trigger_event(ev)
	NarrativeManager.choose(1) # Assert

	assert_almost_eq(StatusManager.get_value(Enums.Stat.RAGE), 35.0, 1e-4, "Rage drops on Assert")
	assert_almost_eq(StatusManager.get_value(Enums.Stat.SANITY), 70.0, 1e-4, "Sanity increases on Assert")
	assert_eq(NarrativeManager.get_flag(&"boundary_firm"), 1)
	assert_eq(NarrativeManager.get_flag(&"self_respect"), 1, "Assert increments self_respect")


func test_follow_up_chain() -> void:
	var follow_up := NarrativeEvent.new()
	follow_up.id = &"follow_up_event"
	follow_up.lines = ["You stood your ground, and they backed off."]

	var first_event := NarrativeEvent.new()
	first_event.id = &"first_event"
	var choice := NarrativeChoice.new(Enums.Stance.ASSERT, "Assert boundary")
	choice.follow_up = follow_up
	first_event.choices.append(choice)

	NarrativeManager.trigger_event(first_event)
	assert_eq(NarrativeManager.active_event.id, &"first_event")
	assert_true(GameClock.has_pause_reason(&"dialogue"))

	NarrativeManager.choose(0)

	assert_eq(NarrativeManager.active_event, follow_up, "Transitions directly into follow_up")
	assert_true(GameClock.has_pause_reason(&"dialogue"), "Dialogue pause remains during follow_up")

	# Finish follow-up
	var end_choice := NarrativeChoice.new(Enums.Stance.DEFLECT, "Done")
	follow_up.choices.append(end_choice)
	NarrativeManager.choose(0)

	assert_null(NarrativeManager.active_event)
	assert_false(GameClock.has_pause_reason(&"dialogue"), "Dialogue pause cleared after entire chain")


func test_game_clock_pause_and_resume() -> void:
	var ev := NarrativeEvent.new()
	ev.id = &"ev_clock"
	var c := NarrativeChoice.new(Enums.Stance.DEFLECT, "Dismiss")
	ev.choices.append(c)

	assert_false(GameClock.has_pause_reason(&"dialogue"))

	NarrativeManager.trigger_event(ev)
	assert_true(GameClock.has_pause_reason(&"dialogue"), "Clock paused on dialogue start")

	NarrativeManager.choose(0)
	assert_false(GameClock.has_pause_reason(&"dialogue"), "Clock resumed on dialogue end")


func test_player_input_lock() -> void:
	var player: PlayerController = PlayerController.new()
	add_child_autoqfree(player)

	var ev := NarrativeEvent.new()
	ev.id = &"ev_input"
	var c := NarrativeChoice.new(Enums.Stance.DEFLECT, "OK")
	ev.choices.append(c)

	assert_false(player.has_lock_reason(&"dialogue"))

	NarrativeManager.trigger_event(ev)
	assert_true(player.has_lock_reason(&"dialogue"), "Player input locked during dialogue")

	NarrativeManager.choose(0)
	assert_false(player.has_lock_reason(&"dialogue"), "Player input unlocked after dialogue")


func test_phone_closed_on_event() -> void:
	if Phone:
		Phone.open(true)
		assert_true(Phone.is_open, "Phone should be open")

		var ev := NarrativeEvent.new()
		ev.id = &"ev_phone"
		var c := NarrativeChoice.new(Enums.Stance.DEFLECT, "End")
		ev.choices.append(c)

		NarrativeManager.trigger_event(ev)
		assert_false(Phone.is_open, "Phone closed when narrative event triggered")

		NarrativeManager.choose(0)


func test_json_round_trip_serialization() -> void:
	NarrativeManager.set_flag(&"self_respect", 3)
	NarrativeManager.set_flag(&"work_boundary_set", 1)
	NarrativeManager.fired_events.append_array([&"event_1", &"event_2"])
	NarrativeManager.last_event_minute = 540
	NarrativeManager.cooldown_minutes = 45

	var dict: Dictionary = NarrativeManager.to_dict()
	var json_str: String = JSON.stringify(dict)
	var parsed: Variant = JSON.parse_string(json_str)

	assert_true(parsed is Dictionary)

	NarrativeManager.reset_state()
	NarrativeManager.from_dict(parsed as Dictionary)

	assert_eq(NarrativeManager.get_flag(&"self_respect"), 3)
	assert_eq(NarrativeManager.get_flag(&"work_boundary_set"), 1)
	assert_true(NarrativeManager.is_event_fired(&"event_1"))
	assert_true(NarrativeManager.is_event_fired(&"event_2"))
	assert_eq(NarrativeManager.last_event_minute, 540)
	assert_eq(NarrativeManager.cooldown_minutes, 45)


func test_authored_library_and_events() -> void:
	assert_true(ResourceLoader.exists(LIBRARY_PATH), "library.tres exists")
	var lib: NarrativeLibrary = load(LIBRARY_PATH) as NarrativeLibrary
	assert_not_null(lib)
	assert_gte(lib.events.size(), 5, "Library has at least 5 authored events")

	var expected_ids: Array[StringName] = [
		&"family_marriage",
		&"unsolicited_appearance",
		&"work_day_off",
		&"cycle_pressure",
		&"follow_up_confrontation",
	]

	for eid: StringName in expected_ids:
		assert_true(lib.has_event(eid), "Library contains event %s" % eid)
		var ev: NarrativeEvent = lib.get_event(eid)
		assert_not_null(ev)
		assert_false(ev.speaker.is_empty(), "Event %s has speaker" % eid)
		assert_gt(ev.lines.size(), 0, "Event %s has lines" % eid)
		assert_gte(ev.choices.size(), 3, "Event %s has 3 stances" % eid)

		var stances_found: Array[Enums.Stance] = []
		for c: NarrativeChoice in ev.choices:
			stances_found.append(c.stance)
			assert_false(c.text.is_empty(), "Choice has text")

		assert_true(stances_found.has(Enums.Stance.PLACATE), "Event %s has Placate choice" % eid)
		assert_true(stances_found.has(Enums.Stance.DEFLECT), "Event %s has Deflect choice" % eid)
		assert_true(stances_found.has(Enums.Stance.ASSERT), "Event %s has Assert choice" % eid)


func test_dialogue_box_ui_and_flow() -> void:
	var box_scene: PackedScene = load(DIALOGUE_BOX_SCENE_PATH)
	assert_not_null(box_scene)

	var box: DialogueBox = box_scene.instantiate() as DialogueBox
	add_child_autoqfree(box)

	assert_false(box.visible, "Dialogue box hidden initially")

	var ev := NarrativeEvent.new()
	ev.id = &"ui_test_event"
	ev.speaker = "Test Speaker"
	ev.channel = &"PHONE_CALL"
	ev.lines = ["First page of dialogue.", "Second page of dialogue."]

	var c_placate := NarrativeChoice.new(Enums.Stance.PLACATE, "Placate text")
	var c_assert := NarrativeChoice.new(Enums.Stance.ASSERT, "Assert text")
	ev.choices.append_array([c_placate, c_assert])

	NarrativeManager.trigger_event(ev)

	assert_true(box.visible, "Dialogue box visible on event start")
	assert_eq(box.speaker_label.text, "Test Speaker")
	assert_true(box.channel_badge.text.contains("PHONE CALL"))
	assert_eq(box.line_label.text, "First page of dialogue.")
	assert_true(box.next_button.visible, "Next button visible on page 1")
	assert_false(box.choices_container.visible, "Choices hidden on page 1")

	# Advance to second page
	box.next_button.pressed.emit()

	assert_eq(box.line_label.text, "Second page of dialogue.")
	assert_false(box.next_button.visible, "Next button hidden on last page")
	assert_true(box.choices_container.visible, "Choices visible on last page")
	assert_eq(box.choices_container.get_child_count(), 2)

	# Click Assert button
	var assert_btn: ChoiceButton = box.choices_container.get_child(1) as ChoiceButton
	assert_not_null(assert_btn)
	assert_true(assert_btn.text.contains("Assert text"))
	assert_btn.pressed.emit()

	assert_false(box.visible, "Dialogue box hidden when choice made and event ends")


func test_rage_release_fx() -> void:
	var fx_scene: PackedScene = load(RAGE_FX_SCENE_PATH)
	assert_not_null(fx_scene)

	var fx: RageReleaseFx = fx_scene.instantiate() as RageReleaseFx
	add_child_autoqfree(fx)

	watch_signals(fx)
	fx.play()
	assert_signal_emitted(fx, "played", "RageReleaseFx played signal emitted")
