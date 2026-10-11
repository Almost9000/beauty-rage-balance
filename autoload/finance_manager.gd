extends Node

signal wallet_changed(cents: int, delta: int)
signal transaction_recorded(entry: Dictionary)
signal bill_charged(category: StringName, cents: int)
signal purchase_declined(cents: int, category: StringName)

const MAX_LEDGER_DAYS: int = 60
const MINUTES_PER_DAY: int = 1440

var config: FinanceConfig = null
var wallet_cents: int = 0
var first_rent_day: int = 30
var last_rent_day: int = 0
var last_income_day: int = 0

var _ledger: Array[Dictionary] = []
var _is_debt_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if not clock.is_connected("day_started", _on_game_clock_day_started):
			clock.connect("day_started", _on_game_clock_day_started)
	reset_state()

func reset_state() -> void:
	config = FinanceConfig.load_default()
	wallet_cents = config.starting_cents if config else 0
	first_rent_day = config.first_rent_day if config else 30
	last_rent_day = 0
	last_income_day = 0
	_ledger.clear()
	_is_debt_active = false
	_update_debt_status()

func to_dict() -> Dictionary:
	return {
		"wallet_cents": wallet_cents,
		"first_rent_day": first_rent_day,
		"last_rent_day": last_rent_day,
		"last_income_day": last_income_day,
		"ledger": _ledger.duplicate(true),
	}

func from_dict(data: Dictionary, _version: int = 1) -> void:
	if config == null:
		config = FinanceConfig.load_default()
	wallet_cents = int(data.get("wallet_cents", 0))
	if data.has("first_rent_day"):
		first_rent_day = int(data["first_rent_day"])
	last_rent_day = int(data.get("last_rent_day", 0))
	last_income_day = int(data.get("last_income_day", 0))

	_ledger.clear()
	if data.has("ledger") and data["ledger"] is Array:
		for item: Variant in (data["ledger"] as Array):
			if item is Dictionary:
				var item_dict: Dictionary = item as Dictionary
				_ledger.append({
					"minute": int(item_dict.get("minute", 0)),
					"amount_cents": int(item_dict.get("amount_cents", 0)),
					"category": StringName(item_dict.get("category", "")),
					"memo": str(item_dict.get("memo", "")),
				})

	_update_debt_status()

func can_afford(cents: int) -> bool:
	if cents <= 0:
		return true
	return wallet_cents >= cents

func spend(cents: int, category: StringName = &"discretionary", memo: String = "") -> bool:
	if cents < 0:
		push_warning("FinanceManager: spend() called with negative cents.")
		return false
	if not can_afford(cents):
		purchase_declined.emit(cents, category)
		return false
	if cents == 0:
		return true

	wallet_cents -= cents
	_record_transaction(-cents, category, memo)
	wallet_changed.emit(wallet_cents, -cents)
	_update_debt_status()
	return true

func earn(cents: int, category: StringName = &"income", memo: String = "") -> void:
	if cents <= 0:
		return
	wallet_cents += cents
	_record_transaction(cents, category, memo)
	wallet_changed.emit(wallet_cents, cents)
	_update_debt_status()

func charge_bill(cents: int, category: StringName = &"bill", memo: String = "") -> void:
	if cents <= 0:
		return
	wallet_cents -= cents
	bill_charged.emit(category, cents)
	_record_transaction(-cents, category, memo)
	wallet_changed.emit(wallet_cents, -cents)
	_update_debt_status()

func charge_rent() -> void:
	if config:
		charge_bill(config.rent_cents, &"rent", "Rent")

func get_ledger() -> Array[Dictionary]:
	return _ledger.duplicate(true)

func totals_for_day(day: int) -> Dictionary:
	var empty_res: Dictionary = {
		"spent": 0,
		"earned": 0,
		"spent_cents": 0,
		"earned_cents": 0,
	}
	if day < 1:
		return empty_res

	var start_min: int = (day - 1) * MINUTES_PER_DAY
	var end_min: int = day * MINUTES_PER_DAY
	var total_spent: int = 0
	var total_earned: int = 0

	for entry: Dictionary in _ledger:
		var m: int = int(entry.get("minute", 0))
		if m >= start_min and m < end_min:
			var amt: int = int(entry.get("amount_cents", 0))
			if amt < 0:
				total_spent += absi(amt)
			elif amt > 0:
				total_earned += amt

	return {
		"spent": total_spent,
		"earned": total_earned,
		"spent_cents": total_spent,
		"earned_cents": total_earned,
	}

func is_rent_day(day: int) -> bool:
	if config == null or config.rent_cents <= 0 or config.rent_interval_days <= 0:
		return false
	if day < first_rent_day:
		return false
	return (day - first_rent_day) % config.rent_interval_days == 0

func is_income_day(day: int) -> bool:
	if config == null or config.income_cents <= 0 or config.income_interval_days <= 0:
		return false
	if day <= 0:
		return false
	return day % config.income_interval_days == 0

func _on_game_clock_day_started(day: int) -> void:
	if is_rent_day(day) and last_rent_day != day:
		last_rent_day = day
		charge_bill(config.rent_cents, &"rent", "Rent")
	if is_income_day(day) and last_income_day != day:
		last_income_day = day
		earn(config.income_cents, &"income", "Income")
	_prune_ledger()

func _record_transaction(amount_cents: int, category: StringName, memo: String) -> void:
	var entry: Dictionary = {
		"minute": _get_current_minute(),
		"amount_cents": amount_cents,
		"category": category,
		"memo": memo,
	}
	_ledger.append(entry)
	_prune_ledger()
	transaction_recorded.emit(entry)

func _prune_ledger() -> void:
	var current_minute: int = _get_current_minute()
	var cutoff_minute: int = current_minute - (MAX_LEDGER_DAYS * MINUTES_PER_DAY)
	while not _ledger.is_empty() and int(_ledger[0].get("minute", 0)) < cutoff_minute:
		_ledger.remove_at(0)

func _update_debt_status() -> void:
	var status_mgr: Node = get_node_or_null("/root/StatusManager")
	if not status_mgr:
		return
	if wallet_cents < 0:
		if not _is_debt_active:
			var debt_mod: StatModifier = config.get_debt_modifier() if config else null
			if debt_mod:
				status_mgr.call("add_modifier", debt_mod)
				_is_debt_active = true
	else:
		if _is_debt_active:
			status_mgr.call("remove_by_source", &"finance_debt")
			_is_debt_active = false
		else:
			status_mgr.call("remove_by_source", &"finance_debt")

func _get_current_minute() -> int:
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		return int(clock.get("now_minutes"))
	return 0
