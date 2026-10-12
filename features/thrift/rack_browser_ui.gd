class_name RackBrowserUI
extends CanvasLayer

signal item_dug(rack_index: int, new_index: int, item_data: Dictionary)
signal item_added_to_basket(item_data: Dictionary)
signal closed()

@export var dig_time_min: int = 5

@onready var panel_root: Control = $PanelRoot
@onready var title_label: Label = $PanelRoot/CenterContainer/MainPanel/Header/TitleLabel
@onready var close_button: Button = $PanelRoot/CenterContainer/MainPanel/Header/CloseButton

@onready var rack_progress_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/RackProgressLabel
@onready var item_name_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/ItemNameLabel
@onready var condition_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/ConditionLabel
@onready var price_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/PriceLabel
@onready var tags_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/TagsLabel
@onready var slot_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/SlotLabel

@onready var dig_button: Button = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/ButtonRow/DigButton
@onready var add_to_basket_button: Button = $PanelRoot/CenterContainer/MainPanel/ContentSplit/ItemCard/ButtonRow/AddToBasketButton

@onready var basket_items_container: VBoxContainer = $PanelRoot/CenterContainer/MainPanel/ContentSplit/BasketDrawer/BasketScroll/BasketItemsContainer
@onready var basket_count_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/BasketDrawer/BasketSummary/BasketCountLabel
@onready var basket_total_label: Label = $PanelRoot/CenterContainer/MainPanel/ContentSplit/BasketDrawer/BasketSummary/BasketTotalLabel

var is_open: bool = false
var rack_index: int = 0
var rack_items: Array = []
var current_index: int = 0
var basket: Array[Dictionary] = []

var _current_actor: Node = null


func _ready() -> void:
	if panel_root:
		panel_root.visible = false
	if close_button and not close_button.pressed.is_connected(close):
		close_button.pressed.connect(close)
	if dig_button and not dig_button.pressed.is_connected(dig):
		dig_button.pressed.connect(dig)
	if add_to_basket_button and not add_to_basket_button.pressed.is_connected(add_to_basket):
		add_to_basket_button.pressed.connect(add_to_basket)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(rack_idx: int, items: Array, initial_idx: int, shared_basket: Array[Dictionary], actor: Node = null) -> void:
	is_open = true
	rack_index = rack_idx
	rack_items = items
	current_index = clampi(initial_idx, 0, maxi(0, items.size() - 1))
	basket = shared_basket
	_current_actor = actor

	if is_instance_valid(_current_actor) and _current_actor.has_method("lock_input"):
		_current_actor.lock_input(&"rack_browser")

	if panel_root:
		panel_root.visible = true

	if title_label:
		title_label.text = "Clothing Rack #%d" % (rack_index + 1)

	_update_display()
	_update_basket_view()


func close() -> void:
	if not is_open:
		return
	is_open = false

	if panel_root:
		panel_root.visible = false

	if is_instance_valid(_current_actor) and _current_actor.has_method("unlock_input"):
		_current_actor.unlock_input(&"rack_browser")
	_current_actor = null

	closed.emit()


func dig() -> bool:
	if not is_open:
		return false
	if current_index + 1 >= rack_items.size():
		return false

	var clock: Node = get_node_or_null("/root/GameClock")
	if clock and clock.has_method("skip"):
		clock.call("skip", dig_time_min)

	current_index += 1
	_update_display()

	var cur_data: Dictionary = get_current_item_data()
	item_dug.emit(rack_index, current_index, cur_data)
	return true


func add_to_basket() -> bool:
	if not is_open:
		return false
	var cur_data: Dictionary = get_current_item_data()
	if cur_data.is_empty():
		return false

	if is_current_in_basket():
		return false

	basket.append(cur_data)
	item_added_to_basket.emit(cur_data)
	_update_display()
	_update_basket_view()
	return true


func get_current_item_data() -> Dictionary:
	if current_index >= 0 and current_index < rack_items.size():
		var val: Variant = rack_items[current_index]
		if val is Dictionary:
			return val as Dictionary
	return {}


func is_current_in_basket() -> bool:
	var cur: Dictionary = get_current_item_data()
	if cur.is_empty():
		return false
	return _is_item_in_basket(cur)


func _is_item_in_basket(item_data: Dictionary) -> bool:
	var itm: Variant = item_data.get("item")
	var ref: String = str(item_data.get("item_ref", ""))
	var price: int = int(item_data.get("price_cents", 0))

	for b: Dictionary in basket:
		if itm != null and b.get("item") == itm and int(b.get("price_cents", 0)) == price:
			return true
		if not ref.is_empty() and str(b.get("item_ref", "")) == ref and int(b.get("price_cents", 0)) == price:
			return true
	return false


func get_basket_total() -> int:
	var total: int = 0
	for b: Dictionary in basket:
		total += int(b.get("price_cents", 0))
	return total


func _update_display() -> void:
	var cur: Dictionary = get_current_item_data()
	var total_items: int = rack_items.size()

	if rack_progress_label:
		if total_items > 0:
			rack_progress_label.text = "Item %d of %d" % [current_index + 1, total_items]
		else:
			rack_progress_label.text = "Rack is empty"

	var item: ClothingItem = cur.get("item") as ClothingItem
	if item == null and cur.has("item_ref"):
		item = ResRef.load_ref(str(cur["item_ref"])) as ClothingItem

	var price: int = int(cur.get("price_cents", 0))

	if item_name_label:
		if item != null and not item.display_name.is_empty():
			item_name_label.text = item.display_name
		elif item != null:
			item_name_label.text = String(item.id)
		else:
			item_name_label.text = "Unknown Item"

	if condition_label:
		if item != null:
			var cond_pct: int = int(round(item.condition * 100.0))
			var rating_str: String = "Worn"
			if item.condition >= 0.8:
				rating_str = "Great"
			elif item.condition >= 0.65:
				rating_str = "Good"
			elif item.condition < 0.55:
				rating_str = "Distressed"
			condition_label.text = "Condition: %d%% (%s)" % [cond_pct, rating_str]
		else:
			condition_label.text = ""

	if price_label:
		price_label.text = Money.format_cents(price)

	if tags_label:
		if item != null and not item.style_tags.is_empty():
			var tag_strs: Array[String] = []
			for t: StringName in item.style_tags:
				tag_strs.append("#" + String(t))
			tags_label.text = "Tags: " + ", ".join(tag_strs)
		else:
			tags_label.text = ""

	if slot_label:
		if item != null:
			var slot_names: Dictionary = {
				Enums.Slot.TOP: "Top",
				Enums.Slot.BOTTOM: "Bottom",
				Enums.Slot.DRESS: "Dress",
				Enums.Slot.SHOES: "Shoes",
				Enums.Slot.OUTERWEAR: "Outerwear",
				Enums.Slot.ACCESSORY: "Accessory",
			}
			slot_label.text = "Slot: " + slot_names.get(item.slot, "Other")
		else:
			slot_label.text = ""

	if dig_button:
		var can_dig: bool = current_index + 1 < total_items
		dig_button.disabled = not can_dig
		if can_dig:
			dig_button.text = "Dig (5 min)"
		else:
			dig_button.text = "End of Rack"

	if add_to_basket_button:
		var in_basket: bool = is_current_in_basket()
		if cur.is_empty():
			add_to_basket_button.disabled = true
			add_to_basket_button.text = "Add to Basket"
		elif in_basket:
			add_to_basket_button.disabled = true
			add_to_basket_button.text = "In Basket"
		else:
			add_to_basket_button.disabled = false
			add_to_basket_button.text = "Add to Basket"


func _update_basket_view() -> void:
	if basket_count_label:
		basket_count_label.text = "Basket: %d items" % basket.size()
	if basket_total_label:
		basket_total_label.text = "Total: " + Money.format_cents(get_basket_total())

	if basket_items_container:
		for c: Node in basket_items_container.get_children():
			c.queue_free()

		for entry: Dictionary in basket:
			var itm: ClothingItem = entry.get("item") as ClothingItem
			if itm == null and entry.has("item_ref"):
				itm = ResRef.load_ref(str(entry["item_ref"])) as ClothingItem
			var p: int = int(entry.get("price_cents", 0))

			var row := HBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.text = itm.display_name if itm != null else "Item"
			var price_lbl := Label.new()
			price_lbl.text = Money.format_cents(p)

			row.add_child(name_lbl)
			row.add_child(price_lbl)
			basket_items_container.add_child(row)
