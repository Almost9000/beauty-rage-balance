class_name ListingRow
extends PanelContainer

signal add_to_cart_clicked(item: Resource, price_cents: int)

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var icon_fallback_label: Label = $MarginContainer/HBoxContainer/IconRect/FallbackLabel
@onready var title_label: Label = $MarginContainer/HBoxContainer/DetailsVBox/TitleLabel
@onready var category_label: Label = $MarginContainer/HBoxContainer/DetailsVBox/CategoryLabel
@onready var price_hbox: HBoxContainer = $MarginContainer/HBoxContainer/DetailsVBox/PriceHBox
@onready var original_price_label: Label = $MarginContainer/HBoxContainer/DetailsVBox/PriceHBox/OriginalPriceLabel
@onready var deal_price_label: Label = $MarginContainer/HBoxContainer/DetailsVBox/PriceHBox/DealPriceLabel
@onready var flash_badge: PanelContainer = $MarginContainer/HBoxContainer/DetailsVBox/PriceHBox/FlashBadge
@onready var flash_badge_label: Label = $MarginContainer/HBoxContainer/DetailsVBox/PriceHBox/FlashBadge/FlashBadgeLabel
@onready var owned_badge: PanelContainer = $MarginContainer/HBoxContainer/ActionVBox/OwnedBadge
@onready var add_button: Button = $MarginContainer/HBoxContainer/ActionVBox/AddButton

var current_item: Resource = null
var current_listing: ShopListing = null
var current_price_cents: int = 0
var base_price_cents: int = 0
var is_flash_active: bool = false
var discount_ratio: float = 0.0
var item_is_in_cart: bool = false


func _ready() -> void:
	if add_button and not add_button.pressed.is_connected(_on_add_button_pressed):
		add_button.pressed.connect(_on_add_button_pressed)
	_apply_ui()


func setup(deal: Dictionary, is_flash: bool, flash_discount: float, is_in_cart: bool) -> void:
	current_listing = deal.get("listing") as ShopListing
	var item_ref: String = str(deal.get("item_ref", ""))
	if current_listing != null:
		current_item = current_listing.item
	elif not item_ref.is_empty():
		current_item = ResRef.load_ref(item_ref)
		if current_item == null and ResourceLoader.exists(item_ref):
			current_item = ResourceLoader.load(item_ref)

	base_price_cents = int(deal.get("base_price_cents", 0))
	var deal_price: int = int(deal.get("deal_price_cents", base_price_cents))
	var flash_price: int = int(deal.get("flash_price_cents", maxi(100, int(round(float(base_price_cents) * (1.0 - flash_discount))))))

	is_flash_active = is_flash
	item_is_in_cart = is_in_cart
	if is_flash:
		current_price_cents = flash_price
		discount_ratio = flash_discount
	else:
		current_price_cents = deal_price
		discount_ratio = float(deal.get("discount", 0.0))

	if is_node_ready():
		_apply_ui()


func _apply_ui() -> void:
	# 1. Title & Category
	var item_name: String = ""
	var cat_name: String = ""
	if current_listing != null:
		item_name = current_listing.get_display_name()
		cat_name = current_listing.get_category_name()
	elif current_item != null:
		item_name = str(current_item.get("display_name")) if "display_name" in current_item else "Special Item"
		if current_item is ClothingItem:
			var slot_names := ["Top", "Bottom", "Dress", "Outerwear", "Shoes", "Accessory"]
			var sl: int = int(current_item.get("slot"))
			cat_name = slot_names[sl] if (sl >= 0 and sl < slot_names.size()) else "Clothing"
		elif current_item is CosmeticItem:
			var layer_names := ["Base", "Blush", "Eyeshadow", "Eyeliner", "Lipstick"]
			var ly: int = int(current_item.get("layer"))
			cat_name = "Cosmetic: " + (layer_names[ly] if (ly >= 0 and ly < layer_names.size()) else "")
		else:
			cat_name = "Accessory"

	if title_label:
		title_label.text = item_name
	if category_label:
		category_label.text = cat_name

	# 2. Icon
	var icon_tex: Texture2D = null
	if current_listing != null:
		icon_tex = current_listing.get_icon()
	elif current_item != null and "icon" in current_item:
		icon_tex = current_item.icon as Texture2D

	if icon_rect:
		if icon_tex != null:
			icon_rect.texture = icon_tex
			if icon_fallback_label:
				icon_fallback_label.visible = false
		else:
			icon_rect.texture = null
			if icon_fallback_label:
				icon_fallback_label.visible = true
				icon_fallback_label.text = item_name.substr(0, 2).to_upper()

	# 3. Prices
	if original_price_label:
		original_price_label.text = Money.format(base_price_cents)
	if deal_price_label:
		deal_price_label.text = Money.format(current_price_cents)

	# 4. Flash badge
	if flash_badge:
		flash_badge.visible = is_flash_active
		if is_flash_active and flash_badge_label:
			var pct_int: int = int(round(discount_ratio * 100.0))
			flash_badge_label.text = "⚡ " + str(pct_int) + "% OFF"

	# 5. Ownership & Action button
	var owned: bool = false
	var root: Window = null
	if Engine.get_main_loop() is SceneTree:
		root = (Engine.get_main_loop() as SceneTree).root
	var inv: Node = root.get_node_or_null("InventoryManager") if root else null
	if inv and current_item != null:
		if inv.has_method("owns_resource"):
			owned = bool(inv.call("owns_resource", current_item))
		elif current_item is ClothingItem and inv.has_method("owns"):
			owned = bool(inv.call("owns", current_item))
		elif current_item is CosmeticItem and inv.has_method("owns_cosmetic"):
			owned = bool(inv.call("owns_cosmetic", current_item))

	if owned_badge:
		owned_badge.visible = owned

	if add_button:
		if owned:
			add_button.visible = false
		else:
			add_button.visible = true
			if item_is_in_cart:
				add_button.text = "In Cart"
				add_button.disabled = true
			else:
				add_button.text = "Add to Cart"
				add_button.disabled = false


func update_flash_countdown(remaining_min: int) -> void:
	if not is_flash_active or flash_badge_label == null:
		return
	var h: int = remaining_min / 60
	var m: int = remaining_min % 60
	var time_str: String = "%dh %02dm" % [h, m] if h > 0 else "%dm" % m
	var pct: int = int(round(discount_ratio * 100.0))
	flash_badge_label.text = "⚡ " + str(pct) + "% OFF (" + time_str + ")"


func _on_add_button_pressed() -> void:
	if current_item != null:
		add_to_cart_clicked.emit(current_item, current_price_cents)
