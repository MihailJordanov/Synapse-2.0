class_name RewindDebugPanel
extends CanvasLayer

## TEMPORARY test buttons for TurnRewind (back 1 / 2 / 3 turns).
## Delete the RewindDebugPanel node from main_level.tscn when done.

@export var max_rounds: int = 3

@onready var rewind: TurnRewind = %TurnRewind

var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 20

	var panel := PanelContainer.new()
	panel.position = Vector2(1180, 12)
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var label := Label.new()
	label.text = "Rewind:"
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)

	for rounds in range(1, max_rounds + 1):
		var button := Button.new()
		button.text = "-%d" % rounds
		button.custom_minimum_size = Vector2(48, 36)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(rewind.request_rewind.bind(rounds))
		row.add_child(button)
		_buttons.append(button)


func _process(_delta: float) -> void:
	for index in range(_buttons.size()):
		_buttons[index].disabled = not rewind.can_rewind(index + 1)
