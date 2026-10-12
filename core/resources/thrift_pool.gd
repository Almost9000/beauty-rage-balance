class_name ThriftPool
extends Resource

@export var entries: Array[Dictionary] = []
@export var racks_count: int = 3
@export var items_per_rack: int = 5
@export var open_minute: int = 600
@export var close_minute: int = 1140
@export var travel_time_min: int = 20
@export var dig_time_min: int = 5


func is_open(minute_of_day: int) -> bool:
	return minute_of_day >= open_minute and minute_of_day < close_minute


func generate_racks(day: int, rng_seed: int = 0) -> Array[Array]:
	var result: Array[Array] = []
	if entries.is_empty():
		return result

	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = (rng_seed * 1000003 + day * 37) & 0x7FFFFFFF
	else:
		rng.seed = (day * 1000003 + 54321) & 0x7FFFFFFF

	var total_weight: float = 0.0
	for e: Dictionary in entries:
		var w: float = float(e.get("weight", 1.0))
		if w > 0.0:
			total_weight += w

	if total_weight <= 0.0:
		total_weight = 1.0

	for r: int in range(racks_count):
		var rack: Array = []
		for i: int in range(items_per_rack):
			var roll: float = rng.randf_range(0.0, total_weight)
			var chosen: Dictionary = {}
			var acc: float = 0.0

			for e: Dictionary in entries:
				var w: float = float(e.get("weight", 1.0))
				if w <= 0.0:
					continue
				acc += w
				if roll <= acc:
					chosen = e
					break

			if chosen.is_empty() and not entries.is_empty():
				chosen = entries[0]

			var item: ClothingItem = chosen.get("item") as ClothingItem
			if item == null and chosen.has("item_ref"):
				item = ResRef.load_ref(str(chosen["item_ref"])) as ClothingItem

			var pr: Vector2i = chosen.get("price_range_cents", Vector2i(500, 2000))
			var min_p: int = mini(pr.x, pr.y)
			var max_p: int = maxi(pr.x, pr.y)
			var price: int = rng.randi_range(min_p, max_p)

			var ref_str: String = ""
			if item != null:
				ref_str = ResRef.to_ref(item)
			elif chosen.has("item_ref"):
				ref_str = str(chosen["item_ref"])

			rack.append({
				"item": item,
				"price_cents": price,
				"item_ref": ref_str,
			})
		result.append(rack)

	return result
