extends Node

signal outfit_changed(slot: Enums.Slot, item: ClothingItem)
signal item_added(item: ClothingItem)

const STARTING_INVENTORY_PATH: String = "res://data/starting_inventory.tres"

var owned_clothing: Array[ClothingItem] = []
var equipped: Dictionary = {}  # Enums.Slot -> ClothingItem


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_state()


func reset_state() -> void:
	owned_clothing.clear()
	equipped.clear()

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

	return {
		"owned_clothing": owned_refs,
		"equipped": equipped_refs,
	}


func from_dict(data: Dictionary, _version: int = 1) -> void:
	owned_clothing.clear()
	equipped.clear()

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
