extends GutTest

func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()

func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()

func test_default_values_and_config() -> void:
	assert_eq(StatusManager.get_value(Enums.Stat.SANITY), 80.0, "Sanity default start value")
	assert_eq(StatusManager.get_value(Enums.Stat.HEALTH), 90.0, "Health default start value")
	assert_eq(StatusManager.get_value(Enums.Stat.HYGIENE), 80.0, "Hygiene default start value")
	assert_eq(StatusManager.get_value(Enums.Stat.RAGE), 10.0, "Rage default start value")

	assert_eq(StatusManager.get_max(Enums.Stat.SANITY), 100.0, "Sanity default max")
	assert_eq(StatusManager.get_max(Enums.Stat.HEALTH), 100.0, "Health default max")
	assert_eq(StatusManager.get_max(Enums.Stat.HYGIENE), 100.0, "Hygiene default max")
	assert_eq(StatusManager.get_max(Enums.Stat.RAGE), 100.0, "Rage default max")

	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), -1.5, 1e-4)
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.HEALTH), -1.0, 1e-4)
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.HYGIENE), -2.0, 1e-4)
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.RAGE), -0.5, 1e-4)

func test_rate_formula_with_mixed_rate_add_and_rate_mul() -> void:
	# Base sanity rate is -1.5/h.
	# Formula: (base_rate + Σ RATE_ADD) * Π RATE_MUL
	var add1: StatModifier = StatModifier.new()
	add1.stat = Enums.Stat.SANITY
	add1.kind = Enums.ModifierKind.RATE_ADD
	add1.value = -2.5
	add1.source_id = &"source_add1"
	add1.duration_min = -1
	StatusManager.add_modifier(add1)
	# (-1.5 + (-2.5)) = -4.0
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), -4.0, 1e-4)

	var mul1: StatModifier = StatModifier.new()
	mul1.stat = Enums.Stat.SANITY
	mul1.kind = Enums.ModifierKind.RATE_MUL
	mul1.value = 1.5
	mul1.source_id = &"source_mul1"
	mul1.duration_min = -1
	StatusManager.add_modifier(mul1)
	# -4.0 * 1.5 = -6.0
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), -6.0, 1e-4)

	var add2: StatModifier = StatModifier.new()
	add2.stat = Enums.Stat.SANITY
	add2.kind = Enums.ModifierKind.RATE_ADD
	add2.value = 1.0
	add2.source_id = &"source_add2"
	add2.duration_min = -1
	StatusManager.add_modifier(add2)
	# (-4.0 + 1.0) * 1.5 = -3.0 * 1.5 = -4.5
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), -4.5, 1e-4)

	var mul2: StatModifier = StatModifier.new()
	mul2.stat = Enums.Stat.SANITY
	mul2.kind = Enums.ModifierKind.RATE_MUL
	mul2.value = 2.0
	mul2.source_id = &"source_mul2"
	mul2.duration_min = -1
	StatusManager.add_modifier(mul2)
	# (-3.0) * 1.5 * 2.0 = -9.0
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), -9.0, 1e-4)

func test_instant_modifier_applies_once_and_is_not_stored() -> void:
	StatusManager.set_value(Enums.Stat.SANITY, 80.0)

	var changed_signals: Array[Dictionary] = []
	StatusManager.stat_changed.connect(func(stat: Enums.Stat, val: float, delta: float) -> void:
		changed_signals.append({"stat": stat, "val": val, "delta": delta})
	)

	var instant_mod: StatModifier = StatModifier.new()
	instant_mod.stat = Enums.Stat.SANITY
	instant_mod.kind = Enums.ModifierKind.INSTANT
	instant_mod.value = -15.0
	instant_mod.source_id = &"coffee_crash"
	instant_mod.duration_min = -1

	StatusManager.add_modifier(instant_mod)

	assert_eq(StatusManager.get_value(Enums.Stat.SANITY), 65.0, "Value should drop by 15 immediately")
	assert_eq(StatusManager.get_modifiers().size(), 0, "Instant modifiers must not be stored")
	assert_eq(changed_signals.size(), 1)
	assert_eq(changed_signals[0]["delta"], -15.0)

	# Advancing time applies only base decay (-1.5/h = -0.025/min), INSTANT does not re-apply
	GameClock.advance_minutes(10)
	assert_almost_eq(StatusManager.get_value(Enums.Stat.SANITY), 65.0 - (0.025 * 10), 1e-4)

func test_cap_modifier_clamps_value_and_max() -> void:
	StatusManager.set_value(Enums.Stat.HEALTH, 90.0)

	var cap1: StatModifier = StatModifier.new()
	cap1.stat = Enums.Stat.HEALTH
	cap1.kind = Enums.ModifierKind.CAP
	cap1.value = 70.0
	cap1.source_id = &"illness"
	cap1.duration_min = -1

	StatusManager.add_modifier(cap1)
	assert_eq(StatusManager.get_max(Enums.Stat.HEALTH), 70.0, "Max should be clamped to 70")
	assert_eq(StatusManager.get_value(Enums.Stat.HEALTH), 70.0, "Value should be clamped immediately to 70")

	StatusManager.set_value(Enums.Stat.HEALTH, 85.0)
	assert_eq(StatusManager.get_value(Enums.Stat.HEALTH), 70.0, "set_value cannot exceed effective_max")

	var cap2: StatModifier = StatModifier.new()
	cap2.stat = Enums.Stat.HEALTH
	cap2.kind = Enums.ModifierKind.CAP
	cap2.value = 50.0
	cap2.source_id = &"fever"
	cap2.duration_min = -1

	StatusManager.add_modifier(cap2)
	assert_eq(StatusManager.get_max(Enums.Stat.HEALTH), 50.0, "Max should be min(STAT_MAX, all CAP values)")
	assert_eq(StatusManager.get_value(Enums.Stat.HEALTH), 50.0, "Value clamped to lower cap")

	StatusManager.remove_by_source(&"fever")
	assert_eq(StatusManager.get_max(Enums.Stat.HEALTH), 70.0, "Max restored to cap1 value after removing cap2")
	assert_eq(StatusManager.get_value(Enums.Stat.HEALTH), 50.0, "Value remains valid")

	StatusManager.remove_by_source(&"illness")
	assert_eq(StatusManager.get_max(Enums.Stat.HEALTH), 100.0, "Max restored to STAT_MAX when all caps removed")

func test_expiry_at_exactly_expires_at() -> void:
	GameClock.now_minutes = 420
	var mod: StatModifier = StatModifier.new()
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.RATE_ADD
	mod.value = 6.0
	mod.source_id = &"cuddle"
	mod.duration_min = 5 # Expires at 425

	StatusManager.add_modifier(mod)
	assert_eq(StatusManager.get_modifiers().size(), 1)
	assert_eq(StatusManager.get_modifier_expires_at(StatusManager.get_modifiers()[0]), 425)

	var mod_changed_emitted: Array[bool] = [false]
	StatusManager.modifiers_changed.connect(func() -> void: mod_changed_emitted[0] = true)

	GameClock.advance_minutes(4) # now 424
	assert_eq(StatusManager.get_modifiers().size(), 1, "Modifier still active at 424")
	assert_false(mod_changed_emitted[0])

	GameClock.advance_minutes(1) # now 425
	assert_eq(StatusManager.get_modifiers().size(), 0, "Modifier expired and removed at exactly 425")
	assert_true(mod_changed_emitted[0], "modifiers_changed emitted on expiry")

func test_remove_by_source_removes_only_that_source() -> void:
	var mod_a1: StatModifier = StatModifier.new()
	mod_a1.stat = Enums.Stat.SANITY
	mod_a1.kind = Enums.ModifierKind.RATE_ADD
	mod_a1.value = 1.0
	mod_a1.source_id = &"source_a"
	mod_a1.duration_min = -1

	var mod_b: StatModifier = StatModifier.new()
	mod_b.stat = Enums.Stat.HEALTH
	mod_b.kind = Enums.ModifierKind.RATE_ADD
	mod_b.value = 2.0
	mod_b.source_id = &"source_b"
	mod_b.duration_min = -1

	var mod_a2: StatModifier = StatModifier.new()
	mod_a2.stat = Enums.Stat.HYGIENE
	mod_a2.kind = Enums.ModifierKind.RATE_ADD
	mod_a2.value = 3.0
	mod_a2.source_id = &"source_a"
	mod_a2.duration_min = -1

	StatusManager.add_modifier(mod_a1)
	StatusManager.add_modifier(mod_b)
	StatusManager.add_modifier(mod_a2)
	assert_eq(StatusManager.get_modifiers().size(), 3)

	StatusManager.remove_by_source(&"source_a")
	var remaining: Array[StatModifier] = StatusManager.get_modifiers()
	assert_eq(remaining.size(), 1, "Only source_b modifier should remain")
	assert_eq(remaining[0].source_id, &"source_b")

func test_replace_not_stack_rule() -> void:
	GameClock.now_minutes = 420

	var mod1: StatModifier = StatModifier.new()
	mod1.stat = Enums.Stat.SANITY
	mod1.kind = Enums.ModifierKind.RATE_ADD
	mod1.value = 2.0
	mod1.source_id = &"coffee"
	mod1.duration_min = 10 # expires at 430

	StatusManager.add_modifier(mod1)
	assert_eq(StatusManager.get_modifiers().size(), 1)
	assert_eq(StatusManager.get_modifier_expires_at(StatusManager.get_modifiers()[0]), 430)

	GameClock.advance_minutes(5) # now 425

	var mod2: StatModifier = StatModifier.new()
	mod2.stat = Enums.Stat.SANITY
	mod2.kind = Enums.ModifierKind.RATE_ADD
	mod2.value = 3.0
	mod2.source_id = &"coffee" # same source, stat, kind
	mod2.duration_min = 10 # should refresh to 425 + 10 = 435

	StatusManager.add_modifier(mod2)
	assert_eq(StatusManager.get_modifiers().size(), 1, "Should replace, not stack")
	var active: StatModifier = StatusManager.get_modifiers()[0]
	assert_eq(active.value, 3.0, "Value replaced, not summed")
	assert_eq(StatusManager.get_modifier_expires_at(active), 435, "Duration refreshed to 435")

func test_skip_equals_advance_minutes_plain_decay() -> void:
	# Run 1: advance_minutes(60)
	GameClock.now_minutes = 420
	StatusManager.reset_state()
	GameClock.advance_minutes(60)

	var s1: float = StatusManager.get_value(Enums.Stat.SANITY)
	var h1: float = StatusManager.get_value(Enums.Stat.HEALTH)
	var hy1: float = StatusManager.get_value(Enums.Stat.HYGIENE)
	var r1: float = StatusManager.get_value(Enums.Stat.RAGE)

	# Run 2: skip(60)
	GameClock.now_minutes = 420
	StatusManager.reset_state()
	GameClock.skip(60)

	var s2: float = StatusManager.get_value(Enums.Stat.SANITY)
	var h2: float = StatusManager.get_value(Enums.Stat.HEALTH)
	var hy2: float = StatusManager.get_value(Enums.Stat.HYGIENE)
	var r2: float = StatusManager.get_value(Enums.Stat.RAGE)

	assert_almost_eq(s2, s1, 1e-3, "Sanity skip vs advance")
	assert_almost_eq(h2, h1, 1e-3, "Health skip vs advance")
	assert_almost_eq(hy2, hy1, 1e-3, "Hygiene skip vs advance")
	assert_almost_eq(r2, r1, 1e-3, "Rage skip vs advance")

func test_skip_equals_advance_minutes_modifier_expiring_mid_skip() -> void:
	# Run 1: 60 minutes with advance_minutes and mod expiring after 25 min
	GameClock.now_minutes = 420
	StatusManager.reset_state()

	var mod1: StatModifier = StatModifier.new()
	mod1.stat = Enums.Stat.SANITY
	mod1.kind = Enums.ModifierKind.RATE_ADD
	mod1.value = -3.0
	mod1.source_id = &"stress"
	mod1.duration_min = 25 # expires at 445
	StatusManager.add_modifier(mod1)

	GameClock.advance_minutes(60) # reaches 480
	var s1: float = StatusManager.get_value(Enums.Stat.SANITY)
	assert_eq(StatusManager.get_modifiers().size(), 0)

	# Run 2: 60 minutes with skip and same mod
	GameClock.now_minutes = 420
	StatusManager.reset_state()

	var mod2: StatModifier = StatModifier.new()
	mod2.stat = Enums.Stat.SANITY
	mod2.kind = Enums.ModifierKind.RATE_ADD
	mod2.value = -3.0
	mod2.source_id = &"stress"
	mod2.duration_min = 25 # expires at 445
	StatusManager.add_modifier(mod2)

	GameClock.skip(60) # reaches 480
	var s2: float = StatusManager.get_value(Enums.Stat.SANITY)
	assert_eq(StatusManager.get_modifiers().size(), 0)

	assert_almost_eq(s2, s1, 1e-3, "Sanity should match within 1e-3 when mod expires mid-skip")

func test_skip_equals_advance_minutes_stat_hitting_zero() -> void:
	# Sanity starts at 1.0. With -1.5/h (-0.025/min), it reaches 0 in 40 minutes.
	# Run 1: advance_minutes(60)
	GameClock.now_minutes = 420
	StatusManager.reset_state()
	StatusManager.set_value(Enums.Stat.SANITY, 1.0)

	var depleted_emitted: Array[bool] = [false]
	StatusManager.stat_depleted.connect(func(st: Enums.Stat) -> void:
		if st == Enums.Stat.SANITY:
			depleted_emitted[0] = true
	)

	GameClock.advance_minutes(60)
	var s1: float = StatusManager.get_value(Enums.Stat.SANITY)
	assert_eq(s1, 0.0)
	assert_true(depleted_emitted[0])

	# Run 2: skip(60)
	GameClock.now_minutes = 420
	StatusManager.reset_state()
	StatusManager.set_value(Enums.Stat.SANITY, 1.0)

	var depleted_emitted_skip: Array[bool] = [false]
	StatusManager.stat_depleted.connect(func(st: Enums.Stat) -> void:
		if st == Enums.Stat.SANITY:
			depleted_emitted_skip[0] = true
	)

	GameClock.skip(60)
	var s2: float = StatusManager.get_value(Enums.Stat.SANITY)
	assert_eq(s2, 0.0)
	assert_true(depleted_emitted_skip[0])

	assert_almost_eq(s2, s1, 1e-3, "Skip hitting 0 matches advance_minutes hitting 0")

func test_tres_modifier_unchanged_after_add_expire() -> void:
	var tres_mod: StatModifier = StatModifier.new()
	tres_mod.stat = Enums.Stat.SANITY
	tres_mod.kind = Enums.ModifierKind.RATE_ADD
	tres_mod.value = 4.0
	tres_mod.source_id = &"tea"
	tres_mod.duration_min = 5
	tres_mod.label = "Chamomile Tea"

	StatusManager.add_modifier(tres_mod)
	GameClock.advance_minutes(10) # Expire

	# Assert that original tres_mod was not mutated
	assert_eq(tres_mod.stat, Enums.Stat.SANITY)
	assert_eq(tres_mod.kind, Enums.ModifierKind.RATE_ADD)
	assert_eq(tres_mod.value, 4.0)
	assert_eq(tres_mod.source_id, &"tea")
	assert_eq(tres_mod.duration_min, 5)
	assert_eq(tres_mod.label, "Chamomile Tea")

func test_to_dict_json_from_dict_round_trip() -> void:
	GameClock.now_minutes = 420
	StatusManager.reset_state()

	StatusManager.set_value(Enums.Stat.SANITY, 72.5)
	StatusManager.set_value(Enums.Stat.HEALTH, 64.0)
	StatusManager.set_value(Enums.Stat.HYGIENE, 88.0)
	StatusManager.set_value(Enums.Stat.RAGE, 35.0)

	var mod: StatModifier = StatModifier.new()
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.RATE_ADD
	mod.value = 5.0
	mod.source_id = &"rest"
	mod.duration_min = 30 # expires at 450
	mod.label = "Power Nap"
	StatusManager.add_modifier(mod)

	# Advance 10 minutes to 430 -> remaining duration is 20 minutes (expires at 450)
	GameClock.advance_minutes(10)
	assert_eq(GameClock.now_minutes, 430)

	var pre_s: float = StatusManager.get_value(Enums.Stat.SANITY)
	var pre_h: float = StatusManager.get_value(Enums.Stat.HEALTH)
	var pre_hy: float = StatusManager.get_value(Enums.Stat.HYGIENE)
	var pre_r: float = StatusManager.get_value(Enums.Stat.RAGE)

	var data: Dictionary = StatusManager.to_dict()
	var json_str: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary)

	# Reset and restore
	StatusManager.reset_state()
	StatusManager.from_dict(parsed as Dictionary)

	assert_almost_eq(StatusManager.get_value(Enums.Stat.SANITY), pre_s, 1e-4)
	assert_almost_eq(StatusManager.get_value(Enums.Stat.HEALTH), pre_h, 1e-4)
	assert_almost_eq(StatusManager.get_value(Enums.Stat.HYGIENE), pre_hy, 1e-4)
	assert_almost_eq(StatusManager.get_value(Enums.Stat.RAGE), pre_r, 1e-4)

	var mods: Array[StatModifier] = StatusManager.get_modifiers()
	assert_eq(mods.size(), 1, "Restored active modifier count")
	assert_eq(mods[0].source_id, &"rest")
	assert_eq(mods[0].label, "Power Nap")
	assert_eq(StatusManager.get_modifier_expires_at(mods[0]), 450, "Remaining expires_at preserved")

	# Advance 20 minutes to 450 -> mod should expire exactly at 450
	GameClock.advance_minutes(20)
	assert_eq(GameClock.now_minutes, 450)
	assert_eq(StatusManager.get_modifiers().size(), 0, "Modifier expired at restored expiry minute")

func test_signals_depleted_and_maxed() -> void:
	StatusManager.reset_state()

	var depleted_stat: Array[Enums.Stat] = []
	var maxed_stat: Array[Enums.Stat] = []

	StatusManager.stat_depleted.connect(func(s: Enums.Stat) -> void: depleted_stat.append(s))
	StatusManager.stat_maxed.connect(func(s: Enums.Stat) -> void: maxed_stat.append(s))

	# Bring sanity to 0 via instant
	var crash: StatModifier = StatModifier.new()
	crash.stat = Enums.Stat.SANITY
	crash.kind = Enums.ModifierKind.INSTANT
	crash.value = -100.0
	crash.source_id = &"crash"
	StatusManager.add_modifier(crash)

	assert_eq(StatusManager.get_value(Enums.Stat.SANITY), 0.0)
	assert_eq(depleted_stat, [Enums.Stat.SANITY])

	# Fill health to max via instant
	var heal: StatModifier = StatModifier.new()
	heal.stat = Enums.Stat.HEALTH
	heal.kind = Enums.ModifierKind.INSTANT
	heal.value = 50.0 # From 90 to 100 max
	heal.source_id = &"meds"
	StatusManager.add_modifier(heal)

	assert_eq(StatusManager.get_value(Enums.Stat.HEALTH), 100.0)
	assert_eq(maxed_stat, [Enums.Stat.HEALTH])

func test_get_modifiers_by_stat_filter() -> void:
	var mod_sanity: StatModifier = StatModifier.new()
	mod_sanity.stat = Enums.Stat.SANITY
	mod_sanity.kind = Enums.ModifierKind.RATE_ADD
	mod_sanity.value = 1.0
	mod_sanity.source_id = &"s1"

	var mod_health: StatModifier = StatModifier.new()
	mod_health.stat = Enums.Stat.HEALTH
	mod_health.kind = Enums.ModifierKind.RATE_ADD
	mod_health.value = 2.0
	mod_health.source_id = &"h1"

	StatusManager.add_modifier(mod_sanity)
	StatusManager.add_modifier(mod_health)

	assert_eq(StatusManager.get_modifiers().size(), 2)
	assert_eq(StatusManager.get_modifiers(Enums.Stat.SANITY).size(), 1)
	assert_eq(StatusManager.get_modifiers(Enums.Stat.HEALTH).size(), 1)
	assert_eq(StatusManager.get_modifiers(Enums.Stat.HYGIENE).size(), 0)
