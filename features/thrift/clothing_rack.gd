class_name ClothingRack
extends Node3D

signal rack_browsed(rack_index: int)
signal item_dug(rack_index: int, new_index: int, item_data: Dictionary)
signal item_added_to_basket(item_data: Dictionary)

@export var rack_index: int = 0
@export var rack_items: Array = []
@export var current_revealed_index: int = 0

@onready var interactable: Interactable = $Interactable
@onready var rack_browser_ui: RackBrowserUI = get_node_or_null("RackBrowserUI") as RackBrowserUI

var shared_basket: Array[Dictionary] = []


func _ready() -> void:
	if interactable:
		interactable.prompt_text = "Browse Rack"
		if not interactable.interacted.is_connected(_on_interacted):
			interactable.interacted.connect(_on_interacted)

	if rack_browser_ui:
		if not rack_browser_ui.item_dug.is_connected(_on_ui_item_dug):
			rack_browser_ui.item_dug.connect(_on_ui_item_dug)
		if not rack_browser_ui.item_added_to_basket.is_connected(_on_ui_item_added):
			rack_browser_ui.item_added_to_basket.connect(_on_ui_item_added)


func setup(idx: int, items: Array, initial_revealed_idx: int, basket: Array[Dictionary]) -> void:
	rack_index = idx
	rack_items = items
	current_revealed_index = initial_revealed_idx
	shared_basket = basket


func _on_interacted(actor: Node) -> void:
	open_browser(actor)


func open_browser(actor: Node = null) -> void:
	if rack_browser_ui:
		rack_browser_ui.open(rack_index, rack_items, current_revealed_index, shared_basket, actor)
		rack_browsed.emit(rack_index)


func close_browser() -> void:
	if rack_browser_ui and rack_browser_ui.is_open:
		rack_browser_ui.close()


func _on_ui_item_dug(_idx: int, new_idx: int, item_data: Dictionary) -> void:
	current_revealed_index = new_idx
	item_dug.emit(rack_index, new_idx, item_data)


func _on_ui_item_added(item_data: Dictionary) -> void:
	item_added_to_basket.emit(item_data)
