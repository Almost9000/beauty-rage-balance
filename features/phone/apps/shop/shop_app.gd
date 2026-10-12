class_name ShopApp
extends AppBase

@export var catalog: ShopCatalog = null
@export var listing_row_scene: PackedScene = preload("res://features/phone/apps/shop/listing_row.tscn")

var cart: Cart = Cart.new()
var daily_deals: Array[Dictionary] = []
var current_deals_day: int = 0
var is_flash_sale_active: bool = false
var flash_sale_end_min: int = -1

@onready var back_button: Button = $VBoxContainer/Header/BackButton
@onready var title_label: Label = $VBoxContainer/Header/TitleLabel
@onready var cart_toggle_button: Button = $VBoxContainer/Header/CartButton
@onready var flash_banner: PanelContainer = $VBoxContainer/FlashBanner
@onready var flash_banner_label: Label = $VBoxContainer/FlashBanner/MarginContainer/FlashLabel
@onready var status_message_panel: PanelContainer = $VBoxContainer/StatusMessagePanel
@onready var status_message_label: Label = $VBoxContainer/StatusMessagePanel/MarginContainer/StatusMessageLabel
@onready var listings_scroll: ScrollContainer = $VBoxContainer/ListingsScroll
@onready var listings_container: VBoxContainer = $VBoxContainer/ListingsScroll/ListingsContainer
@onready var cart_drawer: PanelContainer = $CartDrawer
@onready var cart_close_button: Button = $CartDrawer/VBoxContainer/CartHeader/CartCloseButton
@onready var cart_items_container: VBoxContainer = $CartDrawer/VBoxContainer/CartScroll/CartItemsContainer
@onready var cart_empty_label: Label = $CartDrawer/VBoxContainer/CartEmptyLabel
@onready var cart_subtotal_label: Label = $CartDrawer/VBoxContainer/CartFooter/SubtotalLabel
@onready var checkout_button: Button = $CartDrawer/VBoxContainer/CartFooter/CheckoutButton
@onready var cart_message_label: Label = $CartDrawer/VBoxContainer/CartFooter/CartMessageLabel


func _init() -> void:
	app_id = &"shop"
	display_name = "Chicly"
	var icon_path := "res://assets/textures/shop/shop_icon.png"
	if ResourceLoader.exists(icon_path):
		icon = load(icon_path) as Texture2D


func _ready() -> void:
	if catalog == null and ResourceLoader.exists("res://data/shop/catalog.tres"):
		catalog = load("res://data/shop/catalog.tres") as ShopCatalog

	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	if cart_toggle_button:
		cart_toggle_button.pressed.connect(toggle_cart)
	if cart_close_button:
		cart_close_button.pressed.connect(close_cart)
	if checkout_button:
		checkout_button.pressed.connect(_on_checkout_button_pressed)

	cart.cart_changed.connect(_on_cart_changed)
	cart.checkout_succeeded.connect(_on_checkout_succeeded)
	cart.checkout_failed.connect(_on_checkout_failed)

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock:
		if clock.has_signal("day_started") and not clock.day_started.is_connected(_on_day_started):
			clock.day_started.connect(_on_day_started)
		if clock.has_signal("countdown_finished") and not clock.countdown_finished.is_connected(_on_countdown_finished):
			clock.countdown_finished.connect(_on_countdown_finished)
		if clock.has_signal("minute_ticked") and not clock.minute_ticked.is_connected(_on_minute_ticked):
			clock.minute_ticked.connect(_on_minute_ticked)

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv:
		if inv.has_signal("delivery_arrived") and not inv.delivery_arrived.is_connected(_on_delivery_arrived):
			inv.delivery_arrived.connect(_on_delivery_arrived)
		if inv.has_signal("item_added") and not inv.item_added.is_connected(_on_inventory_changed):
			inv.item_added.connect(_on_inventory_changed)
		if inv.has_signal("cosmetic_added") and not inv.cosmetic_added.is_connected(_on_inventory_changed):
			inv.cosmetic_added.connect(_on_inventory_changed)

	var current_day: int = int(clock.get("day")) if (clock and "day" in clock) else 1
	if daily_deals.is_empty() or current_deals_day != current_day:
		generate_daily_deals(current_day)
	else:
		_refresh_ui()


func open() -> void:
	super.open()
	if cart_drawer:
		cart_drawer.visible = false
	_refresh_ui()


func handle_back() -> bool:
	if cart_drawer and cart_drawer.visible:
		close_cart()
		return true
	return false


func _on_back_button_pressed() -> void:
	if cart_drawer and cart_drawer.visible:
		close_cart()
		return
	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("handle_back"):
		phone.call("handle_back")


func _on_day_started(day: int) -> void:
	generate_daily_deals(day)


func generate_daily_deals(day: int) -> void:
	current_deals_day = day
	is_flash_sale_active = false
	flash_sale_end_min = -1

	if catalog == null and ResourceLoader.exists("res://data/shop/catalog.tres"):
		catalog = load("res://data/shop/catalog.tres") as ShopCatalog

	if catalog:
		daily_deals = catalog.generate_daily_deals()

		# Roll for flash sale only if clock is not skipping time
		var clock: Node = get_node_or_null("/root/GameClock")
		var is_skipping: bool = bool(clock.get("is_skipping")) if clock else false
		if not is_skipping and randf() <= catalog.flash_sale_chance:
			var now_min: int = int(clock.get("now_minutes")) if clock else 420
			var day_base: int = (day - 1) * 1440
			var start_hour: int = randi_range(9, 16)
			var start_min: int = day_base + (start_hour * 60)
			if start_min <= now_min:
				start_min = now_min + 60
			schedule_flash_sale(start_min, catalog.flash_sale_duration_min)

	_refresh_ui()


func schedule_flash_sale(start_minute: int, duration_min: int = 120) -> void:
	var clock: Node = get_node_or_null("/root/GameClock")
	var cid := StringName("shop_flash_%d" % current_deals_day)
	if clock and clock.has_method("create_countdown"):
		clock.call("create_countdown", cid, start_minute, {
			"type": "flash_sale_start",
			"day": current_deals_day,
			"duration_min": duration_min,
		})


func start_flash_sale(duration_min: int = 120) -> void:
	is_flash_sale_active = true
	var clock: Node = get_node_or_null("/root/GameClock")
	var now_m: int = int(clock.get("now_minutes")) if clock else 0
	flash_sale_end_min = now_m + duration_min

	var cid := StringName("shop_flash_end_%d" % current_deals_day)
	if clock and clock.has_method("create_countdown"):
		clock.call("create_countdown", cid, flash_sale_end_min, {
			"type": "flash_sale_end",
			"day": current_deals_day,
		})

	var hrs: int = maxi(1, duration_min / 60)
	post_notification("⚡ FLASH SALE!", "50% off select Chicly styles for the next " + str(hrs) + " hours!")
	_refresh_ui()


func end_flash_sale() -> void:
	is_flash_sale_active = false
	flash_sale_end_min = -1
	_refresh_ui()


func is_flash_sale_active_now() -> bool:
	return is_flash_sale_active


func get_flash_sale_remaining_minutes() -> int:
	if not is_flash_sale_active or flash_sale_end_min <= 0:
		return 0
	var clock: Node = get_node_or_null("/root/GameClock")
	var now_m: int = int(clock.get("now_minutes")) if clock else 0
	return maxi(0, flash_sale_end_min - now_m)


func _on_countdown_finished(id: StringName, payload: Dictionary) -> void:
	var id_str: String = str(id)
	var ptype: String = str(payload.get("type", ""))

	if ptype == "flash_sale_start" or id == StringName("shop_flash_%d" % current_deals_day):
		var dur: int = int(payload.get("duration_min", catalog.flash_sale_duration_min if catalog else 120))
		start_flash_sale(dur)
	elif ptype == "flash_sale_end" or id_str.begins_with("shop_flash_end_") or id_str.begins_with("shop_flash_expire_"):
		end_flash_sale()


func _on_minute_ticked(_now_minute: int) -> void:
	if is_flash_sale_active:
		var rem: int = get_flash_sale_remaining_minutes()
		if rem <= 0:
			end_flash_sale()
		else:
			_update_flash_labels(rem)


func _update_flash_labels(remaining_min: int) -> void:
	var h: int = remaining_min / 60
	var m: int = remaining_min % 60
	var time_str: String = "%dh %02dm left" % [h, m] if h > 0 else "%dm left" % m

	if flash_banner_label:
		var disc: int = int(round((catalog.flash_sale_discount if catalog else 0.5) * 100.0))
		flash_banner_label.text = "⚡ FLASH SALE! " + str(disc) + "% OFF (" + time_str + ")"

	if listings_container:
		for row: Node in listings_container.get_children():
			if row is ListingRow:
				(row as ListingRow).update_flash_countdown(remaining_min)


func _refresh_ui() -> void:
	_update_header()
	_update_flash_banner()
	_populate_listings()
	_update_cart_drawer()


func _update_header() -> void:
	if cart_toggle_button:
		var count: int = cart.get_item_count()
		cart_toggle_button.text = "🛒 Cart (%d)" % count


func _update_flash_banner() -> void:
	if flash_banner:
		flash_banner.visible = is_flash_sale_active
		if is_flash_sale_active:
			_update_flash_labels(get_flash_sale_remaining_minutes())


func _populate_listings() -> void:
	if not listings_container:
		return

	for child: Node in listings_container.get_children():
		listings_container.remove_child(child)
		child.queue_free()

	var flash_disc: float = catalog.flash_sale_discount if catalog else 0.5

	for deal: Dictionary in daily_deals:
		var row: ListingRow = listing_row_scene.instantiate() as ListingRow
		if row:
			listings_container.add_child(row)
			var item_ref: String = str(deal.get("item_ref", ""))
			var itm: Resource = deal.get("listing").item if deal.has("listing") and deal["listing"] != null else ResRef.load_ref(item_ref)
			var in_cart: bool = cart.has_item(itm)

			row.setup(deal, is_flash_sale_active, flash_disc, in_cart)
			row.add_to_cart_clicked.connect(_on_row_add_to_cart_clicked)

	if is_flash_sale_active:
		_update_flash_labels(get_flash_sale_remaining_minutes())


func _on_row_add_to_cart_clicked(item: Resource, price_cents: int) -> void:
	cart.add_item(item, price_cents, 1)
	_show_status_message("Added to cart!")
	_refresh_ui()


func toggle_cart() -> void:
	if cart_drawer:
		cart_drawer.visible = not cart_drawer.visible
		if cart_drawer.visible:
			_update_cart_drawer()


func open_cart() -> void:
	if cart_drawer:
		cart_drawer.visible = true
		_update_cart_drawer()


func close_cart() -> void:
	if cart_drawer:
		cart_drawer.visible = false


func _update_cart_drawer() -> void:
	if not cart_drawer or not cart_drawer.visible:
		return

	if cart_message_label:
		cart_message_label.text = ""

	if not cart_items_container:
		return

	for child: Node in cart_items_container.get_children():
		cart_items_container.remove_child(child)
		child.queue_free()

	var is_empty: bool = cart.is_empty()
	if cart_empty_label:
		cart_empty_label.visible = is_empty

	if cart_subtotal_label:
		cart_subtotal_label.text = "Total: " + Money.format_cents(cart.get_total_cents())

	if checkout_button:
		checkout_button.disabled = is_empty
		checkout_button.text = "Checkout (%s)" % Money.format_cents(cart.get_total_cents())

	for entry: Dictionary in cart.items:
		var item: Resource = entry.get("item") as Resource
		var price: int = int(entry.get("price_cents", 0))
		var qty: int = int(entry.get("quantity", 1))

		var item_row := HBoxContainer.new()
		item_row.custom_minimum_size = Vector2(0, 32)
		item_row.theme_override_constants.separation = 8

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		var item_name: String = str(item.get("display_name")) if (item and "display_name" in item) else "Item"
		name_lbl.text = "%s (x%d)" % [item_name, qty] if qty > 1 else item_name
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_row.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.add_theme_font_size_override("font_size", 11)
		price_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
		price_lbl.text = Money.format_cents(price * qty)
		item_row.add_child(price_lbl)

		var remove_btn := Button.new()
		remove_btn.custom_minimum_size = Vector2(26, 24)
		remove_btn.focus_mode = Control.FOCUS_NONE
		remove_btn.text = "✕"
		remove_btn.add_theme_font_size_override("font_size", 10)
		remove_btn.pressed.connect(func() -> void:
			cart.remove_item(item)
		)
		item_row.add_child(remove_btn)

		cart_items_container.add_child(item_row)


func _on_cart_changed() -> void:
	_update_header()
	if cart_drawer and cart_drawer.visible:
		_update_cart_drawer()
	_populate_listings()


func _on_checkout_button_pressed() -> void:
	cart.checkout()


func _on_checkout_succeeded(items: Array[Resource], _total_cents: int) -> void:
	_show_status_message("Order placed! Arriving tomorrow morning.")
	if cart_message_label:
		cart_message_label.text = "Order placed! Arriving tomorrow morning."
		cart_message_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.55))
	_refresh_ui()


func _on_checkout_failed(reason: String) -> void:
	_show_status_message("Checkout failed: %s" % reason, true)
	if cart_message_label:
		cart_message_label.text = "Checkout failed: %s" % reason
		cart_message_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.4))


func _show_status_message(msg: String, is_error: bool = false) -> void:
	if status_message_panel and status_message_label:
		status_message_label.text = msg
		if is_error:
			status_message_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			status_message_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
		status_message_panel.visible = true

		var tween := create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(func() -> void:
			if status_message_panel:
				status_message_panel.visible = false
		)


func _on_delivery_arrived(_items: Array[Resource]) -> void:
	_refresh_ui()


func _on_inventory_changed(_item: Variant) -> void:
	_refresh_ui()


func reset_state() -> void:
	cart.clear()
	daily_deals.clear()
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("cancel_countdown"):
		if current_deals_day > 0:
			clock.call("cancel_countdown", StringName("shop_flash_%d" % current_deals_day))
			clock.call("cancel_countdown", StringName("shop_flash_end_%d" % current_deals_day))
	current_deals_day = 0
	is_flash_sale_active = false
	flash_sale_end_min = -1
	if cart_drawer:
		cart_drawer.visible = false
	if status_message_panel:
		status_message_panel.visible = false

	var current_day: int = int(clock.get("day")) if (clock and "day" in clock) else 1
	generate_daily_deals(current_day)



func to_dict() -> Dictionary:
	var deals_copy: Array[Dictionary] = []
	for d: Dictionary in daily_deals:
		deals_copy.append({
			"item_ref": str(d.get("item_ref", "")),
			"base_price_cents": int(d.get("base_price_cents", 0)),
			"discount": float(d.get("discount", 0.0)),
			"deal_price_cents": int(d.get("deal_price_cents", 0)),
			"flash_price_cents": int(d.get("flash_price_cents", 0)),
		})

	return {
		"current_deals_day": current_deals_day,
		"daily_deals": deals_copy,
		"is_flash_sale_active": is_flash_sale_active,
		"flash_sale_end_min": flash_sale_end_min,
		"cart": cart.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	current_deals_day = int(data.get("current_deals_day", 1))
	is_flash_sale_active = bool(data.get("is_flash_sale_active", false))
	flash_sale_end_min = int(data.get("flash_sale_end_min", -1))
	daily_deals.clear()

	if catalog == null and ResourceLoader.exists("res://data/shop/catalog.tres"):
		catalog = load("res://data/shop/catalog.tres") as ShopCatalog

	var raw_deals: Variant = data.get("daily_deals", [])
	if raw_deals is Array:
		for d_val: Variant in (raw_deals as Array):
			if d_val is Dictionary:
				var d: Dictionary = (d_val as Dictionary).duplicate(true)
				var ref: String = str(d.get("item_ref", ""))
				if catalog:
					d["listing"] = catalog.get_listing_by_ref(ref)
				daily_deals.append(d)

	var cart_data: Variant = data.get("cart", [])
	if cart_data is Array:
		cart.from_dict(cart_data as Array)

	_refresh_ui()
