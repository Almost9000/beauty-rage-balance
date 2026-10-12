class_name Cart
extends RefCounted

signal cart_changed()
signal checkout_succeeded(items: Array[Resource], total_cents: int)
signal checkout_failed(reason: String)

var items: Array[Dictionary] = []


func add_item(item: Resource, price_cents: int, quantity: int = 1, listing: ShopListing = null) -> bool:
	if item == null or quantity <= 0:
		return false

	var item_ref: String = ResRef.to_ref(item)
	if item_ref.is_empty() and not item.resource_path.is_empty():
		item_ref = item.resource_path

	for entry: Dictionary in items:
		var existing_ref: String = str(entry.get("item_ref", ""))
		if entry.get("item") == item or (not item_ref.is_empty() and existing_ref == item_ref):
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			entry["price_cents"] = price_cents
			cart_changed.emit()
			return true

	items.append({
		"item": item,
		"item_ref": item_ref,
		"price_cents": price_cents,
		"quantity": quantity,
		"listing": listing,
	})
	cart_changed.emit()
	return true


func add_listing(listing: ShopListing, price_cents: int = -1, quantity: int = 1) -> bool:
	if listing == null or listing.item == null:
		return false
	var price: int = price_cents if price_cents > 0 else listing.get_price_cents()
	return add_item(listing.item, price, quantity, listing)


func remove_item(item: Resource) -> bool:
	if item == null:
		return false

	var item_ref: String = ResRef.to_ref(item)
	if item_ref.is_empty() and not item.resource_path.is_empty():
		item_ref = item.resource_path

	for i: int in range(items.size()):
		var entry: Dictionary = items[i]
		var existing_ref: String = str(entry.get("item_ref", ""))
		if entry.get("item") == item or (not item_ref.is_empty() and existing_ref == item_ref):
			items.remove_at(i)
			cart_changed.emit()
			return true

	return false


func remove_at(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	items.remove_at(index)
	cart_changed.emit()
	return true


func has_item(item: Resource) -> bool:
	if item == null:
		return false
	var item_ref: String = ResRef.to_ref(item)
	if item_ref.is_empty() and not item.resource_path.is_empty():
		item_ref = item.resource_path

	for entry: Dictionary in items:
		var existing_ref: String = str(entry.get("item_ref", ""))
		if entry.get("item") == item or (not item_ref.is_empty() and existing_ref == item_ref):
			return true
	return false


func get_total_cents() -> int:
	var total: int = 0
	for entry: Dictionary in items:
		var p: int = int(entry.get("price_cents", 0))
		var q: int = int(entry.get("quantity", 1))
		total += p * q
	return total


func get_subtotal_cents() -> int:
	return get_total_cents()


func get_item_count() -> int:
	var count: int = 0
	for entry: Dictionary in items:
		count += int(entry.get("quantity", 1))
	return count


func is_empty() -> bool:
	return items.is_empty()


func clear() -> void:
	items.clear()
	cart_changed.emit()


func checkout() -> bool:
	if items.is_empty():
		checkout_failed.emit("Cart is empty")
		return false

	var total: int = get_total_cents()
	var memo: String = "Chicly order: %d item(s)" % get_item_count()

	var root: Window = null
	if Engine.get_main_loop() is SceneTree:
		root = (Engine.get_main_loop() as SceneTree).root

	var fm: Node = root.get_node_or_null("FinanceManager") if root else null
	if fm == null:
		checkout_failed.emit("FinanceManager unavailable")
		return false

	var spent: bool = bool(fm.call("spend", total, &"shop", memo))
	if not spent:
		checkout_failed.emit("Insufficient funds")
		return false

	var clock: Node = root.get_node_or_null("GameClock") if root else null
	var current_day: int = int(clock.get("day")) if (clock and "day" in clock) else 1
	var deliver_day: int = current_day + 1

	var inv: Node = root.get_node_or_null("InventoryManager") if root else null
	var bus: Node = root.get_node_or_null("EventBus") if root else null

	var purchased_items: Array[Resource] = []

	for entry: Dictionary in items:
		var itm: Resource = entry.get("item") as Resource
		var ref: String = str(entry.get("item_ref", ""))
		var price: int = int(entry.get("price_cents", 0))
		var qty: int = int(entry.get("quantity", 1))

		for _i: int in range(qty):
			if inv and inv.has_method("add_delivery") and itm != null:
				inv.call("add_delivery", itm, deliver_day)
			if bus and bus.has_signal("item_purchased"):
				bus.item_purchased.emit(ref, price)
			if itm != null:
				purchased_items.append(itm)

	checkout_succeeded.emit(purchased_items, total)
	clear()
	return true


func to_dict() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for entry: Dictionary in items:
		list.append({
			"item_ref": str(entry.get("item_ref", "")),
			"price_cents": int(entry.get("price_cents", 0)),
			"quantity": int(entry.get("quantity", 1)),
		})
	return list


func from_dict(data: Array) -> void:
	items.clear()
	for raw_entry: Variant in data:
		if raw_entry is Dictionary:
			var d: Dictionary = raw_entry
			var ref: String = str(d.get("item_ref", ""))
			var itm: Resource = ResRef.load_ref(ref)
			if itm == null and ResourceLoader.exists(ref):
				itm = ResourceLoader.load(ref)
			if itm != null:
				items.append({
					"item": itm,
					"item_ref": ref,
					"price_cents": int(d.get("price_cents", 0)),
					"quantity": int(d.get("quantity", 1)),
					"listing": null,
				})
	cart_changed.emit()
