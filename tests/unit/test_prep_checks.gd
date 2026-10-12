extends GutTest


func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()


func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()


func test_hygiene_check_evaluation() -> void:
	var check := HygieneCheck.new()
	check.min_hygiene = 70.0
	check.pass_threshold = 1.0

	StatusManager.set_value(Enums.Stat.HYGIENE, 70.0)
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)
	assert_true(check.is_passed())

	StatusManager.set_value(Enums.Stat.HYGIENE, 85.0)
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)
	assert_true(check.is_passed())

	StatusManager.set_value(Enums.Stat.HYGIENE, 35.0)
	assert_almost_eq(check.evaluate(), 0.5, 1e-4)
	assert_false(check.is_passed())

	StatusManager.set_value(Enums.Stat.HYGIENE, 0.0)
	assert_almost_eq(check.evaluate(), 0.0, 1e-4)
	assert_false(check.is_passed())

	check.min_hygiene = 0.0
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)


func test_status_manager_get_stat_helper() -> void:
	StatusManager.set_value(Enums.Stat.HYGIENE, 64.0)
	assert_almost_eq(StatusManager.get_stat("hygiene"), 64.0, 1e-4)
	assert_almost_eq(StatusManager.get_stat(&"HYGIENE"), 64.0, 1e-4)
	assert_almost_eq(StatusManager.get_stat(Enums.Stat.HYGIENE), 64.0, 1e-4)


func test_dress_code_check_matching_tags_and_condition() -> void:
	var check := DressCodeCheck.new()
	check.required_tags = [&"casual"]
	check.forbidden_tags = [&"sleepwear"]
	check.condition_weight = 0.3
	check.pass_threshold = 0.75

	var top := ClothingItem.new()
	top.id = &"test_top"
	top.slot = Enums.Slot.TOP
	top.style_tags = [&"casual"]
	top.condition = 1.0

	var bot := ClothingItem.new()
	bot.id = &"test_bot"
	bot.slot = Enums.Slot.BOTTOM
	bot.style_tags = [&"casual"]
	bot.condition = 1.0

	InventoryManager.equipped.clear()
	InventoryManager.equipped[Enums.Slot.TOP] = top
	InventoryManager.equipped[Enums.Slot.BOTTOM] = bot

	# Both casual, condition 1.0 -> 0.7 * 1.0 + 0.3 * 1.0 = 1.0
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)
	assert_true(check.is_passed())

	# Lower condition: 0.5 average -> 0.7 * 1.0 + 0.3 * 0.5 = 0.85
	top.condition = 0.5
	bot.condition = 0.5
	assert_almost_eq(check.evaluate(), 0.85, 1e-4)
	assert_true(check.is_passed())


func test_dress_code_check_forbidden_tags_fails() -> void:
	var check := DressCodeCheck.new()
	check.required_tags = [&"casual"]
	check.forbidden_tags = [&"sleepwear"]
	check.condition_weight = 0.3
	check.pass_threshold = 0.75

	var pajama := ClothingItem.new()
	pajama.id = &"pajama"
	pajama.slot = Enums.Slot.TOP
	pajama.style_tags = [&"casual", &"sleepwear"]
	pajama.condition = 1.0

	InventoryManager.equipped.clear()
	InventoryManager.equipped[Enums.Slot.TOP] = pajama

	# Has forbidden tag sleepwear -> tag score is 0.0.
	# Score = 0.7 * 0.0 + 0.3 * 1.0 = 0.30
	assert_almost_eq(check.evaluate(), 0.30, 1e-4)
	assert_false(check.is_passed())


func test_dress_code_check_empty_equipped_returns_zero() -> void:
	var check := DressCodeCheck.new()
	check.required_tags = [&"casual"]
	InventoryManager.equipped.clear()
	assert_almost_eq(check.evaluate(), 0.0, 1e-4)
	assert_false(check.is_passed())


func test_makeup_check_optional() -> void:
	var check := MakeupCheck.new()
	check.min_score = 0.6
	check.makeup_optional = true
	check.pass_threshold = 1.0

	# Bare face (no look) -> optional passes with 1.0
	InventoryManager.clear_look()
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)
	assert_true(check.is_passed())

	# Applied good makeup
	var cosmetic := CosmeticItem.new()
	cosmetic.id = &"lipstick"
	var good_look := MakeupLook.new()
	good_look.set_layer(Enums.MakeupLayer.LIPSTICK, cosmetic, 1.0, Vector2.ZERO, 0.9)
	InventoryManager.set_look(good_look)
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)
	assert_true(check.is_passed())

	# Applied sloppy makeup (0.3 < 0.6)
	var sloppy_look := MakeupLook.new()
	sloppy_look.set_layer(Enums.MakeupLayer.LIPSTICK, cosmetic, 1.0, Vector2.ZERO, 0.3)
	InventoryManager.set_look(sloppy_look)
	assert_almost_eq(check.evaluate(), 0.5, 1e-4)
	assert_false(check.is_passed())


func test_makeup_check_required() -> void:
	var check := MakeupCheck.new()
	check.min_score = 0.75
	check.makeup_optional = false
	check.pass_threshold = 1.0

	# Bare face -> fails
	InventoryManager.clear_look()
	assert_almost_eq(check.evaluate(), 0.0, 1e-4)
	assert_false(check.is_passed())

	# High score makeup -> passes
	var cosmetic := CosmeticItem.new()
	cosmetic.id = &"lipstick"
	var look := MakeupLook.new()
	look.set_layer(Enums.MakeupLayer.LIPSTICK, cosmetic, 1.0, Vector2.ZERO, 0.8)
	InventoryManager.set_look(look)
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)
	assert_true(check.is_passed())


func test_wallet_check_evaluation() -> void:
	var check := WalletCheck.new()
	check.cost_cents = 3000
	check.pass_threshold = 1.0

	FinanceManager.wallet_cents = 5000
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)
	assert_true(check.is_passed())

	FinanceManager.wallet_cents = 1500
	assert_almost_eq(check.evaluate(), 0.5, 1e-4)
	assert_false(check.is_passed())

	FinanceManager.wallet_cents = 0
	assert_almost_eq(check.evaluate(), 0.0, 1e-4)
	assert_false(check.is_passed())

	check.cost_cents = 0
	assert_almost_eq(check.evaluate(), 1.0, 1e-4)


func test_outing_data_evaluate_readiness() -> void:
	var outing: OutingData = load("res://data/outings/girls_day_out.tres") as OutingData
	assert_not_null(outing)
	assert_eq(outing.checks.size(), 4)

	# Favorable state
	StatusManager.set_value(Enums.Stat.HYGIENE, 90.0)
	FinanceManager.wallet_cents = 5000

	var top := ClothingItem.new()
	top.id = &"top"
	top.style_tags = [&"casual"]
	top.condition = 1.0
	InventoryManager.equipped[Enums.Slot.TOP] = top
	InventoryManager.clear_look()  # optional for girls day out

	var result: Dictionary = outing.evaluate_readiness()
	assert_true(result["score"] >= outing.pass_threshold)
	assert_eq(result["result"], Enums.OutingResult.PASS)
	assert_eq(outing.get_affinity_delta(Enums.OutingResult.PASS), 15)
	assert_eq(outing.get_affinity_delta(Enums.OutingResult.FAIL), -10)
