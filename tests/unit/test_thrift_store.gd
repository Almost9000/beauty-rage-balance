extends GutTest

var thrift_pool_default: ThriftPool
var front_door_scene: PackedScene
var thrift_store_scene: PackedScene
var rack_browser_scene: PackedScene
var checkout_counter_scene: PackedScene

var sample_top: ClothingItem
var sample_bottom: ClothingItem
var sample_dress: ClothingItem


func before_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()
	SceneRouter.reset_state()

	thrift_pool_default = load("res://data/thrift_pools/default.tres") as ThriftPool
	front_door_scene = load("res://features/prep/front_door.tscn") as PackedScene
	thrift_store_scene = load("res://levels/thrift_store/thrift_store.tscn") as PackedScene
	rack_browser_scene = load("res://features/thrift/rack_browser_ui.tscn") as PackedScene
	checkout_counter_scene = load("res://features/thrift/checkout_counter.tscn") as PackedScene

	sample_top = load("res://data/clothing/top/top_vintage_blouse_worn.tres") as ClothingItem
	sample_bottom = load("res://data/clothing/bottom/bottom_corduroy_pants_worn.tres") as ClothingItem
	sample_dress = load("res://data/clothing/dress/dress_retro_polka_worn.tres") as ClothingItem


func after_each() -> void:
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()
	SceneRouter.reset_state()


# -----------------------------------------------------------------------------
# 1. Pool Generation: Weights & Price Ranges Deterministically
# -----------------------------------------------------------------------------

func test_pool_generation_deterministic_with_seed() -> void:
	assert_not_null(thrift_pool_default, "Default ThriftPool should load cleanly")
	assert_eq(thrift_pool_default.racks_count, 3)
	assert_eq(thrift_pool_default.items_per_rack, 5)

	# Fixed seed generation produces identical racks
	var racks_a: Array[Array] = thrift_pool_default.generate_racks(1, 42)
	var racks_b: Array[Array] = thrift_pool_default.generate_racks(1, 42)

	assert_eq(racks_a.size(), 3)
	assert_eq(racks_a[0].size(), 5)
	assert_eq(racks_a.size(), racks_b.size())

	for r: int in range(racks_a.size()):
		for i: int in range(racks_a[r].size()):
			var item_a: Dictionary = racks_a[r][i]
			var item_b: Dictionary = racks_b[r][i]
			assert_eq(item_a["item_ref"], item_b["item_ref"], "Item ref should match deterministically")
			assert_eq(item_a["price_cents"], item_b["price_cents"], "Price should match deterministically")


func test_pool_generation_respects_price_ranges() -> void:
	var racks: Array[Array] = thrift_pool_default.generate_racks(1, 999)

	var price_map: Dictionary = {}
	for e: Dictionary in thrift_pool_default.entries:
		var itm: ClothingItem = e.get("item") as ClothingItem
		var ref: String = ResRef.to_ref(itm)
		price_map[ref] = e.get("price_range_cents", Vector2i(500, 2000))

	for r: int in range(racks.size()):
		for i: int in range(racks[r].size()):
			var entry: Dictionary = racks[r][i]
			var ref: String = str(entry["item_ref"])
			var price: int = int(entry["price_cents"])
			assert_true(price_map.has(ref), "Generated item should exist in pool catalog")
			var p_range: Vector2i = price_map[ref]
			var min_p: int = mini(p_range.x, p_range.y)
			var max_p: int = maxi(p_range.x, p_range.y)
			assert_between(price, min_p, max_p, "Item price should fall within configured price range")


func test_pool_generation_respects_weights() -> void:
	var custom_pool := ThriftPool.new()
	custom_pool.racks_count = 1
	custom_pool.items_per_rack = 100
	custom_pool.entries = [
		{
			"item": sample_top,
			"weight": 1000.0,
			"price_range_cents": Vector2i(100, 200),
		},
		{
			"item": sample_bottom,
			"weight": 0.001,
			"price_range_cents": Vector2i(100, 200),
		}
	]

	var racks: Array[Array] = custom_pool.generate_racks(1, 12345)
	var top_count: int = 0
	var bot_count: int = 0
	for entry: Dictionary in racks[0]:
		if entry["item"] == sample_top:
			top_count += 1
		elif entry["item"] == sample_bottom:
			bot_count += 1

	assert_gt(top_count, 90, "Heavily weighted item should appear vast majority of the time")
	assert_lte(bot_count, 5, "Miniscule weighted item should appear rarely or never")


# -----------------------------------------------------------------------------
# 2. Rack Stability Within Same Day & Regeneration Next Day
# -----------------------------------------------------------------------------

func test_rack_contents_stable_within_same_day_and_regenerate_on_new_day() -> void:
	# Same day (Day 1) produces stable results without seed override
	var racks_day1_first: Array[Array] = thrift_pool_default.generate_racks(1)
	var racks_day1_second: Array[Array] = thrift_pool_default.generate_racks(1)

	assert_eq(racks_day1_first[0][0]["item_ref"], racks_day1_second[0][0]["item_ref"])
	assert_eq(racks_day1_first[0][0]["price_cents"], racks_day1_second[0][0]["price_cents"])

	# Day 2 produces regenerated racks
	var racks_day2: Array[Array] = thrift_pool_default.generate_racks(2)
	var day1_all_refs: Array[String] = []
	for r: Array in racks_day1_first:
		for e: Dictionary in r:
			day1_all_refs.append(str(e["item_ref"]) + str(e["price_cents"]))

	var day2_all_refs: Array[String] = []
	for r: Array in racks_day2:
		for e: Dictionary in r:
			day2_all_refs.append(str(e["item_ref"]) + str(e["price_cents"]))

	assert_ne(day1_all_refs, day2_all_refs, "Racks on day 2 should differ from day 1")


func test_thrift_store_level_state_persistence_same_day() -> void:
	var store1: ThriftStore = thrift_store_scene.instantiate() as ThriftStore
	add_child_autoqfree(store1)

	var orig_racks: Array[Array] = store1.racks.duplicate(true)
	assert_false(orig_racks.is_empty())

	# Dig on rack 0
	store1._on_rack_item_dug(0, 2, {})
	var saved: Dictionary = store1.save_state()
	assert_eq(saved["day"], 1)
	assert_eq(saved["revealed_indices"][0], 2)

	# Instantiate a second store on the same day -> restores state
	var store2: ThriftStore = thrift_store_scene.instantiate() as ThriftStore
	add_child_autoqfree(store2)

	assert_eq(store2.rack_revealed_indices[0], 2, "Revealed index on rack 0 should be restored")
	assert_eq(store2.racks[0][0]["item_ref"], orig_racks[0][0]["item_ref"], "Rack contents should match restored state")


# -----------------------------------------------------------------------------
# 3. Digging Advances GameClock by dig_time_min
# -----------------------------------------------------------------------------

func test_digging_advances_game_clock_by_dig_time() -> void:
	var ui: RackBrowserUI = rack_browser_scene.instantiate() as RackBrowserUI
	add_child_autoqfree(ui)

	var mock_items: Array = [
		{"item": sample_top, "price_cents": 1200, "item_ref": ResRef.to_ref(sample_top)},
		{"item": sample_bottom, "price_cents": 1300, "item_ref": ResRef.to_ref(sample_bottom)},
		{"item": sample_dress, "price_cents": 1800, "item_ref": ResRef.to_ref(sample_dress)},
	]
	var test_basket: Array[Dictionary] = []

	ui.open(0, mock_items, 0, test_basket)
	assert_eq(ui.current_index, 0)
	assert_eq(ui.get_current_item_data()["item"], sample_top)

	var start_min: int = GameClock.now_minutes
	watch_signals(ui)

	# First Dig
	var success: bool = ui.dig()
	assert_true(success, "Dig should succeed when next item available")
	assert_eq(GameClock.now_minutes, start_min + 5, "GameClock should advance by dig_time_min (5 min)")
	assert_eq(ui.current_index, 1)
	assert_eq(ui.get_current_item_data()["item"], sample_bottom)
	assert_signal_emitted(ui, "item_dug")

	# Second Dig
	success = ui.dig()
	assert_true(success)
	assert_eq(GameClock.now_minutes, start_min + 10)
	assert_eq(ui.current_index, 2)
	assert_eq(ui.get_current_item_data()["item"], sample_dress)

	# Third Dig: at end of rack -> fails, clock unchanged
	success = ui.dig()
	assert_false(success, "Digging beyond end of rack should return false")
	assert_eq(GameClock.now_minutes, start_min + 10, "Clock should not advance when digging fails")


# -----------------------------------------------------------------------------
# 4. Checkout Success: Inventory, Wallet, and EventBus
# -----------------------------------------------------------------------------

func test_checkout_success_adds_clothing_deducts_wallet_and_emits_eventbus() -> void:
	var counter: CheckoutCounter = checkout_counter_scene.instantiate() as CheckoutCounter
	add_child_autoqfree(counter)

	FinanceManager.wallet_cents = 5000  # €50.00
	var test_basket: Array[Dictionary] = [
		{"item": sample_top, "price_cents": 1200, "item_ref": ResRef.to_ref(sample_top)},
		{"item": sample_bottom, "price_cents": 1300, "item_ref": ResRef.to_ref(sample_bottom)},
	]
	counter.set_basket(test_basket)

	assert_false(InventoryManager.owns(sample_top))
	assert_false(InventoryManager.owns(sample_bottom))

	watch_signals(EventBus)
	watch_signals(counter)

	var success: bool = counter.checkout()
	assert_true(success, "Checkout should succeed when wallet has enough funds")

	# Wallet deducted (5000 - 2500 = 2500)
	assert_eq(FinanceManager.wallet_cents, 2500, "Wallet should be deducted by total basket cost")

	# Inventory owns the items immediately
	assert_true(InventoryManager.owns(sample_top), "Sample top should be added to owned clothing")
	assert_true(InventoryManager.owns(sample_bottom), "Sample bottom should be added to owned clothing")

	# EventBus signals emitted
	assert_signal_emit_count(EventBus, "item_purchased", 2)
	assert_eq(get_signal_parameters(EventBus, "item_purchased", 0), [ResRef.to_ref(sample_top), 1200])
	assert_eq(get_signal_parameters(EventBus, "item_purchased", 1), [ResRef.to_ref(sample_bottom), 1300])

	# Basket cleared
	assert_true(test_basket.is_empty(), "Basket should be cleared upon checkout success")
	assert_signal_emitted(counter, "checkout_succeeded")


# -----------------------------------------------------------------------------
# 5. Checkout Decline: Insufficient Funds Preserves Basket and Wallet
# -----------------------------------------------------------------------------

func test_checkout_decline_preserves_basket_and_wallet() -> void:
	var counter: CheckoutCounter = checkout_counter_scene.instantiate() as CheckoutCounter
	add_child_autoqfree(counter)

	FinanceManager.wallet_cents = 1000  # €10.00
	var test_basket: Array[Dictionary] = [
		{"item": sample_dress, "price_cents": 2200, "item_ref": ResRef.to_ref(sample_dress)},
	]
	counter.set_basket(test_basket)

	watch_signals(EventBus)
	watch_signals(FinanceManager)
	watch_signals(counter)

	var success: bool = counter.checkout()
	assert_false(success, "Checkout should fail when funds are insufficient")

	# Wallet unchanged
	assert_eq(FinanceManager.wallet_cents, 1000, "Wallet should not be altered on decline")

	# Basket preserved
	assert_eq(test_basket.size(), 1, "Basket should preserve unpurchased items")
	assert_false(InventoryManager.owns(sample_dress), "Item should not be owned")

	# Signals
	assert_signal_not_emitted(EventBus, "item_purchased")
	assert_signal_emitted(FinanceManager, "purchase_declined")
	assert_signal_emitted(counter, "checkout_declined")


# -----------------------------------------------------------------------------
# 6. Opening Hours Validation on Front Door
# -----------------------------------------------------------------------------

func test_front_door_opening_hours_validation() -> void:
	var door: FrontDoor = front_door_scene.instantiate() as FrontDoor
	add_child_autoqfree(door)

	# 1. At 07:00 (wake time, 420 min): Closed before 10:00
	assert_eq(GameClock.now_minutes, 420)
	assert_false(door.is_thrift_open(), "Thrift store should be closed at 07:00")
	assert_false(door.can_go_thrifting())
	assert_eq(door.get_thrift_notice(), "Thrift Store closed (10:00-19:00)")
	door.update_prompt()
	assert_eq(door.interactable.prompt_text, "Nothing planned")

	# 2. Advance to 10:30 (630 min): Open
	GameClock.advance_minutes(630 - GameClock.now_minutes)
	assert_eq(GameClock.now_minutes, 630)
	door.update_prompt()
	assert_true(door.is_thrift_open(), "Thrift store should be open at 10:30")
	assert_true(door.can_go_thrifting())
	assert_true(door.interactable.prompt_text.contains("Go Thrifting"))
	assert_eq(door.get_thrift_notice(), "")

	# 3. Advance to 19:15 (1155 min): Closed after 19:00
	GameClock.advance_minutes(1155 - GameClock.now_minutes)
	assert_eq(GameClock.now_minutes, 1155)
	door.update_prompt()
	assert_false(door.is_thrift_open(), "Thrift store should be closed after 19:00")
	assert_false(door.can_go_thrifting())
	assert_eq(door.get_thrift_notice(), "Thrift Store closed (10:00-19:00)")

	# Attempting to go thrifting when closed shows closed notice
	door.go_thrifting()
	assert_eq(door.closed_notice, "Thrift Store closed (10:00-19:00)")


func test_front_door_thrifting_unavailable_during_active_prep() -> void:
	var door: FrontDoor = front_door_scene.instantiate() as FrontDoor
	add_child_autoqfree(door)

	# At 12:00 (720 min): thrift is open
	GameClock.advance_minutes(720 - GameClock.now_minutes)
	door.update_prompt()
	assert_true(door.can_go_thrifting())

	# Schedule outing at 13:00 (780 min) with Chloe (prep_window_min = 90, so prep window starts at 690)
	var outing: OutingData = load("res://data/outings/girls_day_out.tres") as OutingData
	OutingManager.schedule(outing, 780, "Chloe")
	GameClock.advance_minutes(1)
	door.update_prompt()

	assert_true(OutingManager.is_prep_active(), "Outing prep should be active")
	assert_false(door.can_go_thrifting(), "Thrifting should be unavailable when prep is active")
	assert_true(door.interactable.prompt_text.contains("Leave for"))


# -----------------------------------------------------------------------------
# 7. Closing Time Warning and Eviction at 19:00
# -----------------------------------------------------------------------------

func test_closing_warning_and_eviction_at_19_00() -> void:
	# Advance clock to 18:40 before instantiating store
	GameClock.advance_minutes(1120 - GameClock.now_minutes)

	var store: ThriftStore = thrift_store_scene.instantiate() as ThriftStore
	add_child_autoqfree(store)

	watch_signals(store)

	store.check_closing_hours()
	assert_false(store.closing_banner.visible)

	# Advance to 18:45 (1125 min, 15 min warning) -> warning shown
	GameClock.advance_minutes(5)
	store.check_closing_hours()
	assert_signal_emitted(store, "closing_warning_shown")
	assert_true(store.closing_banner.visible, "Closing banner should be visible at 18:45")
	assert_true(store.closing_banner_label.text.contains("19:00"))

	# Put unpaid items in basket
	store.shared_basket.append({"item": sample_top, "price_cents": 1200})
	assert_eq(store.shared_basket.size(), 1)

	# Advance to 19:00 (1140 min, closing time) -> eviction
	GameClock.advance_minutes(15)
	store.check_closing_hours()
	assert_signal_emitted(store, "closing_eviction_triggered")
	assert_true(store.shared_basket.is_empty(), "Unpaid basket must be discarded upon eviction")


# -----------------------------------------------------------------------------
# 8. Rack Browser UI: Add to Basket & Display Formatting
# -----------------------------------------------------------------------------

func test_rack_browser_ui_add_to_basket_and_prevent_duplicates() -> void:
	var ui: RackBrowserUI = rack_browser_scene.instantiate() as RackBrowserUI
	add_child_autoqfree(ui)

	var mock_items: Array = [
		{"item": sample_top, "price_cents": 1200, "item_ref": ResRef.to_ref(sample_top)},
	]
	var test_basket: Array[Dictionary] = []

	ui.open(0, mock_items, 0, test_basket)
	assert_eq(ui.item_name_label.text, sample_top.display_name)
	assert_true(ui.condition_label.text.contains("65%"))
	assert_eq(ui.price_label.text, "€12.00")
	assert_true(ui.tags_label.text.contains("#vintage"))

	# Add to basket
	var added: bool = ui.add_to_basket()
	assert_true(added)
	assert_eq(test_basket.size(), 1)
	assert_eq(ui.get_basket_total(), 1200)
	assert_true(ui.add_to_basket_button.disabled, "Add button should be disabled when already in basket")

	# Second add attempt should be rejected
	var added_again: bool = ui.add_to_basket()
	assert_false(added_again, "Cannot add same rack item twice")
	assert_eq(test_basket.size(), 1)
