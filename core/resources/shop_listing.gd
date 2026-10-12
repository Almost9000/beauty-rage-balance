class_name ShopListing
extends Resource

@export var item: Resource = null
@export var base_price_cents: int = 0
@export var weight: float = 1.0


func get_price_cents() -> int:
	if base_price_cents > 0:
		return base_price_cents
	if item != null and "price_cents" in item:
		return int(item.price_cents)
	return 0


func get_display_name() -> String:
	if item != null and "display_name" in item:
		return str(item.display_name)
	return ""


func get_item_id() -> StringName:
	if item != null and "id" in item:
		return StringName(str(item.id))
	return &""


func get_category_name() -> String:
	if item is ClothingItem:
		var ci := item as ClothingItem
		var slot_names := ["Top", "Bottom", "Dress", "Shoes", "Accessory"]
		if ci.slot >= 0 and ci.slot < slot_names.size():
			return slot_names[ci.slot]
		return "Clothing"
	elif item is CosmeticItem:
		var mi := item as CosmeticItem
		var layer_names := ["Base", "Blush", "Eyeshadow", "Eyeliner", "Lipstick"]
		if mi.layer >= 0 and mi.layer < layer_names.size():
			return "Cosmetic: %s" % layer_names[mi.layer]
		return "Cosmetic"
	return "Item"


func get_icon() -> Texture2D:
	if item != null and "icon" in item:
		return item.icon as Texture2D
	return null


func is_owned() -> bool:
	if item == null:
		return false
	var inv: Node = Engine.get_main_loop().root.get_node_or_null("InventoryManager") if Engine.get_main_loop() else null
	if inv:
		if inv.has_method("owns_resource"):
			return bool(inv.call("owns_resource", item))
		if item is ClothingItem and inv.has_method("owns"):
			return bool(inv.call("owns", item))
		elif item is CosmeticItem and inv.has_method("owns_cosmetic"):
			return bool(inv.call("owns_cosmetic", item))
	return false
