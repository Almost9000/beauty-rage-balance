extends GutTest

func test_stat_bar_initialization() -> void:
	var bar: StatBar = load("res://ui/widgets/stat_bar.tscn").instantiate()
	bar.stat_type = Enums.Stat.SANITY
	add_child_autoqfree(bar)

	assert_eq(bar.stat_type, Enums.Stat.SANITY)
	assert_eq(bar.stat_label.text, "Sanity")
	assert_eq(bar.trend_label.text, "→")
	assert_eq(bar.progress_bar.max_value, 100.0)

func test_stat_bar_set_value() -> void:
	var bar: StatBar = load("res://ui/widgets/stat_bar.tscn").instantiate()
	add_child_autoqfree(bar)

	bar.set_value(75.0, 100.0, false)
	assert_almost_eq(bar.get_stat_value(), 75.0, 1e-4)
	assert_almost_eq(bar.progress_bar.value, 75.0, 1e-4)
	assert_eq(bar.value_label.text, "75 / 100")

	# Test clamping
	bar.set_value(150.0, 100.0, false)
	assert_almost_eq(bar.get_stat_value(), 100.0, 1e-4)

	bar.set_value(-20.0, 100.0, false)
	assert_almost_eq(bar.get_stat_value(), 0.0, 1e-4)

func test_stat_bar_effective_rate_trend() -> void:
	var bar: StatBar = load("res://ui/widgets/stat_bar.tscn").instantiate()
	add_child_autoqfree(bar)

	bar.set_effective_rate(1.5)
	assert_eq(bar.get_trend_text(), "↑", "Positive rate should show up arrow")
	assert_almost_eq(bar.get_effective_rate(), 1.5, 1e-4)

	bar.set_effective_rate(-2.0)
	assert_eq(bar.get_trend_text(), "↓", "Negative rate should show down arrow")
	assert_almost_eq(bar.get_effective_rate(), -2.0, 1e-4)

	bar.set_effective_rate(0.0)
	assert_eq(bar.get_trend_text(), "→", "Zero rate should show neutral arrow")
	assert_almost_eq(bar.get_effective_rate(), 0.0, 1e-4)

func test_stat_bar_type_switching() -> void:
	var bar: StatBar = load("res://ui/widgets/stat_bar.tscn").instantiate()
	add_child_autoqfree(bar)

	for stat: Enums.Stat in [Enums.Stat.SANITY, Enums.Stat.HEALTH, Enums.Stat.HYGIENE, Enums.Stat.RAGE]:
		bar.set_stat_type(stat)
		assert_eq(bar.stat_type, stat)
		assert_eq(bar.stat_label.text, StatBar.STAT_NAMES[stat])
		var fill_style: StyleBoxFlat = bar.progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
		assert_not_null(fill_style)
		assert_eq(fill_style.bg_color, StatBar.STAT_COLORS[stat])
