extends GutTest

func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	FinanceManager.reset_state()

func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	FinanceManager.reset_state()

func test_default_state_and_config() -> void:
	assert_not_null(FinanceManager.config, "Config should be loaded")
	assert_eq(FinanceManager.wallet_cents, 25000, "Starting wallet should match config default (€250.00)")
	assert_eq(FinanceManager.first_rent_day, 30, "First rent day should default to 30")
	assert_eq(FinanceManager.last_rent_day, 0, "Last rent day should initialize to 0")
	assert_eq(FinanceManager.last_income_day, 0, "Last income day should initialize to 0")
	assert_true(FinanceManager.get_ledger().is_empty(), "Ledger should start empty")

	assert_true(FinanceManager.can_afford(25000), "Can afford exact wallet amount")
	assert_false(FinanceManager.can_afford(25001), "Cannot afford 1 cent over wallet amount")
	assert_true(FinanceManager.can_afford(0), "Can afford 0 cents")
	assert_true(FinanceManager.can_afford(-100), "Can afford negative cents")

	var debt_mods: Array[StatModifier] = StatusManager.get_modifiers(int(Enums.Stat.SANITY))
	var has_debt: bool = false
	for m: StatModifier in debt_mods:
		if m.source_id == &"finance_debt":
			has_debt = true
	assert_false(has_debt, "No debt modifier should be present initially")

func test_spend_success_and_ledger() -> void:
	watch_signals(FinanceManager)
	var initial_wallet: int = FinanceManager.wallet_cents
	var spend_amount: int = 1299

	var success: bool = FinanceManager.spend(spend_amount, &"thrift", "Red blouse")
	assert_true(success, "Spend should succeed when wallet has funds")
	assert_eq(FinanceManager.wallet_cents, initial_wallet - spend_amount, "Wallet should decrease by spend amount")

	assert_signal_emitted(FinanceManager, "wallet_changed")
	assert_signal_emitted(FinanceManager, "transaction_recorded")
	assert_signal_not_emitted(FinanceManager, "purchase_declined")

	var ledger: Array[Dictionary] = FinanceManager.get_ledger()
	assert_eq(ledger.size(), 1, "One ledger entry should be present")
	var entry: Dictionary = ledger[0]
	assert_eq(entry["amount_cents"], -spend_amount, "Spend amount in ledger should be negative")
	assert_eq(entry["category"], &"thrift", "Category should match")
	assert_eq(entry["memo"], "Red blouse", "Memo should match")
	assert_eq(entry["minute"], GameClock.now_minutes, "Minute should match clock")

func test_spend_insufficient_funds_declined() -> void:
	watch_signals(FinanceManager)
	var initial_wallet: int = FinanceManager.wallet_cents
	var over_amount: int = initial_wallet + 500

	var success: bool = FinanceManager.spend(over_amount, &"shop", "Designer bag")
	assert_false(success, "Spend should return false on insufficient funds")
	assert_eq(FinanceManager.wallet_cents, initial_wallet, "Wallet must remain unchanged on decline")

	assert_signal_emitted_with_parameters(FinanceManager, "purchase_declined", [over_amount, &"shop"])
	assert_signal_not_emitted(FinanceManager, "wallet_changed")
	assert_signal_not_emitted(FinanceManager, "transaction_recorded")
	assert_true(FinanceManager.get_ledger().is_empty(), "No ledger entry should be created on decline")

func test_spend_zero_and_negative() -> void:
	var initial_wallet: int = FinanceManager.wallet_cents
	assert_true(FinanceManager.spend(0, &"misc", "Free item"))
	assert_eq(FinanceManager.wallet_cents, initial_wallet)

	assert_false(FinanceManager.spend(-500, &"misc", "Negative spend rejected"))
	assert_eq(FinanceManager.wallet_cents, initial_wallet)

func test_earn_and_ledger() -> void:
	watch_signals(FinanceManager)
	var initial_wallet: int = FinanceManager.wallet_cents
	var earn_amount: int = 5000

	FinanceManager.earn(earn_amount, &"income", "Freelance work")
	assert_eq(FinanceManager.wallet_cents, initial_wallet + earn_amount)

	assert_signal_emitted_with_parameters(FinanceManager, "wallet_changed", [initial_wallet + earn_amount, earn_amount])
	assert_signal_emitted(FinanceManager, "transaction_recorded")

	var ledger: Array[Dictionary] = FinanceManager.get_ledger()
	assert_eq(ledger.size(), 1)
	assert_eq(ledger[0]["amount_cents"], earn_amount)
	assert_eq(ledger[0]["category"], &"income")
	assert_eq(ledger[0]["memo"], "Freelance work")

func test_charge_bill_pushes_wallet_negative() -> void:
	watch_signals(FinanceManager)
	var initial_wallet: int = FinanceManager.wallet_cents
	var bill_amount: int = initial_wallet + 1000

	FinanceManager.charge_bill(bill_amount, &"rent", "Rent bill")
	assert_eq(FinanceManager.wallet_cents, -1000, "Bill should push wallet negative")

	assert_signal_emitted_with_parameters(FinanceManager, "bill_charged", [&"rent", bill_amount])
	assert_signal_emitted_with_parameters(FinanceManager, "wallet_changed", [-1000, -bill_amount])
	assert_signal_emitted(FinanceManager, "transaction_recorded")

	var ledger: Array[Dictionary] = FinanceManager.get_ledger()
	assert_eq(ledger.size(), 1)
	assert_eq(ledger[0]["amount_cents"], -bill_amount)

func test_debt_stress_modifier_added_when_negative_and_removed_when_non_negative() -> void:
	# 1. Initially wallet > 0, no debt modifier
	assert_false(_has_debt_modifier(), "Initially no debt modifier")
	var base_rate: float = StatusManager.get_effective_rate(Enums.Stat.SANITY)

	# 2. Charge bill pushing wallet negative
	FinanceManager.charge_bill(FinanceManager.wallet_cents + 5000, &"bill", "Huge bill")
	assert_lt(FinanceManager.wallet_cents, 0, "Wallet is now negative")
	assert_true(_has_debt_modifier(), "Debt modifier should be active in StatusManager")

	var mod: StatModifier = _get_debt_modifier()
	assert_not_null(mod)
	assert_eq(mod.stat, Enums.Stat.SANITY)
	assert_eq(mod.kind, Enums.ModifierKind.RATE_ADD)
	assert_almost_eq(mod.value, -1.0, 1e-4)
	assert_eq(mod.source_id, &"finance_debt")
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), base_rate - 1.0, 1e-4)

	# 3. Additional bill while still in debt keeps modifier active without duplicate
	FinanceManager.charge_bill(1000, &"bill", "Another bill")
	var count: int = _count_debt_modifiers()
	assert_eq(count, 1, "Debt modifier should not be duplicated")

	# 4. Partial earning still keeps wallet negative
	FinanceManager.earn(2000, &"income", "Partial payment")
	assert_lt(FinanceManager.wallet_cents, 0)
	assert_true(_has_debt_modifier(), "Debt modifier remains active while negative")

	# 5. Earning enough to reach exactly 0 removes debt modifier
	var remaining_debt: int = absi(FinanceManager.wallet_cents)
	FinanceManager.earn(remaining_debt, &"income", "Cleared to zero")
	assert_eq(FinanceManager.wallet_cents, 0, "Wallet reached exactly 0")
	assert_false(_has_debt_modifier(), "Debt modifier removed when wallet is >= 0")
	assert_almost_eq(StatusManager.get_effective_rate(Enums.Stat.SANITY), base_rate, 1e-4)

	# 6. Pushing negative again re-adds debt modifier
	FinanceManager.charge_bill(1, &"bill", "One cent deficit")
	assert_eq(FinanceManager.wallet_cents, -1)
	assert_true(_has_debt_modifier(), "Debt modifier re-added on deficit")

	# 7. Earning above 0 removes it again
	FinanceManager.earn(100, &"income", "Back in black")
	assert_gt(FinanceManager.wallet_cents, 0)
	assert_false(_has_debt_modifier(), "Debt modifier removed when wallet > 0")

func test_skipping_60_days_charges_rent_twice_and_income_on_every_7th_day() -> void:
	# Acceptance criterion: Skipping 60 days charges rent exactly twice and income on every 7th day, each once.
	assert_eq(GameClock.day, 1)
	assert_eq(FinanceManager.wallet_cents, 25000)

	# Skip 60 days
	GameClock.skip(60 * 1440)
	assert_eq(GameClock.day, 61, "60 days skipped should land on day 61")

	# Count rent and income entries in ledger
	var rent_count: int = 0
	var income_count: int = 0
	var ledger: Array[Dictionary] = FinanceManager.get_ledger()

	for entry: Dictionary in ledger:
		if entry["category"] == &"rent":
			rent_count += 1
		elif entry["category"] == &"income":
			income_count += 1

	assert_eq(rent_count, 2, "Rent charged exactly twice across 60 days (days 30 and 60)")
	assert_eq(income_count, 8, "Income credited on every 7th day across 60 days (7, 14, 21, 28, 35, 42, 49, 56)")
	assert_eq(FinanceManager.last_rent_day, 60, "Last rent day should be 60")
	assert_eq(FinanceManager.last_income_day, 56, "Last income day should be 56")

	# Math check:
	# Start: 25000
	# Rent: 2 * -60000 = -120000
	# Income: 8 * 35000 = 280000
	# Net: 25000 - 120000 + 280000 = 185000
	assert_eq(FinanceManager.wallet_cents, 185000, "Wallet calculation matches exact rent and income totals")

func test_totals_for_day() -> void:
	# Transactions on Day 1 (clock is at 420)
	FinanceManager.spend(500, &"food", "Coffee")
	FinanceManager.earn(2000, &"gift", "Gift")
	FinanceManager.spend(700, &"food", "Lunch")

	# Advance to Day 2 (midnight is minute 1440)
	GameClock.skip(1440)
	assert_eq(GameClock.day, 2)

	FinanceManager.charge_bill(1500, &"bill", "Electricity")

	var day1_totals: Dictionary = FinanceManager.totals_for_day(1)
	assert_eq(day1_totals["spent"], 1200, "Day 1 spent total is 500 + 700 = 1200")
	assert_eq(day1_totals["earned"], 2000, "Day 1 earned total is 2000")

	var day2_totals: Dictionary = FinanceManager.totals_for_day(2)
	assert_eq(day2_totals["spent"], 1500, "Day 2 spent total is 1500")
	assert_eq(day2_totals["earned"], 0, "Day 2 earned total is 0")

	var day3_totals: Dictionary = FinanceManager.totals_for_day(3)
	assert_eq(day3_totals["spent"], 0, "Day 3 has no transactions")
	assert_eq(day3_totals["earned"], 0, "Day 3 has no transactions")

func test_ledger_pruning_after_60_days() -> void:
	FinanceManager.spend(100, &"food", "Old coffee")
	assert_eq(FinanceManager.get_ledger().size(), 1)
	assert_eq(FinanceManager.get_ledger()[0]["memo"], "Old coffee")

	# Skip 61 days
	GameClock.skip(61 * 1440)

	# Trigger a new transaction
	FinanceManager.spend(200, &"food", "New coffee")

	var ledger: Array[Dictionary] = FinanceManager.get_ledger()
	var has_old: bool = false
	for entry: Dictionary in ledger:
		if entry["memo"] == "Old coffee":
			has_old = true
	assert_false(has_old, "Entry older than 60 days should be pruned")

func test_json_round_trip() -> void:
	# 1. Setup custom state with debt
	FinanceManager.wallet_cents = -5000
	FinanceManager.first_rent_day = 30
	FinanceManager.last_rent_day = 30
	FinanceManager.last_income_day = 28
	FinanceManager._record_transaction(-5000, &"rent", "Rent debt")
	FinanceManager._update_debt_status()

	assert_true(_has_debt_modifier(), "Debt modifier is active before serialization")

	# 2. Serialize to JSON string
	var dict: Dictionary = FinanceManager.to_dict()
	var json_str: String = JSON.stringify(dict)
	assert_not_null(json_str)

	# 3. Reset manager to blank default
	FinanceManager.reset_state()
	assert_eq(FinanceManager.wallet_cents, 25000)
	assert_false(_has_debt_modifier())

	# 4. Deserialize from JSON string
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary)
	FinanceManager.from_dict(parsed as Dictionary)

	# 5. Verify restored state
	assert_eq(FinanceManager.wallet_cents, -5000)
	assert_eq(typeof(FinanceManager.wallet_cents), TYPE_INT)
	assert_eq(FinanceManager.first_rent_day, 30)
	assert_eq(FinanceManager.last_rent_day, 30)
	assert_eq(FinanceManager.last_income_day, 28)
	assert_true(_has_debt_modifier(), "Debt modifier restored after loading negative wallet")

	var ledger: Array[Dictionary] = FinanceManager.get_ledger()
	assert_eq(ledger.size(), 1)
	assert_eq(ledger[0]["amount_cents"], -5000)
	assert_eq(typeof(ledger[0]["amount_cents"]), TYPE_INT)
	assert_eq(typeof(ledger[0]["minute"]), TYPE_INT)
	assert_eq(ledger[0]["category"], &"rent")
	assert_eq(ledger[0]["memo"], "Rent debt")

func test_no_floats_in_money_paths() -> void:
	assert_eq(typeof(FinanceManager.wallet_cents), TYPE_INT)
	assert_eq(typeof(FinanceManager.config.starting_cents), TYPE_INT)
	assert_eq(typeof(FinanceManager.config.rent_cents), TYPE_INT)
	assert_eq(typeof(FinanceManager.config.income_cents), TYPE_INT)

	FinanceManager.spend(50, &"test", "test")
	var entry: Dictionary = FinanceManager.get_ledger()[0]
	assert_eq(typeof(entry["amount_cents"]), TYPE_INT)
	assert_eq(typeof(entry["minute"]), TYPE_INT)

	var totals: Dictionary = FinanceManager.totals_for_day(1)
	assert_eq(typeof(totals["spent"]), TYPE_INT)
	assert_eq(typeof(totals["earned"]), TYPE_INT)

# Helper functions
func _has_debt_modifier() -> bool:
	for m: StatModifier in StatusManager.get_modifiers(int(Enums.Stat.SANITY)):
		if m.source_id == &"finance_debt":
			return true
	return false

func _get_debt_modifier() -> StatModifier:
	for m: StatModifier in StatusManager.get_modifiers(int(Enums.Stat.SANITY)):
		if m.source_id == &"finance_debt":
			return m
	return null

func _count_debt_modifiers() -> int:
	var count: int = 0
	for m: StatModifier in StatusManager.get_modifiers(int(Enums.Stat.SANITY)):
		if m.source_id == &"finance_debt":
			count += 1
	return count
