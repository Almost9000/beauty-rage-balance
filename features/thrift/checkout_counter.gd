class_name CheckoutCounter
extends Node3D

signal checkout_succeeded(total_cents: int)
signal checkout_declined(total_cents: int)
signal review_opened()
signal review_closed()

@onready var interactable: Interactable = $Interactable
@onready var checkout_ui: CanvasLayer = get_node_or_null("CheckoutUI") as CanvasLayer
@onready var panel_root: Control = get_node_or_null("CheckoutUI/PanelRoot") as Control
@onready var items_container: VBoxContainer = get_node_or_null("CheckoutUI/PanelRoot/CenterContainer/MainPanel/ScrollContainer/ItemsContainer") as VBoxContainer
@onready var total_label: Label = get_node_or_null("CheckoutUI/PanelRoot/CenterContainer/MainPanel/Summary/TotalLabel") as Label
@onready var wallet_label: Label = get_node_or_null("CheckoutUI/PanelRoot/CenterContainer/MainPanel/Summary/WalletLabel") as Label
@onready var feedback_label: Label = get_node_or_null("CheckoutUI/PanelRoot/CenterContainer/MainPanel/FeedbackLabel") as Label
@onready var pay_button: Button = get_node_or_null("CheckoutUI/PanelRoot/CenterContainer/MainPanel/ButtonRow/PayButton") as Button
@onready var cancel_button: Button = get_node_or_null("CheckoutUI/PanelRoot/CenterContainer/MainPanel/ButtonRow/CancelButton") as Button

var shared_basket: Array[Dictionary] = []
var is_review_open: bool = false
var _current_actor: Node = null


func _ready() -> void:
	if interactable:
		interactable.prompt_text = "Pay & Checkout"
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	if panel_root:
		panel_root.visible = false

	if pay_button and not pay_button.pressed.is_connected(_on_pay_pressed):
		pay_button.pressed.connect(_on_pay_pressed)

	if cancel_button and not cancel_button.pressed.is_connected(close_review):
		cancel_button.pressed.connect(close_review)


func _unhandled_input(event: InputEvent) -> void:
	if not is_review_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_review()
		get_viewport().set_input_as_handled()


func set_basket(basket_ref: Array[Dictionary]) -> void:
	shared_basket = basket_ref


func _on_interacted(actor: Node) -> void:
	open_review(actor)


func open_review(actor: Node = null) -> void:
	is_review_open = true
	_current_actor = actor

	if is_instance_valid(_current_actor) and _current_actor.has_method("lock_input"):
		_current_actor.lock_input(&"checkout")

	if panel_root:
		panel_root.visible = true

	if feedback_label:
		feedback_label.text = ""

	_update_review_display()
	review_opened.emit()


func close_review() -> void:
	if not is_review_open:
		return
	is_review_open = false

	if panel_root:
		panel_root.visible = false

	if is_instance_valid(_current_actor) and _current_actor.has_method("unlock_input"):
		_current_actor.unlock_input(&"checkout")
	_current_actor = null

	review_closed.emit()


func _on_pay_pressed() -> void:
	var success: bool = checkout()
	if success:
		# Keep confirmation visible for a moment or until user cancels / finishes
		_update_review_display()


func get_basket_total() -> int:
	var total: int = 0
	for entry: Dictionary in shared_basket:
		total += int(entry.get("price_cents", 0))
	return total


func checkout() -> bool:
	if shared_basket.is_empty():
		_set_feedback("Basket is empty!", Color(0.9, 0.4, 0.4))
		return false

	var total: int = get_basket_total()
	var memo: String = "Thrift store purchase (%d items)" % shared_basket.size()

	var fm: Node = get_node_or_null("/root/FinanceManager")
	var inv: Node = get_node_or_null("/root/InventoryManager")
	var bus: Node = get_node_or_null("/root/EventBus")

	var can_afford: bool = true
	if fm and fm.has_method("can_afford"):
		can_afford = bool(fm.call("can_afford", total))

	if not can_afford:
		if fm and fm.has_method("spend"):
			fm.call("spend", total, &"thrift", memo)
		_set_feedback("Declined: Insufficient funds!", Color(0.95, 0.35, 0.35))
		checkout_declined.emit(total)
		return false

	var spent: bool = true
	if fm and fm.has_method("spend"):
		spent = bool(fm.call("spend", total, &"thrift", memo))

	if not spent:
		_set_feedback("Transaction failed.", Color(0.95, 0.35, 0.35))
		checkout_declined.emit(total)
		return false

	# Success: add to inventory and emit event
	for entry: Dictionary in shared_basket:
		var item: ClothingItem = entry.get("item") as ClothingItem
		if item == null and entry.has("item_ref"):
			item = ResRef.load_ref(str(entry["item_ref"])) as ClothingItem

		var price: int = int(entry.get("price_cents", 0))
		var ref_str: String = str(entry.get("item_ref", ""))
		if ref_str.is_empty() and item != null:
			ref_str = ResRef.to_ref(item)

		if item != null and inv and inv.has_method("add_owned"):
			inv.call("add_owned", item)

		if bus and bus.has_signal("item_purchased"):
			bus.emit_signal("item_purchased", ref_str, price)

	shared_basket.clear()
	_set_feedback("Purchase complete! Items added to wardrobe.", Color(0.4, 0.85, 0.5))
	checkout_succeeded.emit(total)
	return true


func _set_feedback(msg: String, col: Color) -> void:
	if feedback_label:
		feedback_label.text = msg
		feedback_label.add_theme_color_override("font_color", col)


func _update_review_display() -> void:
	var total: int = get_basket_total()

	if total_label:
		total_label.text = "Total: " + Money.format_cents(total)

	var fm: Node = get_node_or_null("/root/FinanceManager")
	if wallet_label and fm and "wallet_cents" in fm:
		wallet_label.text = "Wallet: " + Money.format_cents(int(fm.wallet_cents))

	if pay_button:
		pay_button.disabled = shared_basket.is_empty()

	if items_container:
		for c: Node in items_container.get_children():
			c.queue_free()

		if shared_basket.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "No items in basket"
			empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			items_container.add_child(empty_lbl)
		else:
			for entry: Dictionary in shared_basket:
				var item: ClothingItem = entry.get("item") as ClothingItem
				if item == null and entry.has("item_ref"):
					item = ResRef.load_ref(str(entry["item_ref"])) as ClothingItem
				var p: int = int(entry.get("price_cents", 0))

				var row := HBoxContainer.new()
				var name_lbl := Label.new()
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_lbl.text = item.display_name if item != null else "Item"

				var price_lbl := Label.new()
				price_lbl.text = Money.format_cents(p)
				price_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))

				row.add_child(name_lbl)
				row.add_child(price_lbl)
				items_container.add_child(row)
