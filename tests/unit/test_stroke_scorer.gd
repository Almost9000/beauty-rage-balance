extends GutTest


func test_makeup_guides_exist_and_valid() -> void:
	var guide_files := {
		Enums.MakeupLayer.BASE: "res://data/looks/guides/base.tres",
		Enums.MakeupLayer.BLUSH: "res://data/looks/guides/blush.tres",
		Enums.MakeupLayer.EYESHADOW: "res://data/looks/guides/eyeshadow.tres",
		Enums.MakeupLayer.EYELINER: "res://data/looks/guides/eyeliner.tres",
		Enums.MakeupLayer.LIPSTICK: "res://data/looks/guides/lipstick.tres",
	}

	for layer: Enums.MakeupLayer in guide_files.keys():
		var path: String = guide_files[layer]
		assert_true(ResourceLoader.exists(path), "Guide file exists: " + path)
		var guide: MakeupGuide = load(path) as MakeupGuide
		assert_not_null(guide, "Guide loads as MakeupGuide: " + path)
		assert_eq(guide.layer, layer, "Guide layer matches: " + path)
		assert_true(guide.is_valid(), "Guide is valid: " + path)
		assert_gt(guide.points.size(), 1, "Guide has multiple points")
		assert_gt(guide.time_cost_min, 0, "Guide has positive time cost")
		assert_gt(guide.opacity_range.y, guide.opacity_range.x, "Guide opacity range valid")
		assert_gt(guide.max_smudge, 0.0, "Guide max smudge positive")


func test_stroke_scorer_no_stroke_returns_zero() -> void:
	var guide := MakeupGuide.new()
	guide.layer = Enums.MakeupLayer.BASE
	guide.points = PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.8, 0.5)])
	guide.width = 0.04
	guide.opacity_range = Vector2(0.2, 0.95)
	guide.max_smudge = 0.03

	var result: Dictionary = StrokeScorer.score_stroke(guide, PackedVector2Array(), -1.0, 0.0)

	assert_eq(result["accuracy"], 0.0, "Accuracy is 0.0 for empty stroke")
	assert_eq(result["coverage"], 0.0, "Coverage is 0.0")
	assert_eq(result["bleed"], 0.0, "Bleed is 0.0")
	assert_almost_eq(result["opacity"], 0.2, 0.001, "Opacity equals minimum range")
	var smudge: Vector2 = result["smudge"]
	assert_almost_eq(smudge.length(), 0.03, 0.001, "Smudge magnitude is max_smudge")


func test_stroke_scorer_perfect_trace_returns_one() -> void:
	var guide := MakeupGuide.new()
	guide.layer = Enums.MakeupLayer.BLUSH
	guide.points = PackedVector2Array([
		Vector2(0.2, 0.5),
		Vector2(0.5, 0.6),
		Vector2(0.8, 0.5)
	])
	guide.width = 0.05
	guide.opacity_range = Vector2(0.2, 0.95)
	guide.max_smudge = 0.03

	# Identical points and default width gives exact coverage with zero bleed
	var stroke: PackedVector2Array = guide.points
	var result: Dictionary = StrokeScorer.score_stroke(guide, stroke, -1.0, 0.0)

	assert_almost_eq(result["accuracy"], 1.0, 0.001, "Accuracy is 1.0 for perfect trace")
	assert_almost_eq(result["coverage"], 1.0, 0.001, "Coverage is 1.0")
	assert_almost_eq(result["bleed"], 0.0, 0.001, "Bleed is 0.0")
	assert_almost_eq(result["opacity"], 0.95, 0.001, "Opacity equals maximum range")
	var smudge: Vector2 = result["smudge"]
	assert_almost_eq(smudge.length(), 0.0, 0.001, "Smudge magnitude is 0.0")


func test_stroke_scorer_all_bleed_returns_zero() -> void:
	var guide := MakeupGuide.new()
	guide.layer = Enums.MakeupLayer.LIPSTICK
	guide.points = PackedVector2Array([Vector2(0.4, 0.7), Vector2(0.6, 0.7)])
	guide.width = 0.04
	guide.opacity_range = Vector2(0.2, 0.95)
	guide.max_smudge = 0.03

	# Stroke completely disjoint from guide (at y=0.1 vs y=0.7)
	var stroke := PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.3, 0.1)])
	var result: Dictionary = StrokeScorer.score_stroke(guide, stroke, -1.0, 0.0)

	assert_eq(result["accuracy"], 0.0, "Accuracy is 0.0 when all stroke is bleed")
	assert_eq(result["coverage"], 0.0, "Coverage is 0.0")
	assert_gt(result["bleed"], 0.0, "Bleed is positive")


func test_stroke_scorer_half_trace_returns_half() -> void:
	var guide := MakeupGuide.new()
	guide.layer = Enums.MakeupLayer.EYELINER
	guide.points = PackedVector2Array([Vector2(0.1, 0.5), Vector2(0.9, 0.5)])
	guide.width = 0.04
	guide.opacity_range = Vector2(0.2, 1.0)
	guide.max_smudge = 0.04

	# Stroke covers the left half of the straight horizontal segment
	var stroke := PackedVector2Array([Vector2(0.1, 0.5), Vector2(0.5, 0.5)])
	var result: Dictionary = StrokeScorer.score_stroke(guide, stroke, -1.0, 0.0)

	assert_almost_eq(result["bleed"], 0.0, 0.01, "Bleed is approximately 0.0")
	assert_between(result["coverage"], 0.45, 0.55, "Coverage is approximately 0.5")
	assert_between(result["accuracy"], 0.45, 0.55, "Accuracy is approximately 0.5")
	assert_between(result["opacity"], 0.55, 0.65, "Opacity scales with accuracy")


func test_stroke_scorer_multi_stroke_support() -> void:
	var guide := MakeupGuide.new()
	guide.points = PackedVector2Array([Vector2(0.1, 0.3), Vector2(0.5, 0.3), Vector2(0.9, 0.3)])
	guide.width = 0.04

	# Two distinct stroke segments
	var stroke1 := PackedVector2Array([Vector2(0.1, 0.3), Vector2(0.5, 0.3)])
	var stroke2 := PackedVector2Array([Vector2(0.5, 0.3), Vector2(0.9, 0.3)])
	var strokes: Array = [stroke1, stroke2]

	var result: Dictionary = StrokeScorer.score_stroke(guide, strokes)
	assert_almost_eq(result["accuracy"], 1.0, 0.01, "Multi-stroke trace achieves full accuracy")
	assert_almost_eq(result["coverage"], 1.0, 0.01, "Multi-stroke coverage is 1.0")


func test_stroke_scorer_performance_under_two_ms() -> void:
	var guide: MakeupGuide = load("res://data/looks/guides/base.tres") as MakeupGuide
	assert_not_null(guide)

	var stroke: PackedVector2Array = guide.points

	# Warm up JIT/bytecode cache
	StrokeScorer.score_stroke(guide, stroke)

	var t0: int = Time.get_ticks_usec()
	var result: Dictionary = StrokeScorer.score_stroke(guide, stroke)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	assert_gt(result["guide_cells"], 0)
	assert_lt(elapsed_ms, 2.0, "StrokeScorer execution must be under 2.0 ms (took %.3f ms)" % elapsed_ms)
