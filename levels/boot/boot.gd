extends Node

@onready var continue_button: Button = get_node_or_null("MenuCanvas/CenterContainer/VBox/ButtonsVBox/ContinueButton") as Button
@onready var new_game_button: Button = get_node_or_null("MenuCanvas/CenterContainer/VBox/ButtonsVBox/NewGameButton") as Button
@onready var quit_button: Button = get_node_or_null("MenuCanvas/CenterContainer/VBox/ButtonsVBox/QuitButton") as Button


func _ready() -> void:
	if continue_button:
		var has_saved_game: bool = false
		var sm: Node = get_node_or_null("/root/SaveManager")
		if sm and sm.has_method("has_save"):
			has_saved_game = bool(sm.call("has_save"))
		continue_button.disabled = not has_saved_game
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)

	if new_game_button and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)

	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	# Grab focus on Continue if available, otherwise New Game
	if continue_button and not continue_button.disabled:
		continue_button.grab_focus()
	elif new_game_button:
		new_game_button.grab_focus()


func _on_continue_pressed() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("load_game"):
		sm.call("load_game", true)


func _on_new_game_pressed() -> void:
	# Reset state on all managers in autoload order
	GameSettings.reset_current()
	GameClock.reset_state()
	StatusManager.reset_state()
	CycleManager.reset_state()
	FinanceManager.reset_state()
	InventoryManager.reset_state()
	OutingManager.reset_state()
	NarrativeManager.reset_state()
	SceneRouter.reset_state()

	var dd: Node = get_node_or_null("/root/DayDirector")
	if dd and dd.has_method("reset_state"):
		dd.call("reset_state")

	var phone: Node = get_node_or_null("/root/Phone")
	if phone and phone.has_method("reset_state"):
		phone.call("reset_state")

	SceneRouter.change_level("res://levels/apartment/apartment.tscn", &"default")


func _on_quit_pressed() -> void:
	get_tree().quit()
