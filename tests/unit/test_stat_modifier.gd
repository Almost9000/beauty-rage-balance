extends GutTest

func test_default_values() -> void:
	var mod: StatModifier = StatModifier.new()
	assert_eq(mod.stat, Enums.Stat.SANITY)
	assert_eq(mod.kind, Enums.ModifierKind.INSTANT)
	assert_eq(mod.value, 0.0)
	assert_eq(mod.source_id, &"")
	assert_eq(mod.duration_min, -1)
	assert_eq(mod.label, "")
	assert_false(mod.is_valid(), "Default modifier with empty source_id should be invalid")

func test_validity_checks() -> void:
	var mod: StatModifier = StatModifier.new()
	mod.source_id = &"test_source"
	mod.stat = Enums.Stat.HEALTH
	mod.kind = Enums.ModifierKind.RATE_ADD
	mod.value = 1.5
	mod.duration_min = 60
	assert_true(mod.is_valid(), "Configured modifier should be valid")

	var invalid_source: StatModifier = mod.duplicate() as StatModifier
	invalid_source.source_id = &""
	assert_false(invalid_source.is_valid(), "Empty source_id is invalid")

	var invalid_duration: StatModifier = mod.duplicate() as StatModifier
	invalid_duration.duration_min = -5
	assert_false(invalid_duration.is_valid(), "Duration < -1 is invalid")

	var cap_mod: StatModifier = StatModifier.new()
	cap_mod.source_id = &"cap_source"
	cap_mod.kind = Enums.ModifierKind.CAP
	cap_mod.value = 120.0
	assert_false(cap_mod.is_valid(), "CAP value > STAT_MAX is invalid")

	cap_mod.value = -5.0
	assert_false(cap_mod.is_valid(), "CAP value < 0 is invalid")

	cap_mod.value = 80.0
	assert_true(cap_mod.is_valid(), "CAP value within [0, STAT_MAX] is valid")

	var neg_mul: StatModifier = mod.duplicate() as StatModifier
	neg_mul.kind = Enums.ModifierKind.RATE_MUL
	neg_mul.value = -0.5
	assert_false(neg_mul.is_valid(), "Negative RATE_MUL value is invalid")

	var invalid_stat: StatModifier = mod.duplicate() as StatModifier
	invalid_stat.stat = 999 as Enums.Stat
	assert_false(invalid_stat.is_valid(), "Unknown stat value is invalid")

	var invalid_kind: StatModifier = mod.duplicate() as StatModifier
	invalid_kind.kind = 999 as Enums.ModifierKind
	assert_false(invalid_kind.is_valid(), "Unknown kind value is invalid")

func test_serialization_dict() -> void:
	var mod: StatModifier = StatModifier.new()
	mod.stat = Enums.Stat.RAGE
	mod.kind = Enums.ModifierKind.RATE_MUL
	mod.value = 1.35
	mod.source_id = &"test_rage_src"
	mod.duration_min = 120
	mod.label = "HUD_MOD_RAGE_BOOST"

	var dict: Dictionary = mod.to_dict()
	assert_eq(dict["stat"], int(Enums.Stat.RAGE))
	assert_eq(dict["kind"], int(Enums.ModifierKind.RATE_MUL))
	assert_almost_eq(float(dict["value"]), 1.35, 0.0001)
	assert_eq(dict["source_id"], "test_rage_src")
	assert_eq(dict["duration_min"], 120)
	assert_eq(dict["label"], "HUD_MOD_RAGE_BOOST")

	var restored: StatModifier = StatModifier.from_dict(dict)
	assert_eq(restored.stat, Enums.Stat.RAGE)
	assert_eq(restored.kind, Enums.ModifierKind.RATE_MUL)
	assert_almost_eq(restored.value, 1.35, 0.0001)
	assert_eq(restored.source_id, &"test_rage_src")
	assert_eq(restored.duration_min, 120)
	assert_eq(restored.label, "HUD_MOD_RAGE_BOOST")
	assert_true(restored.is_valid(), "Restored modifier should be valid")

func test_describe_formatting() -> void:
	var instant_add: StatModifier = StatModifier.new()
	instant_add.stat = Enums.Stat.HEALTH
	instant_add.kind = Enums.ModifierKind.INSTANT
	instant_add.value = 10.0
	assert_eq(instant_add.describe(), "Health +10")

	var rate_sub: StatModifier = StatModifier.new()
	rate_sub.stat = Enums.Stat.SANITY
	rate_sub.kind = Enums.ModifierKind.RATE_ADD
	rate_sub.value = -0.5
	assert_eq(rate_sub.describe(), "Sanity −0.5/h")

	var rate_mul: StatModifier = StatModifier.new()
	rate_mul.stat = Enums.Stat.RAGE
	rate_mul.kind = Enums.ModifierKind.RATE_MUL
	rate_mul.value = 1.3
	assert_eq(rate_mul.describe(), "Rage gain ×1.3")

	var cap_mod: StatModifier = StatModifier.new()
	cap_mod.stat = Enums.Stat.SANITY
	cap_mod.kind = Enums.ModifierKind.CAP
	cap_mod.value = 80.0
	assert_eq(cap_mod.describe(), "Sanity cap 80")

func test_scaling_instant() -> void:
	var mod: StatModifier = StatModifier.new()
	mod.source_id = &"instant_src"
	mod.stat = Enums.Stat.HEALTH
	mod.kind = Enums.ModifierKind.INSTANT
	mod.value = 20.0

	var s0: StatModifier = mod.scaled(0.0)
	assert_almost_eq(s0.value, 0.0, 0.0001)
	assert_almost_eq(mod.value, 20.0, 0.0001, "Source must not be mutated")

	var s_half: StatModifier = mod.scaled(0.5)
	assert_almost_eq(s_half.value, 10.0, 0.0001)
	assert_almost_eq(mod.value, 20.0, 0.0001, "Source must not be mutated")

	var s1: StatModifier = mod.scaled(1.0)
	assert_almost_eq(s1.value, 20.0, 0.0001)
	assert_almost_eq(mod.value, 20.0, 0.0001, "Source must not be mutated")

func test_scaling_rate_add() -> void:
	var mod: StatModifier = StatModifier.new()
	mod.source_id = &"rate_add_src"
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.RATE_ADD
	mod.value = -2.0

	var s0: StatModifier = mod.scaled(0.0)
	assert_almost_eq(s0.value, 0.0, 0.0001)
	assert_almost_eq(mod.value, -2.0, 0.0001, "Source must not be mutated")

	var s_half: StatModifier = mod.scaled(0.5)
	assert_almost_eq(s_half.value, -1.0, 0.0001)
	assert_almost_eq(mod.value, -2.0, 0.0001, "Source must not be mutated")

	var s1: StatModifier = mod.scaled(1.0)
	assert_almost_eq(s1.value, -2.0, 0.0001)
	assert_almost_eq(mod.value, -2.0, 0.0001, "Source must not be mutated")

func test_scaling_rate_mul() -> void:
	var mod: StatModifier = StatModifier.new()
	mod.source_id = &"rate_mul_src"
	mod.stat = Enums.Stat.RAGE
	mod.kind = Enums.ModifierKind.RATE_MUL
	mod.value = 1.4

	# formula: 1 + (value - 1) * k
	var s0: StatModifier = mod.scaled(0.0)
	assert_almost_eq(s0.value, 1.0, 0.0001)
	assert_almost_eq(mod.value, 1.4, 0.0001, "Source must not be mutated")

	var s_half: StatModifier = mod.scaled(0.5)
	assert_almost_eq(s_half.value, 1.2, 0.0001)
	assert_almost_eq(mod.value, 1.4, 0.0001, "Source must not be mutated")

	var s1: StatModifier = mod.scaled(1.0)
	assert_almost_eq(s1.value, 1.4, 0.0001)
	assert_almost_eq(mod.value, 1.4, 0.0001, "Source must not be mutated")

func test_scaling_cap() -> void:
	var mod: StatModifier = StatModifier.new()
	mod.source_id = &"cap_src"
	mod.stat = Enums.Stat.SANITY
	mod.kind = Enums.ModifierKind.CAP
	mod.value = 80.0

	# formula: STAT_MAX - (STAT_MAX - value) * k
	var s0: StatModifier = mod.scaled(0.0)
	assert_almost_eq(s0.value, 100.0, 0.0001)
	assert_almost_eq(mod.value, 80.0, 0.0001, "Source must not be mutated")

	var s_half: StatModifier = mod.scaled(0.5)
	assert_almost_eq(s_half.value, 90.0, 0.0001)
	assert_almost_eq(mod.value, 80.0, 0.0001, "Source must not be mutated")

	var s1: StatModifier = mod.scaled(1.0)
	assert_almost_eq(s1.value, 80.0, 0.0001)
	assert_almost_eq(mod.value, 80.0, 0.0001, "Source must not be mutated")
