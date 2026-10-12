extends GutTest

const SHOP_APP_SCENE_PATH := "res://features/phone/apps/shop/shop_app.tscn"
const CATALOG_PATH := "res://data/shop/catalog.tres"
const PHONE_SCENE_PATH := "res://features/phone/phone.tscn"

var shop_app_scene: PackedScene
var catalog: ShopCatalog
var phone_scene: PackedScene


func before_each() -> void:
	shop_app_scene = load(SHOP_APP_SCENE_PATH) as PackedScene
	catalog = load(CATALOG_PATH) as ShopCatalog
	phone_scene = load(PHONE_SCENE_PATH) as PackedScene

	GameSettings.reset_current()
	GameClock.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	StatusManager.reset_state()


func after_each() -> void:
	GameClock.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	StatusManager.reset_state()
	var root_phone: Node = get_node_or_null("/root/Phone")
	if root_phone and root_phone.has_method("reset_state"):
		root_phone.call("reset_state")


func test_catalog_resource_validity() -> void:
	assert_not_null(catalog, "Catalog resource should load cleanly")
	assert_gt(catalog.listings.size(), 8, "Catalog should contain ~10 listings")
	assert_eq(catalog.deals_per_day, 4, "Deals per day should be 4")
	assert_eq(catalog.flash_sale_discount, 0.5, "Flash sale discount should be 50%")

	var unowned_found: int = 0
	var owned_found: int = 0
	for listing: ShopListing in catalog.listings:
		assert_not_null(listing, "Listing should not be null")
		assert_not_null(listing.item, "Listing item should not be null")
		assert_gt(listing.get_price_cents(), 0, "Listing should have price > 0")
		assert_false(listing.get_display_name().is_empty(), "Listing has display name")
		if listing.is_owned():
			owned_found += 1
		else:
			unowned_found += 1

	assert_gt(owned_found, 0, "Catalog should have some starting owned items")
	assert_gt(unowned_found, 0, "Catalog should have some unowned items to purchase")


func test_shop_app_initialization_and_daily_deals() -> void:
	var app: ShopApp = shop_app_scene.instantiate() as ShopApp
	add_child_autoqfree(app)

	assert_eq(app.app_id, &"shop", "App ID should be 'shop'")
	assert_eq(app.display_name, "Chicly", "Display name should be 'Chicly'")
	assert_not_null(app.icon, "Shop app should have an icon")
	assert_eq(app.daily_deals.size(), 4, "Should generate 4 daily deals")
	assert_eq(app.listings_container.get_child_count(), 4, "Should have 4 listing rows in UI")


func test_declined_checkout_insufficient_funds() -> void:
	var app: ShopApp = shop_app_scene.instantiate() as ShopApp
	add_child_autoqfree(app)

	# Set wallet to 0 cents
	FinanceManager.wallet_cents = 0

	# Find an unowned listing
	var target_deal: Dictionary = {}
	for deal: Dictionary in app.daily_deals:
		var item: Resource = ResRef.load_ref(str(deal.get("item_ref", "")))
		if not InventoryManager.owns_resource(item):
			target_deal = deal
			break

	assert_false(target_deal.is_empty(), "Found unowned daily deal")
	var target_item: Resource = ResRef.load_ref(str(target_deal["item_ref"]))
	var deal_price: int = int(target_deal["deal_price_cents"])

	# Add to cart
	app.cart.add_item(target_item, deal_price)
	assert_eq(app.cart.get_item_count(), 1, "Cart has 1 item")
	assert_eq(app.cart.get_total_cents(), deal_price, "Cart total matches deal price")

	watch_signals(FinanceManager)
	watch_signals(EventBus)
	watch_signals(InventoryManager)

	# Attempt checkout
	var success: bool = app.cart.checkout()
	assert_false(success, "Checkout should fail due to insufficient funds")

	# Wallet unchanged
	assert_eq(FinanceManager.wallet_cents, 0, "Wallet remains 0")
	assert_signal_emitted(FinanceManager, "purchase_declined")

	# Cart preserved
	assert_eq(app.cart.get_item_count(), 1, "Cart is preserved on declined checkout")
	assert_false(app.cart.is_empty(), "Cart is not empty")

	# No deliveries scheduled
	assert_eq(InventoryManager.get_pending_deliveries().size(), 0, "No pending deliveries")
	assert_signal_not_emitted(EventBus, "item_purchased")
	assert_signal_not_emitted(InventoryManager, "delivery_arrived")


func test_successful_checkout_and_next_day_delivery() -> void:
	var app: ShopApp = shop_app_scene.instantiate() as ShopApp
	add_child_autoqfree(app)

	# Provide ample funds
	FinanceManager.wallet_cents = 50000
	var initial_wallet: int = FinanceManager.wallet_cents

	# Find an unowned item
	var target_deal: Dictionary = {}
	for deal: Dictionary in app.daily_deals:
		var item: Resource = ResRef.load_ref(str(deal.get("item_ref", "")))
		if not InventoryManager.owns_resource(item):
			target_deal = deal
			break

	assert_false(target_deal.is_empty(), "Found unowned daily deal")
	var target_item: Resource = ResRef.load_ref(str(target_deal["item_ref"]))
	var target_ref: String = str(target_deal["item_ref"])
	var deal_price: int = int(target_deal["deal_price_cents"])

	app.cart.add_item(target_item, deal_price)

	watch_signals(EventBus)
	watch_signals(InventoryManager)
	watch_signals(FinanceManager)

	# Checkout
	var success: bool = app.cart.checkout()
	assert_true(success, "Checkout should succeed with sufficient funds")

	# Wallet deducted
	assert_eq(FinanceManager.wallet_cents, initial_wallet - deal_price, "Wallet deducted by deal price")
	assert_signal_emitted(FinanceManager, "wallet_changed")

	# EventBus signal emitted
	assert_signal_emitted_with_parameters(EventBus, "item_purchased", [target_ref, deal_price])

	# Cart cleared
	assert_true(app.cart.is_empty(), "Cart is cleared after successful checkout")

	# Delivery scheduled for tomorrow (day 2)
	var deliveries: Array[Dictionary] = InventoryManager.get_pending_deliveries()
	assert_eq(deliveries.size(), 1, "Exactly one delivery scheduled")
	assert_eq(int(deliveries[0]["deliver_day"]), 2, "Scheduled for day 2")
	assert_eq(str(deliveries[0]["item_ref"]), target_ref, "Item ref matches purchased item")

	# Not yet in inventory
	assert_false(InventoryManager.owns_resource(target_item), "Item is not yet owned before delivery")

	# Advance 24 hours (1440 minutes) via GameClock.skip
	GameClock.skip(1440)

	# Now day 2
	assert_eq(GameClock.day, 2, "Current day is now day 2")

	# Delivery arrived signal emitted
	assert_signal_emitted(InventoryManager, "delivery_arrived")

	# Item now owned in InventoryManager
	assert_true(InventoryManager.owns_resource(target_item), "Item is now owned after delivery arrival")
	assert_eq(InventoryManager.get_pending_deliveries().size(), 0, "Pending deliveries cleared after arrival")


func test_flash_sale_activation_and_expiration_via_countdown() -> void:
	var app: ShopApp = shop_app_scene.instantiate() as ShopApp
	add_child_autoqfree(app)

	assert_false(app.is_flash_sale_active_now(), "Flash sale should initially be inactive")

	# Schedule flash sale starting at 600 min (10:00) with 120 min duration
	var flash_start_min: int = 600
	var flash_duration: int = 120
	app.schedule_flash_sale(flash_start_min, flash_duration)

	var flash_cid: StringName = StringName("shop_flash_%d" % app.current_deals_day)
	assert_true(GameClock.has_countdown(flash_cid), "Countdown shop_flash_<day> exists in GameClock")

	# Advance time to flash sale start
	var skip_to_start: int = flash_start_min - GameClock.now_minutes
	watch_signals(app)
	GameClock.skip(skip_to_start)

	assert_true(app.is_flash_sale_active_now(), "Flash sale is now active after countdown finished")
	assert_signal_emitted(app, "notification_posted")
	assert_true(app.flash_banner.visible, "Flash sale banner is visible")

	# Check pricing on listings during flash sale
	var first_deal: Dictionary = app.daily_deals[0]
	var base_price: int = int(first_deal["base_price_cents"])
	var expected_flash_price: int = maxi(100, int(round(float(base_price) * (1.0 - app.catalog.flash_sale_discount))))

	var row: ListingRow = app.listings_container.get_child(0) as ListingRow
	assert_not_null(row, "Listing row exists")
	assert_eq(row.current_price_cents, expected_flash_price, "Listing row price reflects 50% flash discount")
	assert_true(row.flash_badge.visible, "Flash badge is visible on listing row")

	# Advance time past flash sale expiration
	var end_cid: StringName = StringName("shop_flash_end_%d" % app.current_deals_day)
	assert_true(GameClock.has_countdown(end_cid), "End countdown exists in GameClock")

	GameClock.skip(flash_duration)

	assert_false(app.is_flash_sale_active_now(), "Flash sale should expire after duration ends")
	assert_false(app.flash_banner.visible, "Flash banner hidden after expiration")

	# Listing reverts to normal deal price
	var expected_normal_deal: int = int(first_deal["deal_price_cents"])
	row = app.listings_container.get_child(0) as ListingRow
	assert_eq(row.current_price_cents, expected_normal_deal, "Listing row reverts to normal deal price")
	assert_false(row.flash_badge.visible, "Flash badge hidden after expiration")


func test_shop_app_to_dict_and_from_dict_json_round_trip() -> void:
	var app: ShopApp = shop_app_scene.instantiate() as ShopApp
	add_child_autoqfree(app)

	# Setup state: active flash sale and items in cart
	app.start_flash_sale(90)
	var sample_item: Resource = catalog.listings[0].item
	app.cart.add_item(sample_item, 1500, 2)

	var saved_dict: Dictionary = app.to_dict()

	# Assert JSON serializable
	var json_str: String = JSON.stringify(saved_dict)
	assert_false(json_str.is_empty(), "ShopApp state serializes to JSON string")

	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary, "Parsed JSON is a dictionary")

	# Instantiate a fresh app and restore
	var app2: ShopApp = shop_app_scene.instantiate() as ShopApp
	add_child_autoqfree(app2)
	app2.from_dict(parsed as Dictionary)

	assert_eq(app2.current_deals_day, app.current_deals_day, "Current deals day matches")
	assert_eq(app2.is_flash_sale_active_now(), true, "Flash sale active state restored")
	assert_eq(app2.flash_sale_end_min, app.flash_sale_end_min, "Flash sale end min matches")
	assert_eq(app2.daily_deals.size(), app.daily_deals.size(), "Daily deals count matches")
	assert_eq(app2.cart.get_item_count(), 2, "Cart item count matches")
	assert_eq(app2.cart.get_total_cents(), 3000, "Cart total cents matches")


func test_inventory_manager_deliveries_round_trip() -> void:
	var item1: Resource = catalog.listings[0].item
	var item2: Resource = catalog.listings[1].item

	InventoryManager.add_delivery(item1, 2)
	InventoryManager.add_delivery(item2, 3)

	var saved_dict: Dictionary = InventoryManager.to_dict()
	assert_true(saved_dict.has("pending_deliveries"), "Inventory save includes pending deliveries")

	var json_str: String = JSON.stringify(saved_dict)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary, "Inventory save produces valid JSON")

	InventoryManager.reset_state()
	assert_eq(InventoryManager.get_pending_deliveries().size(), 0, "Deliveries cleared on reset")

	InventoryManager.from_dict(parsed as Dictionary)
	var restored: Array[Dictionary] = InventoryManager.get_pending_deliveries()
	assert_eq(restored.size(), 2, "Restored 2 pending deliveries")
	assert_eq(int(restored[0]["deliver_day"]), 2, "First delivery day is 2")
	assert_eq(int(restored[1]["deliver_day"]), 3, "Second delivery day is 3")


func test_phone_notification_on_delivery_arrived() -> void:
	var phone: PhoneShell = phone_scene.instantiate() as PhoneShell
	add_child_autoqfree(phone)

	# Verify shop app is registered in PhoneShell
	var shop: AppBase = phone.get_app(&"shop")
	assert_not_null(shop, "Chicly shop app should be auto-registered in PhoneShell")

	# Cancel any random day 1 flash sale countdown so delivery is the primary notification
	GameClock.cancel_countdown(StringName("shop_flash_%d" % GameClock.day))
	phone.notification_banner.clear_queue()

	watch_signals(phone.notification_banner)

	# Trigger delivery arrived
	var item: Resource = catalog.listings[0].item
	InventoryManager.add_delivery(item, 2)
	GameClock.skip(1440)

	# Notification banner should have displayed notification
	assert_signal_emitted(phone.notification_banner, "notification_displayed")
	assert_true(phone.notification_banner.is_banner_visible(), "Banner is visible")
	var notif: Dictionary = phone.notification_banner.get_current_notification()
	assert_eq(notif.get("title", ""), "Package Delivered!", "Banner title matches")



func test_ui_listing_row_owned_badge_and_cart_drawer() -> void:
	var app: ShopApp = shop_app_scene.instantiate() as ShopApp
	add_child_autoqfree(app)

	# Open cart drawer
	assert_false(app.cart_drawer.visible, "Cart drawer initially closed")
	app.toggle_cart()
	assert_true(app.cart_drawer.visible, "Cart drawer opens on toggle")

	# Close cart drawer via handle_back
	var handled: bool = app.handle_back()
	assert_true(handled, "Back handled by closing cart drawer")
	assert_false(app.cart_drawer.visible, "Cart drawer closed after handle_back")

	# Second back returns false
	var handled_again: bool = app.handle_back()
	assert_false(handled_again, "Back returns false when drawer already closed")
