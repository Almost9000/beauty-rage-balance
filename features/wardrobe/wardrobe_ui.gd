class_name WardrobeUI
extends CanvasLayer

signal closed()

const SLOTS: Array[Enums.Slot] = [
	Enums.Slot.TOP,
	Enums.Slot.BOTTOM,
	Enums.Slot.DRESS,
	Enums.Slot.SHOES,
	Enums.Slot.OUTERWEAR,
	Enums.Slot.ACCESSORY,
]

const SLOT_NAMES: Dictionary = {
	Enums.Slot.TOP: "Top",
	Enums.Slot.BOTTOM: "Bottom",
	Enums.Slot.DRESS: "Dress",
	Enums.Slot.SHOES: "Shoes",
	Enums.Slot.OUTERWEAR: "Outerwear",
	Enums.Slot.ACCESSORY: "Accessory",
}

@onready var panel_root: Control = $PanelRoot
@onready var tab_bar: TabBar = $PanelRoot/MarginContainer/VBoxContainer/SlotTabBar
@onready var items_container: VBoxContainer = $PanelRoot/MarginContainer/VBoxContainer/ScrollContainer/ItemsContainer
@onready var close_button: Button = $PanelRoot/MarginContainer/VBoxContainer/Header/CloseButton

var is_open: bool = false
var _current_slot: Enums.Slot = Enums.Slot.TOP


func _ready() -> void:
	if panel_root:
		panel_root.visible = false
	if close_button:
		close_button.pressed.connect(close)
	_setup_tabs()
	_connect_inventory()


func _connect_inventory() -> void:
	var inv: Node = get_node_or_null("/root/InventoryManager")
	if inv:
		if not inv.is_connected("outfit_changed", _on_inventory_outfit_changed):
			inv.connect("outfit_changed", _on_inventory_outfit_changed)
		if not inv.is_connected("item_added", _on_inventory_item_added):
			inv.connect("item_added", _on_inventory_item_added)


func _setup_tabs() -> void:
	if not tab_bar:
		return
	tab_bar.clear_tabs()
	for slot: Enums.Slot in SLOTS:
		var slot_name: String = SLOT_NAMES.get(slot, "Slot")
		tab_bar.add_tab(tr(slot_name))
	if not tab_bar.tab_changed.is_connected(_on_tab_changed):
		tab_bar.tab_changed.connect(_on_tab_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	if panel_root:
		panel_root.visible = true
	if tab_bar and tab_bar.current_tab >= 0 and tab_bar.current_tab < SLOTS.size():
		_current_slot = SLOTS[tab_bar.current_tab]
	else:
		_current_slot = Enums.Slot.TOP
	_populate_items()


func close() -> void:
	if not is_open:
		return
	is_open = false
	if panel_root:
		panel_root.visible = false
	closed.emit()


func _on_tab_changed(tab: int) -> void:
	if tab >= 0 and tab < SLOTS.size():
		_current_slot = SLOTS[tab]
		_populate_items()


func _on_inventory_outfit_changed(_slot: Enums.Slot, _item: ClothingItem) -> void:
	if is_open:
		_populate_items()


func _on_inventory_item_added(_item: ClothingItem) -> void:
	if is_open:
		_populate_items()


func _populate_items() -> void:
	if not items_container:
		return

	for child: Node in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()

	var inv: Node = get_node_or_null("/root/InventoryManager")
	if not inv:
		return

	var current_equipped: ClothingItem = null
	if inv.has_method("get_equipped"):
		current_equipped = inv.call("get_equipped", _current_slot) as ClothingItem

	var owned: Array[ClothingItem] = []
	if "owned_clothing" in inv:
		for item: ClothingItem in inv.owned_clothing:
			if item and item.slot == _current_slot:
				owned.append(item)

	if owned.is_empty():
		var empty_panel: PanelContainer = PanelContainer.new()
		var empty_sb := StyleBoxFlat.new()
		empty_sb.bg_color = Color(0.1, 0.12, 0.18, 0.6)
		empty_sb.corner_radius_top_left = 6
		empty_sb.corner_radius_top_right = 6
		empty_sb.corner_radius_bottom_left = 6
		empty_sb.corner_radius_bottom_right = 6
		empty_sb.content_margin_top = 24
		empty_sb.content_margin_bottom = 24
		empty_panel.add_theme_stylebox_override("panel", empty_sb)

		var empty_label: Label = Label.new()
		empty_label.text = tr("No items owned for this slot.")
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("#94a3b8"))
		empty_panel.add_child(empty_label)
		items_container.add_child(empty_panel)
		return

	for item: ClothingItem in owned:
		var card: Control = _create_item_card(item, item == current_equipped, inv)
		items_container.add_child(card)


func _create_item_card(item: ClothingItem, is_equipped: bool, inv: Node) -> Control:
	var card := PanelContainer.new()
	card.name = "ItemCard_" + str(item.id)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12
	sb.content_margin_top = 10
	sb.content_margin_right = 12
	sb.content_margin_bottom = 10

	if is_equipped:
		sb.bg_color = Color(0.12, 0.22, 0.2, 0.9)
		sb.border_color = Color(0.2, 0.83, 0.6, 0.85)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	else:
		sb.bg_color = Color(0.12, 0.14, 0.2, 0.8)
		sb.border_color = Color(0.22, 0.26, 0.36, 0.6)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1

	card.add_theme_stylebox_override("panel", sb)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	card.add_child(main_hbox)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(info_vbox)

	# Header row (Title + Equipped badge)
	var title_hbox := HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(title_hbox)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("#f8fafc"))
	title_hbox.add_child(name_label)

	if is_equipped:
		var eq_badge := Label.new()
		eq_badge.text = tr("[EQUIPPED]")
		eq_badge.add_theme_font_size_override("font_size", 11)
		eq_badge.add_theme_color_override("font_color", Color("#34d399"))
		title_hbox.add_child(eq_badge)

	# Style tags chips row
	if not item.style_tags.is_empty():
		var tags_hbox := HBoxContainer.new()
		tags_hbox.name = "TagChips"
		tags_hbox.add_theme_constant_override("separation", 6)
		info_vbox.add_child(tags_hbox)

		for tag: StringName in item.style_tags:
			var chip := PanelContainer.new()
			var chip_sb := StyleBoxFlat.new()
			chip_sb.bg_color = Color(0.18, 0.22, 0.32, 0.85)
			chip_sb.border_color = Color(0.3, 0.36, 0.5, 0.6)
			chip_sb.border_width_left = 1
			chip_sb.border_width_top = 1
			chip_sb.border_width_right = 1
			chip_sb.border_width_bottom = 1
			chip_sb.corner_radius_top_left = 4
			chip_sb.corner_radius_top_right = 4
			chip_sb.corner_radius_bottom_left = 4
			chip_sb.corner_radius_bottom_right = 4
			chip_sb.content_margin_left = 6
			chip_sb.content_margin_top = 2
			chip_sb.content_margin_right = 6
			chip_sb.content_margin_bottom = 2
			chip.add_theme_stylebox_override("panel", chip_sb)

			var tag_label := Label.new()
			tag_label.text = "#" + String(tag)
			tag_label.add_theme_font_size_override("font_size", 11)
			tag_label.add_theme_color_override("font_color", Color("#93c5fd"))
			chip.add_child(tag_label)
			tags_hbox.add_child(chip)

	# Modifiers description row
	if not item.modifiers.is_empty():
		var mod_vbox := VBoxContainer.new()
		mod_vbox.name = "ModifiersList"
		mod_vbox.add_theme_constant_override("separation", 2)
		info_vbox.add_child(mod_vbox)

		for mod: StatModifier in item.modifiers:
			if mod:
				var mod_label := Label.new()
				mod_label.text = "• " + mod.describe()
				mod_label.add_theme_font_size_override("font_size", 11)
				mod_label.add_theme_color_override("font_color", Color("#6ee7b7"))
				mod_vbox.add_child(mod_label)

	# Action button
	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(84, 34)
	action_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if is_equipped:
		action_btn.text = tr("Unequip")
		action_btn.pressed.connect(func() -> void:
			if inv and inv.has_method("unequip"):
				inv.call("unequip", _current_slot)
		)
	else:
		action_btn.text = tr("Equip")
		action_btn.pressed.connect(func() -> void:
			if inv and inv.has_method("equip"):
				inv.call("equip", item)
		)

	main_hbox.add_child(action_btn)
	return card
