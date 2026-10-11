extends GutTest

func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()

func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()

func test_hud_initial_state() -> void:
	var hud: HUD = load("res://ui/hud/hud.tscn").instantiate()
	add_child_autoqfree(hud)

	assert_not_null(hud.sanity_bar)
	assert_not_null(hud.health_bar)
	assert_not_null(hud.hygiene_bar)
	assert_not_null(hud.rage_bar)

	assert_almost_eq(hud.sanity_bar.get_stat_value(), 80.0, 1e-4)
	assert_almost_eq(hud.health_bar.get_stat_value(), 90.0, 1e-4)
	assert_almost_eq(hud.hygiene_bar.get_stat_value(), 80.0, 1e-4)
	assert_almost_eq(hud.rage_bar.get_stat_value(), 10.0, 1e-4)

	assert_eq(hud.get_clock_text(), "Day 1 · 07:00")
	assert_eq(hud.get_wallet_text(), "€250.00")
	assert_true(hud.get_phase_badge_text().begins_with("Follicular"))
	assert_false(hud.is_modifiers_expanded())
	assert_false(hud.modifiers_panel.visible)

func test_hud_signal_driven_stat_change() -> void:
	var hud: HUD = load("res://ui/hud/hud.tscn").instantiate()
	add_child_autoqfree(hud)

	StatusManager.set_value(Enums.Stat.SANITY, 42.0)
	assert_almost_eq(hud.sanity_bar.get_stat_value(), 42.0, 1e-4)

	StatusManager.set_value(Enums.Stat.RAGE, 77.0)
	assert_almost_eq(hud.rage_bar.get_stat_value(), 77.0, 1e-4)

func test_hud_signal_driven_clock_updates() -> void:
	var hud: HUD = load("res://ui/hud/hud.tscn").instantiate()
	add_child_autoqfree(hud)

	GameClock.advance_minutes(30)
	assert_eq(hud.get_clock_text(), "Day 1 · 07:30")

	GameClock.skip(1440)
	assert_eq(hud.get_clock_text(), "Day 2 · 07:30")

func test_hud_signal_driven_wallet_updates() -> void:
	var hud: HUD = load("res://ui/hud/hud.tscn").instantiate()
	add_child_autoqfree(hud)

	FinanceManager.spend(5000, &"groceries", "Shop trip")
	assert_eq(hud.get_wallet_text(), "€200.00")

	FinanceManager.charge_bill(30000, &"urgent", "Overdraft bill")
	assert_eq(hud.get_wallet_text(), "−€100.00")

func test_hud_phase_badge_and_modifier_expansion() -> void:
	var hud: HUD = load("res://ui/hud/hud.tscn").instantiate()
	add_child_autoqfree(hud)

	# Initially collapsed
	assert_false(hud.is_modifiers_expanded())
	assert_true(hud.get_phase_badge_text().ends_with("▼"))

	# Expand
	hud.toggle_modifiers_expanded()
	assert_true(hud.is_modifiers_expanded())
	assert_true(hud.modifiers_panel.visible)
	assert_true(hud.get_phase_badge_text().ends_with("▲"))

	# Check modifier descriptions match active modifiers
	var descs: Array[String] = hud.get_active_modifier_descriptions()
	var expected_mods: Array[StatModifier] = StatusManager.get_modifiers()
	assert_eq(descs.size(), expected_mods.size())
	for mod: StatModifier in expected_mods:
		assert_true(descs.has(mod.describe()), "Modifiers list should contain '%s'" % mod.describe())

	# Force phase change to Luteal
	CycleManager.force_phase(Enums.CyclePhase.LUTEAL)
	assert_true(hud.get_phase_badge_text().begins_with("Luteal"))

	descs = hud.get_active_modifier_descriptions()
	expected_mods = StatusManager.get_modifiers()
	assert_eq(descs.size(), expected_mods.size())
	for mod: StatModifier in expected_mods:
		assert_true(descs.has(mod.describe()))

	# Test adding non-cycle modifier (e.g. debt stress)
	FinanceManager.charge_bill(40000, &"debt", "Force debt")
	descs = hud.get_active_modifier_descriptions()
	var found_debt: bool = false
	for d: String in descs:
		if d.begins_with("Sanity") and d.contains("−1"):
			found_debt = true
			break
	assert_true(found_debt, "Active modifier list must include debt modifier from all sources")

func test_hud_28_day_cycle_walkthrough() -> void:
	var hud: HUD = load("res://ui/hud/hud.tscn").instantiate()
	add_child_autoqfree(hud)

	var phases_seen: Array[String] = []

	# Day 1 starts in Follicular
	var curr_phase: String = hud.get_phase_badge_text().split(" ")[0]
	phases_seen.append(curr_phase)

	# Advance 28 days in 1-day skips
	for i: int in range(28):
		GameClock.skip(1440)
		var p: String = hud.get_phase_badge_text().split(" ")[0]
		if not phases_seen.has(p):
			phases_seen.append(p)

	assert_true(phases_seen.has("Follicular"))
	assert_true(phases_seen.has("Ovulatory"))
	assert_true(phases_seen.has("Luteal"))
	assert_true(phases_seen.has("Menstrual"))
	assert_eq(phases_seen.size(), 4, "Should have walked through all 4 cycle phases")
