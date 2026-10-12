class_name ShopCatalog
extends Resource

@export var listings: Array[ShopListing] = []
@export var deals_per_day: int = 4
@export_range(0.0, 1.0, 0.01) var min_discount: float = 0.1
@export_range(0.0, 1.0, 0.01) var max_discount: float = 0.4
@export_range(0.0, 1.0, 0.01) var flash_sale_chance: float = 0.5
@export var flash_sale_duration_min: int = 120
@export_range(0.0, 1.0, 0.01) var flash_sale_discount: float = 0.5


func generate_daily_deals(count: int = -1) -> Array[Dictionary]:
	var target_count: int = count if count > 0 else deals_per_day
	var available: Array[ShopListing] = []
	for listing: ShopListing in listings:
		if listing != null and listing.item != null:
			available.append(listing)

	if available.is_empty():
		return []

	# Weighted or uniform random selection without replacement
	var chosen: Array[ShopListing] = []
	var pool: Array[ShopListing] = available.duplicate()

	while chosen.size() < target_count and not pool.is_empty():
		var total_weight: float = 0.0
		for l: ShopListing in pool:
			total_weight += maxf(0.01, l.weight)

		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		var selected_index: int = 0
		for i: int in range(pool.size()):
			cumulative += maxf(0.01, pool[i].weight)
			if roll <= cumulative:
				selected_index = i
				break

		chosen.append(pool[selected_index])
		pool.remove_at(selected_index)

	var deals: Array[Dictionary] = []
	for listing: ShopListing in chosen:
		var base_price: int = listing.get_price_cents()
		var disc: float = snappedf(randf_range(min_discount, max_discount), 0.05)
		var deal_price: int = maxi(100, int(round(float(base_price) * (1.0 - disc))))
		var flash_price: int = maxi(100, int(round(float(base_price) * (1.0 - flash_sale_discount))))
		var item_ref: String = ResRef.to_ref(listing.item)
		if item_ref.is_empty() and not listing.item.resource_path.is_empty():
			item_ref = listing.item.resource_path

		deals.append({
			"listing": listing,
			"item_ref": item_ref,
			"base_price_cents": base_price,
			"discount": disc,
			"deal_price_cents": deal_price,
			"flash_price_cents": flash_price,
		})

	return deals


func get_listing_by_item(item: Resource) -> ShopListing:
	if item == null:
		return null
	for l: ShopListing in listings:
		if l != null and l.item == item:
			return l
	return null


func get_listing_by_ref(ref: String) -> ShopListing:
	if ref.is_empty():
		return null
	for l: ShopListing in listings:
		if l != null and l.item != null:
			if ResRef.to_ref(l.item) == ref or l.item.resource_path == ref:
				return l
	return null
