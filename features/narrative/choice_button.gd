class_name ChoiceButton
extends Button

signal chosen(index: int, choice: NarrativeChoice)

const COLOR_PLACATE := Color(0.25, 0.65, 0.65, 1.0)
const COLOR_DEFLECT := Color(0.88, 0.68, 0.18, 1.0)
const COLOR_ASSERT := Color(0.92, 0.25, 0.40, 1.0)

var choice: NarrativeChoice = null
var choice_index: int = -1


func _ready() -> void:
	pressed.connect(_on_pressed)


func setup(p_choice: NarrativeChoice, p_index: int) -> void:
	choice = p_choice
	choice_index = p_index

	if choice == null:
		return

	var stance_color: Color = COLOR_PLACATE
	var stance_prefix: String = "[Placate] "

	match choice.stance:
		Enums.Stance.PLACATE:
			stance_color = COLOR_PLACATE
			stance_prefix = "[Placate] "
		Enums.Stance.DEFLECT:
			stance_color = COLOR_DEFLECT
			stance_prefix = "[Deflect] "
		Enums.Stance.ASSERT:
			stance_color = COLOR_ASSERT
			stance_prefix = "[Assert] "

	text = stance_prefix + choice.text
	add_theme_color_override("font_color", stance_color)
	add_theme_color_override("font_hover_color", stance_color.lightened(0.2))
	add_theme_color_override("font_focus_color", stance_color.lightened(0.1))


func _on_pressed() -> void:
	if choice_index >= 0:
		chosen.emit(choice_index, choice)
		var nm: Node = get_node_or_null("/root/NarrativeManager")
		if nm and nm.has_method("choose"):
			nm.call("choose", choice_index)
