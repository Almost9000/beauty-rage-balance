extends GutTest

func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()

func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()

func test_default_phase_lengths_and_initial_state() -> void:
	var lengths: Dictionary = CycleManager.get_scaled_phase_lengths(28)
	assert_eq(lengths[Enums.CyclePhase.MENSTRUAL], 5, "Menstrual default length should be 5")
	assert_eq(lengths[Enums.CyclePhase.FOLLICULAR], 8, "Follicular default length should be 8")
	assert_eq(lengths[Enums.CyclePhase.OVULATORY], 3, "Ovulatory default length should be 3")
	assert_eq(lengths[Enums.CyclePhase.LUTEAL], 12, "Luteal default length should be 12")
	assert_eq(lengths[Enums.CyclePhase.MENSTRUAL] + lengths[Enums.CyclePhase.FOLLICULAR] + lengths[Enums.CyclePhase.OVULATORY] + lengths[Enums.CyclePhase.LUTEAL], 28)

	# New game: day 1 is follicular day 1
	assert_eq(CycleManager.current_phase, Enums.CyclePhase.FOLLICULAR, "Day 1 should be Follicular phase")
	assert_eq(CycleManager.day_in_phase, 1, "Day in phase should be 1")
	assert_eq(CycleManager.days_until_next_phase, 7, "Days until next phase should be 7")
	assert_eq(CycleManager.cycle_start_day, -4, "Cycle start day for 28d cycle should be -4")

func test_12_day_scaling_sums_to_12_and_each_phase_ge_1() -> void:
	var lengths: Dictionary = CycleManager.get_scaled_phase_lengths(12)
	assert_eq(lengths[Enums.CyclePhase.MENSTRUAL], 2, "Menstrual 12d length should be 2")
	assert_eq(lengths[Enums.CyclePhase.FOLLICULAR], 4, "Follicular 12d length should be 4")
	assert_eq(lengths[Enums.CyclePhase.OVULATORY], 1, "Ovulatory 12d length should be 1")
	assert_eq(lengths[Enums.CyclePhase.LUTEAL], 5, "Luteal 12d length should be 5")

	var sum_days: int = lengths[Enums.CyclePhase.MENSTRUAL] + lengths[Enums.CyclePhase.FOLLICULAR] + lengths[Enums.CyclePhase.OVULATORY] + lengths[Enums.CyclePhase.LUTEAL]
	assert_eq(sum_days, 12, "Total scaled days should sum to 12")

	for phase_enum: Enums.CyclePhase in lengths:
		assert_true(lengths[phase_enum] >= 1, "Each phase length must be >= 1")

	# Test all allowable cycle lengths (12 to 40)
	for l: int in range(12, 41):
		var scaled: Dictionary = CycleManager.get_scaled_phase_lengths(l)
		var total: int = scaled[Enums.CyclePhase.MENSTRUAL] + scaled[Enums.CyclePhase.FOLLICULAR] + scaled[Enums.CyclePhase.OVULATORY] + scaled[Enums.CyclePhase.LUTEAL]
		assert_eq(total, l, "Cycle length %d should sum to %d" % [l, l])
		for p: Enums.CyclePhase in scaled:
			assert_true(scaled[p] >= 1, "Phase %d in cycle length %d must be >= 1" % [int(p), l])

func test_phase_modifiers_registered_with_source_cycle() -> void:
	# On new game (Follicular), check StatusManager modifiers
	var cycle_mods: Array[StatModifier] = []
	for mod: StatModifier in StatusManager.get_modifiers():
		if mod.source_id == &"cycle":
			cycle_mods.append(mod)

	assert_gt(cycle_mods.size(), 0, "Follicular phase should register cycle modifiers")
	var fol_data: CyclePhaseData = CycleManager.get_phase_data(Enums.CyclePhase.FOLLICULAR)
	assert_eq(cycle_mods.size(), fol_data.modifiers.size(), "All follicular modifiers should be registered")

	for mod: StatModifier in cycle_mods:
		assert_eq(mod.source_id, &"cycle")
		assert_eq(mod.duration_min, -1)

func test_force_phase_moves_cycle_start_day_and_updates_modifiers() -> void:
	watch_signals(CycleManager)

	CycleManager.force_phase(Enums.CyclePhase.LUTEAL)
	assert_signal_emitted(CycleManager, "phase_changed")
	assert_eq(CycleManager.current_phase, Enums.CyclePhase.LUTEAL)
	assert_eq(CycleManager.day_in_phase, 1)
	assert_eq(CycleManager.days_until_next_phase, 11)

	# Luteal modifiers include Rage gain ×1.3 (ADR-02)
	var cycle_mods: Array[StatModifier] = []
	for mod: StatModifier in StatusManager.get_modifiers():
		if mod.source_id == &"cycle":
			cycle_mods.append(mod)

	var found_rage_mul: bool = false
	for mod: StatModifier in cycle_mods:
		if mod.stat == Enums.Stat.RAGE and mod.kind == Enums.ModifierKind.RATE_MUL:
			assert_almost_eq(mod.value, 1.3, 1e-4)
			found_rage_mul = true
	assert_true(found_rage_mul, "Luteal should register Rage gain ×1.3 modifier")

	# Force Menstrual
	CycleManager.force_phase(Enums.CyclePhase.MENSTRUAL)
	assert_eq(CycleManager.current_phase, Enums.CyclePhase.MENSTRUAL)
	assert_eq(CycleManager.day_in_phase, 1)
	assert_eq(CycleManager.days_until_next_phase, 4)

	# Verify exactly one phase's modifiers carry source_id = &"cycle"
	cycle_mods.clear()
	for mod: StatModifier in StatusManager.get_modifiers():
		if mod.source_id == &"cycle":
			cycle_mods.append(mod)
	var men_data: CyclePhaseData = CycleManager.get_phase_data(Enums.CyclePhase.MENSTRUAL)
	assert_eq(cycle_mods.size(), men_data.modifiers.size(), "Only Menstrual modifiers should be registered")

func test_intensity_zero_neutralizes_rates_and_re_registers_immediately() -> void:
	CycleManager.force_phase(Enums.CyclePhase.LUTEAL)

	# With intensity 1.0, Luteal has Rage gain x1.3, so effective rate should be scaled
	var base_rage_rate: float = StatusManager.config.get_base_rate(Enums.Stat.RAGE)
	var full_rate: float = StatusManager.get_effective_rate(Enums.Stat.RAGE)
	assert_almost_eq(full_rate, base_rage_rate * 1.3, 1e-4)

	# Set intensity to 0.0
	GameSettings.current().symptom_intensity = 0.0

	# Rates should now be neutral (ADD 0, MUL 1) -> effective rate equals base rate
	var neutral_rate: float = StatusManager.get_effective_rate(Enums.Stat.RAGE)
	assert_almost_eq(neutral_rate, base_rage_rate, 1e-4, "Intensity 0 should leave rates neutral")

	# Check Sanity rate as well
	var base_sanity_rate: float = StatusManager.config.get_base_rate(Enums.Stat.SANITY)
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), base_sanity_rate, 1e-4)

	# Re-register immediately when intensity changes back
	GameSettings.current().symptom_intensity = 1.0
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.RAGE), base_rage_rate * 1.3, 1e-4)

func test_skip_28_days_emits_four_phase_changed_and_ends_in_start_phase() -> void:
	watch_signals(CycleManager)

	assert_eq(CycleManager.current_phase, Enums.CyclePhase.FOLLICULAR)

	# Skip 28 days (28 * 1440 minutes)
	GameClock.skip(28 * 1440)

	assert_signal_emit_count(CycleManager, "phase_changed", 4)
	assert_eq(CycleManager.current_phase, Enums.CyclePhase.FOLLICULAR, "Should end in Follicular (start phase)")
	assert_eq(CycleManager.day_in_phase, 1, "Should end on Day 1 of Follicular")

func test_has_tag_queries() -> void:
	CycleManager.force_phase(Enums.CyclePhase.FOLLICULAR)
	assert_true(CycleManager.has_tag(&"follicular"))
	assert_true(CycleManager.has_tag(&"creative"))
	assert_false(CycleManager.has_tag(&"cramps"))
	assert_false(CycleManager.has_tag(&"boundaries"))

	CycleManager.force_phase(Enums.CyclePhase.MENSTRUAL)
	assert_true(CycleManager.has_tag(&"cramps"))
	assert_true(CycleManager.has_tag(&"menstrual"))
	assert_false(CycleManager.has_tag(&"creative"))

	CycleManager.force_phase(Enums.CyclePhase.OVULATORY)
	assert_true(CycleManager.has_tag(&"peak_confidence"))
	assert_true(CycleManager.has_tag(&"charismatic"))

	CycleManager.force_phase(Enums.CyclePhase.LUTEAL)
	assert_true(CycleManager.has_tag(&"boundaries"))
	assert_true(CycleManager.has_tag(&"irritability"))

func test_json_round_trip() -> void:
	CycleManager.force_phase(Enums.CyclePhase.OVULATORY)
	var orig_phase: Enums.CyclePhase = CycleManager.current_phase
	var orig_start_day: int = CycleManager.cycle_start_day

	var data: Dictionary = CycleManager.to_dict()
	var json_str: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary)

	# Reset and restore
	CycleManager.reset_state()
	assert_eq(CycleManager.current_phase, Enums.CyclePhase.FOLLICULAR)

	CycleManager.from_dict(parsed as Dictionary)
	assert_eq(CycleManager.current_phase, orig_phase, "Phase should be preserved after round trip")
	assert_eq(CycleManager.cycle_start_day, orig_start_day, "Cycle start day should be preserved after round trip")
