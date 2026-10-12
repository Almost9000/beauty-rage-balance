extends GutTest

var girls_day_out: OutingData
var date_night: OutingData
var front_door_scene: PackedScene
var departure_summary_scene: PackedScene


func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()

	girls_day_out = load("res://data/outings/girls_day_out.tres") as OutingData
	date_night = load("res://data/outings/date_night.tres") as OutingData
	front_door_scene = load("res://features/prep/front_door.tscn") as PackedScene
	departure_summary_scene = load("res://features/prep/departure_summary.tscn") as PackedScene


func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()


func test_score_thresholds_pass_partial_fail() -> void:
	# Girls Day Out: pass_threshold = 0.75, partial_threshold = 0.4
	# 1. High score -> PASS
	StatusManager.set_value(Enums.Stat.HYGIENE, 90.0)
	var casual_top: ClothingItem = load("res://data/clothing/top/top_chic_blouse.tres") as ClothingItem
	InventoryManager.equip(casual_top)
	FinanceManager.wallet_cents = 5000

	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(510 - GameClock.now_minutes)  # prep active

	var eval_pass: Dictionary = OutingManager.evaluate()
	assert_gt(eval_pass["score"], 0.75, "High prep readiness should exceed pass threshold")
	assert_eq(eval_pass["result"], Enums.OutingResult.PASS, "Score >= 0.75 should result in PASS")

	# 2. Moderate score -> PARTIAL
	# Hygiene at 35 (0.5 score), budget at 1500 (0.5 score), casual outfit (1.0), optional makeup (1.0)
	# Weighted score = (0.5*1 + 0.5*1 + 1.0*1 + 1.0*0.8) / 3.8 = 2.8 / 3.8 = ~0.737
	StatusManager.set_value(Enums.Stat.HYGIENE, 35.0)
	FinanceManager.wallet_cents = 1500
	var eval_partial: Dictionary = OutingManager.evaluate()
	assert_true(eval_partial["score"] >= 0.4 and eval_partial["score"] < 0.75, "Score should fall into partial range")
	assert_eq(eval_partial["result"], Enums.OutingResult.PARTIAL, "Score in [0.4, 0.75) should result in PARTIAL")

	# 3. Failing score -> FAIL
	StatusManager.set_value(Enums.Stat.HYGIENE, 0.0)
	FinanceManager.wallet_cents = 0  # Fails budget check
	InventoryManager.equipped.clear()  # Fails dress code check
	var eval_fail: Dictionary = OutingManager.evaluate()
	assert_lt(eval_fail["score"], 0.4, "Low readiness should be below partial threshold")
	assert_eq(eval_fail["result"], Enums.OutingResult.FAIL, "Score < 0.4 should result in FAIL")


func test_lateness_penalty_calculation() -> void:
	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(510 - GameClock.now_minutes)

	# On time (lateness = 0)
	assert_eq(OutingManager.get_lateness_min(600, 550), 0)
	assert_eq(OutingManager.calculate_penalty(girls_day_out, 0), 0.0)

	# 10 minutes late: penalty = (10/10) * 0.1 = 0.1
	assert_eq(OutingManager.get_lateness_min(600, 610), 10)
	assert_almost_eq(OutingManager.calculate_penalty(girls_day_out, 10), 0.1, 1e-4)

	# 25 minutes late: penalty = (25/10) * 0.1 = 0.25
	assert_eq(OutingManager.get_lateness_min(600, 625), 25)
	assert_almost_eq(OutingManager.calculate_penalty(girls_day_out, 25), 0.25, 1e-4)

	# Evaluate with penalty applied
	var eval_on_time: Dictionary = OutingManager.evaluate(girls_day_out, 600, 580)
	var eval_late_20: Dictionary = OutingManager.evaluate(girls_day_out, 600, 620)
	assert_almost_eq(eval_on_time["score"] - eval_late_20["score"], 0.2, 1e-4, "20m lateness reduces score by 0.2")


func test_depart_on_time_success() -> void:
	# Setup passing prep conditions
	StatusManager.set_value(Enums.Stat.HYGIENE, 95.0)
	StatusManager.set_value(Enums.Stat.SANITY, 50.0)
	var casual_top: ClothingItem = load("res://data/clothing/top/top_chic_blouse.tres") as ClothingItem
	InventoryManager.equip(casual_top)
	FinanceManager.wallet_cents = 6000
	OutingManager.set_affinity("Chloe", 10)

	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(510 - GameClock.now_minutes)  # now 510

	watch_signals(OutingManager)

	var start_wallet: int = FinanceManager.wallet_cents
	var res: Dictionary = OutingManager.depart()

	assert_eq(res["result"], Enums.OutingResult.PASS)
	assert_signal_emitted(OutingManager, "outing_departed")
	assert_signal_emitted(OutingManager, "outing_resolved")

	# Wallet charged outing cost (€30 = 3000 cents)
	assert_eq(FinanceManager.wallet_cents, start_wallet - 3000)

	# Time skipped by duration (510 + 180 = 690)
	assert_eq(GameClock.now_minutes, 690)

	# Affinity increased by pass_affinity_delta (+15): 10 + 15 = 25
	assert_eq(OutingManager.get_affinity("Chloe"), 25)

	# Active outing cleared
	assert_false(OutingManager.is_prep_active())
	assert_null(OutingManager.active_outing)


func test_depart_late_within_grace_penalized() -> void:
	StatusManager.set_value(Enums.Stat.HYGIENE, 95.0)
	var casual_top: ClothingItem = load("res://data/clothing/top/top_chic_blouse.tres") as ClothingItem
	InventoryManager.equip(casual_top)
	FinanceManager.wallet_cents = 6000
	OutingManager.set_affinity("Chloe", 20)

	OutingManager.schedule(girls_day_out, 600, "Chloe")
	# Advance clock to 615 min -> 15 min late
	GameClock.advance_minutes(615 - GameClock.now_minutes)

	assert_true(OutingManager.is_late())
	assert_eq(OutingManager.get_lateness_min(), 15)

	var eval_res: Dictionary = OutingManager.evaluate()
	assert_almost_eq(eval_res["penalty"], 0.15, 1e-4)

	var res: Dictionary = OutingManager.depart()
	# Time skipped from 615 by 180 min -> 795
	assert_eq(GameClock.now_minutes, 795)
	# Wallet charged (€30)
	assert_eq(FinanceManager.wallet_cents, 3000)


func test_missed_outing_after_grace_period() -> void:
	StatusManager.set_value(Enums.Stat.SANITY, 50.0)
	FinanceManager.wallet_cents = 6000
	OutingManager.set_affinity("Chloe", 20)

	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(510 - GameClock.now_minutes)  # prep starts

	watch_signals(OutingManager)

	# Advance to departure deadline (600)
	GameClock.advance_minutes(90)
	assert_signal_emitted(OutingManager, "departure_deadline_reached")
	assert_signal_not_emitted(OutingManager, "outing_missed")
	assert_true(OutingManager.is_prep_active())

	# Advance to grace end (600 + 30 = 630) -> triggers missed!
	GameClock.advance_minutes(30)

	assert_signal_emitted(OutingManager, "outing_missed")
	assert_signal_not_emitted(OutingManager, "outing_departed")

	# Affinity penalty for FAIL (-10) applied: 20 - 10 = 10
	assert_eq(OutingManager.get_affinity("Chloe"), 10)

	# FAIL consequences applied to StatusManager (source_id = "outing:girls_day_out")
	var active_mods: Array[StatModifier] = StatusManager.get_modifiers()
	var found_fail_mod: bool = false
	for m: StatModifier in active_mods:
		if m.source_id == &"outing:girls_day_out":
			found_fail_mod = true
			break
	assert_true(found_fail_mod, "FAIL modifier must be registered in StatusManager")

	# No outing duration skipped! Time remains at 630
	assert_eq(GameClock.now_minutes, 630)

	# Wallet NOT charged!
	assert_eq(FinanceManager.wallet_cents, 6000)

	# Outing cleared
	assert_false(OutingManager.is_prep_active())


func test_modifiers_registered_with_correct_source() -> void:
	StatusManager.set_value(Enums.Stat.HYGIENE, 95.0)
	FinanceManager.wallet_cents = 7000
	OutingManager.schedule(date_night, 600, "Liam")
	# Date night prep window is 120m -> prep start at 480. Advance to 500.
	GameClock.advance_minutes(500 - GameClock.now_minutes)

	OutingManager.depart()

	var mods: Array[StatModifier] = StatusManager.get_modifiers()
	var found_date_night_source: bool = false
	for m: StatModifier in mods:
		if m.source_id == &"outing:date_night":
			found_date_night_source = true
			break
	assert_true(found_date_night_source, "Modifiers must have source_id = outing:date_night")

	# Test removal by source works cleanly
	StatusManager.remove_by_source(&"outing:date_night")
	for m: StatModifier in StatusManager.get_modifiers():
		assert_ne(m.source_id, &"outing:date_night")


func test_affinity_deltas_pass_partial_fail() -> void:
	assert_eq(girls_day_out.get_affinity_delta(Enums.OutingResult.PASS), 15)
	assert_eq(girls_day_out.get_affinity_delta(Enums.OutingResult.PARTIAL), 5)
	assert_eq(girls_day_out.get_affinity_delta(Enums.OutingResult.FAIL), -10)

	assert_eq(date_night.get_affinity_delta(Enums.OutingResult.PASS), 20)
	assert_eq(date_night.get_affinity_delta(Enums.OutingResult.PARTIAL), 5)
	assert_eq(date_night.get_affinity_delta(Enums.OutingResult.FAIL), -15)


func test_json_round_trip_between_deadline_and_grace_end() -> void:
	OutingManager.set_affinity("Chloe", 15)
	OutingManager.schedule(girls_day_out, 600, "Chloe")

	# Advance to minute 615: between departure deadline (600) and grace end (630)
	GameClock.advance_minutes(615 - GameClock.now_minutes)
	assert_true(OutingManager.is_prep_active())
	assert_true(OutingManager.is_late())

	var data: Dictionary = OutingManager.to_dict()

	# Verify JSON serialization
	var json_str: String = JSON.stringify(data)
	assert_false(json_str.is_empty())
	var parsed: Variant = JSON.parse_string(json_str)
	assert_not_null(parsed)

	# Reset and restore
	OutingManager.reset_state()
	assert_false(OutingManager.is_prep_active())

	OutingManager.from_dict(parsed as Dictionary)
	assert_true(OutingManager.is_prep_active())
	assert_true(OutingManager.is_late())
	assert_eq(OutingManager.active_departure_min, 600)
	assert_true(GameClock.has_countdown(&"outing_late_grace_deadline"))
	assert_eq(GameClock.remaining(&"outing_late_grace_deadline"), 15)

	# Advance remaining 15 minutes to grace end -> missed
	watch_signals(OutingManager)
	GameClock.advance_minutes(15)
	assert_signal_emitted(OutingManager, "outing_missed")
	assert_false(OutingManager.is_prep_active())


func test_front_door_prompt_and_interaction() -> void:
	var door: FrontDoor = front_door_scene.instantiate() as FrontDoor
	add_child_autoqfree(door)

	# Initially no active outing
	assert_eq(door.interactable.prompt_text, "Nothing planned")

	# Schedule outing and enter prep
	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(510 - GameClock.now_minutes)  # prep starts
	door.update_prompt()
	assert_true(door.interactable.prompt_text.contains("Girls' Day Out"))

	# Interacting opens DepartureSummary modal
	var dummy_actor: Node3D = Node3D.new()
	add_child_autoqfree(dummy_actor)
	door.interactable.interact(dummy_actor)

	assert_true(door.departure_summary.is_open)
	assert_true(GameClock.has_pause_reason(&"modal"))

	# Closing modal resumes game clock
	door.departure_summary.close()
	assert_false(door.departure_summary.is_open)
	assert_false(GameClock.has_pause_reason(&"modal"))


func test_departure_summary_ui_elements_and_confirm() -> void:
	var summary: DepartureSummary = departure_summary_scene.instantiate() as DepartureSummary
	add_child_autoqfree(summary)

	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(510 - GameClock.now_minutes)  # prep active

	watch_signals(summary)
	summary.open()

	assert_true(summary.is_open)
	assert_true(summary.modal_panel.visible)
	assert_true(summary.title_label.text.contains("GIRLS' DAY OUT"))
	assert_not_null(summary.outcome_badge.text)
	assert_true(summary.cost_label.text.contains("€30.00"))

	# Confirm button emits confirmed and closes modal
	summary.confirm_button.emit_signal("pressed")
	assert_signal_emitted(summary, "confirmed")
	assert_false(summary.is_open)
	assert_false(GameClock.has_pause_reason(&"modal"))


func test_date_night_pass_and_fail_resolution() -> void:
	# 1. Date night PASS resolution
	StatusManager.set_value(Enums.Stat.HYGIENE, 100.0)
	StatusManager.set_value(Enums.Stat.SANITY, 40.0)
	FinanceManager.wallet_cents = 10000
	var chic_top: ClothingItem = load("res://data/clothing/top/top_chic_blouse.tres") as ClothingItem
	InventoryManager.equip(chic_top)
	var glam_look: MakeupLook = load("res://data/looks/glam.tres") as MakeupLook
	InventoryManager.set_look(glam_look)
	OutingManager.set_affinity("Liam", 10)

	OutingManager.schedule(date_night, 600, "Liam")
	GameClock.advance_minutes(480 - GameClock.now_minutes)  # prep starts

	var eval_res: Dictionary = OutingManager.evaluate()
	assert_eq(eval_res["result"], Enums.OutingResult.PASS)

	var res: Dictionary = OutingManager.depart()
	assert_eq(res["result"], Enums.OutingResult.PASS)
	assert_eq(FinanceManager.wallet_cents, 5000)  # Charged €50
	assert_eq(OutingManager.get_affinity("Liam"), 30)  # 10 + 20 = 30
	assert_almost_eq(StatusManager.get_value(Enums.Stat.SANITY), 64.8, 0.5)  # +25 instant sanity minus slight decay during skip

	# 2. Date night FAIL resolution
	OutingManager.reset_state()
	GameClock.reset_state()
	StatusManager.set_value(Enums.Stat.HYGIENE, 0.0)
	StatusManager.set_value(Enums.Stat.SANITY, 50.0)
	FinanceManager.wallet_cents = 1000
	InventoryManager.equipped.clear()
	InventoryManager.clear_look()
	OutingManager.set_affinity("Liam", 30)

	OutingManager.schedule(date_night, 600, "Liam")
	GameClock.advance_minutes(480 - GameClock.now_minutes)

	var fail_eval: Dictionary = OutingManager.evaluate()
	assert_eq(fail_eval["result"], Enums.OutingResult.FAIL)

	var fail_res: Dictionary = OutingManager.depart()
	assert_eq(fail_res["result"], Enums.OutingResult.FAIL)
	assert_eq(OutingManager.get_affinity("Liam"), 15)  # 30 - 15 = 15
	assert_almost_eq(StatusManager.get_value(Enums.Stat.SANITY), 27.12, 0.5)  # -20 instant sanity minus decay during skip


func test_hud_late_banner_and_updates() -> void:
	var hud_scene: PackedScene = load("res://ui/hud/hud.tscn") as PackedScene
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autoqfree(hud)

	assert_false(hud.is_late_banner_visible())

	OutingManager.schedule(girls_day_out, 600, "Chloe")
	GameClock.advance_minutes(510 - GameClock.now_minutes)  # prep active
	assert_false(hud.is_late_banner_visible())

	# Advance past departure deadline into late grace (610 min)
	GameClock.advance_minutes(100)  # now 610
	assert_true(OutingManager.is_late())
	assert_true(hud.is_late_banner_visible(), "Late banner should show on HUD when player is late")

	# Depart outing
	OutingManager.depart()
	assert_false(hud.is_late_banner_visible(), "Late banner should hide after departure")
