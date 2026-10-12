extends Node

signal outfit_changed(slot: Enums.Slot, item: ClothingItem)
signal item_added(item: ClothingItem)
signal cosmetic_added(item: CosmeticItem)
signal look_changed(look: MakeupLook)
signal delivery_arrived(items: Array[Resource])

const STARTING_INVENTORY_PATH: String = "res://data/starting_inventory.tres"

var owned_clothing: Array[ClothingItem] = []
var equipped: Dictionary = {}  # Enums.Slot -> ClothingItem
var owned_cosmetics: Array[CosmeticItem] = []
var current_look: MakeupLook = null
var pending_deliveries: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not outfit_changed.is_connected(_on_outfit_changed):
		outfit_changed.connect(_on_outfit_changed)
	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_signal("day_started"):
		if not clock.day_started.is_connected(_on_day_started):
			clock.day_started.connect(_on_day_started)
	reset_state()


func reset_state() -> void:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("remove_by_source"):
		for s in Enums.Slot.values():
			sm.call("remove_by_source", get_slot_source_id(s))

	owned_clothing.clear()
	equipped.clear()
	owned_cosmetics.clear()
	pending_deliveries.clear()
	current_look = null

	var start_inv: StartingInventory = null
	if ResourceLoader.exists(STARTING_INVENTORY_PATH):
		start_inv = load(STARTING_INVENTORY_PATH) as StartingInventory

	if start_inv:
		for item: ClothingItem in start_inv.owned_clothing:
			if item and not owns(item):
				owned_clothing.append(item)
		for item: ClothingItem in start_inv.equipped_clothing:
			if item:
				equip(item)
		if "owned_cosmetics" in start_inv:
			for cosmetic: CosmeticItem in start_inv.owned_cosmetics:
				if cosmetic and not owns_cosmetic(cosmetic):
					owned_cosmetics.append(cosmetic)
		if "initial_look" in start_inv and start_inv.initial_look != null:
			set_look(start_inv.initial_look)
		else:
			clear_look()
	else:
		clear_look()


func add_owned(item: ClothingItem) -> void:
	if item == null:
		return
	if not owns(item):
		owned_clothing.append(item)
		item_added.emit(item)


func owns(item: ClothingItem) -> bool:
	if item == null:
		return false
	for owned: ClothingItem in owned_clothing:
		if owned == item or (owned != null and not owned.id.is_empty() and owned.id == item.id):
			return true
	return false


func add_owned_cosmetic(item: CosmeticItem) -> void:
	if item == null:
		return
	if not owns_cosmetic(item):
		owned_cosmetics.append(item)
		cosmetic_added.emit(item)


func owns_cosmetic(item: CosmeticItem) -> bool:
	if item == null:
		return false
	for owned: CosmeticItem in owned_cosmetics:
		if owned == item or (owned != null and not owned.id.is_empty() and owned.id == item.id):
			return true
	return false


func owns_resource(item: Resource) -> bool:
	if item is ClothingItem:
		return owns(item as ClothingItem)
	elif item is CosmeticItem:
		return owns_cosmetic(item as CosmeticItem)
	return false


func add_delivery(item: Resource, deliver_day: int) -> void:
	if item == null:
		return
	var ref: String = ResRef.to_ref(item)
	if ref.is_empty() and not item.resource_path.is_empty():
		ref = item.resource_path
	pending_deliveries.append({
		"item_ref": ref,
		"deliver_day": deliver_day,
	})


func get_pending_deliveries() -> Array[Dictionary]:
	return pending_deliveries.duplicate(true)


func check_deliveries(current_day: int = -1) -> Array[Resource]:
	if current_day <= 0:
		var clock: Node = get_node_or_null("/root/GameClock")
		if clock and "day" in clock:
			current_day = int(clock.day)
		else:
			current_day = 1

	var arrived_items: Array[Resource] = []
	var remaining: Array[Dictionary] = []

	for entry: Dictionary in pending_deliveries:
		var deliv_day: int = int(entry.get("deliver_day", 0))
		if deliv_day <= current_day:
			var ref: String = str(entry.get("item_ref", ""))
			var item: Resource = ResRef.load_ref(ref)
			if item == null and ResourceLoader.exists(ref):
				item = ResourceLoader.load(ref)
			if item is ClothingItem:
				add_owned(item as ClothingItem)
				arrived_items.append(item)
			elif item is CosmeticItem:
				add_owned_cosmetic(item as CosmeticItem)
				arrived_items.append(item)
			elif item != null:
				arrived_items.append(item)
		else:
			remaining.append(entry)

	pending_deliveries = remaining

	if not arrived_items.is_empty():
		delivery_arrived.emit(arrived_items)

	return arrived_items


func _on_day_started(day: int) -> void:
	check_deliveries(day)



func set_look(look: MakeupLook) -> void:
	current_look = look
	look_changed.emit(current_look)


func clear_look() -> void:
	current_look = null
	look_changed.emit(null)


func equip(item: ClothingItem) -> void:
	if item == null:
		return

	if not owns(item):
		add_owned(item)

	# Slot collision rules
	if item.slot == Enums.Slot.DRESS:
		if equipped.has(Enums.Slot.TOP):
			unequip(Enums.Slot.TOP)
		if equipped.has(Enums.Slot.BOTTOM):
			unequip(Enums.Slot.BOTTOM)
	elif item.slot == Enums.Slot.TOP or item.slot == Enums.Slot.BOTTOM:
		if equipped.has(Enums.Slot.DRESS):
			unequip(Enums.Slot.DRESS)

	equipped[item.slot] = item
	outfit_changed.emit(item.slot, item)


func unequip(slot: Enums.Slot) -> void:
	if equipped.has(slot):
		equipped.erase(slot)
		outfit_changed.emit(slot, null)


func get_equipped(slot: Enums.Slot) -> ClothingItem:
	return equipped.get(slot, null)


func to_dict() -> Dictionary:
	var owned_refs: Array[String] = []
	for item: ClothingItem in owned_clothing:
		if item:
			var ref: String = ResRef.to_ref(item)
			if not ref.is_empty():
				owned_refs.append(ref)

	var equipped_refs: Dictionary = {}
	for slot_variant: Variant in equipped.keys():
		var slot: int = int(slot_variant)
		var item: ClothingItem = equipped.get(slot)
		if item:
			var ref: String = ResRef.to_ref(item)
			if not ref.is_empty():
				equipped_refs[str(slot)] = ref

	var cosmetic_refs: Array[String] = []
	for item: CosmeticItem in owned_cosmetics:
		if item:
			var ref: String = ResRef.to_ref(item)
			if ref.is_empty() and not item.resource_path.is_empty():
				ref = item.resource_path
			if ref.is_empty():
				ref = String(item.id)
			if not ref.is_empty():
				cosmetic_refs.append(ref)

	var look_data: Variant = null
	if current_look != null:
		look_data = current_look.to_dict()

	var deliveries_copy: Array[Dictionary] = []
	for deliv: Dictionary in pending_deliveries:
		deliveries_copy.append({
			"item_ref": str(deliv.get("item_ref", "")),
			"deliver_day": int(deliv.get("deliver_day", 0)),
		})

	return {
		"owned_clothing": owned_refs,
		"equipped": equipped_refs,
		"owned_cosmetics": cosmetic_refs,
		"current_look": look_data,
		"pending_deliveries": deliveries_copy,
	}


func from_dict(data: Dictionary, _version: int = 1) -> void:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if sm and sm.has_method("remove_by_source"):
		for s in Enums.Slot.values():
			sm.call("remove_by_source", get_slot_source_id(s))

	owned_clothing.clear()
	equipped.clear()
	owned_cosmetics.clear()
	pending_deliveries.clear()

	var owned_refs: Array = data.get("owned_clothing", [])
	for ref_variant: Variant in owned_refs:
		var ref: String = str(ref_variant)
		var res: Resource = ResRef.load_ref(ref)
		if res is ClothingItem:
			owned_clothing.append(res as ClothingItem)

	var equipped_refs: Dictionary = data.get("equipped", {})
	for slot_str: Variant in equipped_refs.keys():
		var slot: int = int(str(slot_str))
		var ref: String = str(equipped_refs[slot_str])
		var res: Resource = ResRef.load_ref(ref)
		if res is ClothingItem:
			equipped[slot] = res as ClothingItem
			outfit_changed.emit(slot, res as ClothingItem)

	var cosmetic_refs: Array = data.get("owned_cosmetics", [])
	for ref_variant: Variant in cosmetic_refs:
		var ref: String = str(ref_variant)
		var res: Resource = ResRef.load_ref(ref)
		if res is CosmeticItem:
			owned_cosmetics.append(res as CosmeticItem)
		elif ResourceLoader.exists(ref):
			var loaded: Resource = ResourceLoader.load(ref)
			if loaded is CosmeticItem:
				owned_cosmetics.append(loaded as CosmeticItem)

	var raw_delivs: Variant = data.get("pending_deliveries", [])
	if raw_delivs is Array:
		for d_val: Variant in (raw_delivs as Array):
			if d_val is Dictionary:
				pending_deliveries.append({
					"item_ref": str((d_val as Dictionary).get("item_ref", "")),
					"deliver_day": int((d_val as Dictionary).get("deliver_day", 0)),
				})

	if data.has("current_look") and data["current_look"] != null and data["current_look"] is Dictionary:
		current_look = MakeupLook.from_dict(data["current_look"])
		look_changed.emit(current_look)
	else:
		current_look = null
		look_changed.emit(null)


func get_slot_source_id(slot: Enums.Slot) -> StringName:
	var slot_name: String = ""
	var keys: Array = Enums.Slot.keys()
	if slot >= 0 and slot < keys.size():
		slot_name = String(keys[slot]).to_lower()
	else:
		slot_name = str(slot).to_lower()
	return StringName("outfit:" + slot_name)


func _on_outfit_changed(slot: Enums.Slot, item: ClothingItem) -> void:
	var sm: Node = get_node_or_null("/root/StatusManager")
	if not sm:
		return
	var source_id: StringName = get_slot_source_id(slot)
	if sm.has_method("remove_by_source"):
		sm.call("remove_by_source", source_id)
	if item != null and sm.has_method("add_modifier"):
		for mod: StatModifier in item.modifiers:
			if mod:
				var mod_copy: StatModifier = mod.duplicate() as StatModifier
				mod_copy.source_id = source_id
				if mod_copy.label.is_empty():
					mod_copy.label = item.display_name
				sm.call("add_modifier", mod_copy)
