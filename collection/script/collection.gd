class_name Collection extends CanvasLayer


@export var unit_card_example_scene: PackedScene
@export_range(1.0, 64.0, 1.0) var selection_drag_threshold: float = 16.0


@onready var units_panel: Panel = %UnitsPanel
@onready var unit_card_example_show: UnitCardExample = %UnitCardExampleShow
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var unit_cards_grid_container: GridContainer = %UnitCardsGridContainer
@onready var add_unit_in_deck_button: Button = %AddUnitInDeckButton
@onready var remove_unit_in_deck_button: Button = %RemoveUnitInDeckButton


var selected_card: UnitCardExample
var selected_card_id: int = 0

var _pressed_card: UnitCardExample
var _press_position: Vector2
var _press_was_dragged: bool = false


func _ready() -> void:
	unit_card_example_show.visible = false
	scroll_container.scroll_deadzone = int(selection_drag_threshold)
	add_unit_in_deck_button.pressed.connect(_on_add_unit_in_deck_button_pressed)
	remove_unit_in_deck_button.pressed.connect(_on_remove_unit_in_deck_button_pressed)
	_hide_unit_deck_buttons()
	_load_unit_collection()


func _load_unit_collection() -> void:
	_clear_unit_collection()

	for card_id: int in CardManager.get_unit_collection():
		_create_unit_card_example(card_id)


func _clear_unit_collection() -> void:
	for child: Node in unit_cards_grid_container.get_children():
		child.queue_free()

	selected_card = null
	selected_card_id = 0
	unit_card_example_show.visible = false

	_hide_unit_deck_buttons()


func _create_unit_card_example(card_id: int) -> void:
	if unit_card_example_scene == null:
		push_error("Collection: UnitCardExample scene is not assigned.")
		return

	var card_example := unit_card_example_scene.instantiate() as UnitCardExample

	if card_example == null:
		return

	card_example.card_id = card_id
	card_example.show_deck_indicator = false
	card_example.mouse_filter = Control.MOUSE_FILTER_PASS

	unit_cards_grid_container.add_child(card_example)

	card_example.gui_input.connect(
		_on_unit_card_gui_input.bind(card_example)
	)


func _on_unit_card_gui_input(
	event: InputEvent,
	card_example: UnitCardExample
) -> void:
	if event is InputEventMouseButton:
		_handle_card_mouse_button(event, card_example)

	elif event is InputEventMouseMotion:
		_handle_card_mouse_motion(event)


func _handle_card_mouse_button(
	event: InputEventMouseButton,
	card_example: UnitCardExample
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_pressed_card = card_example
		_press_position = event.global_position
		_press_was_dragged = false
		return

	if _pressed_card != card_example:
		_reset_press()
		return

	var movement: float = event.global_position.distance_to(
		_press_position
	)

	if movement <= selection_drag_threshold and not _press_was_dragged:
		_select_unit_card(card_example)

	_reset_press()


func _handle_card_mouse_motion(
	event: InputEventMouseMotion
) -> void:
	if _pressed_card == null:
		return

	if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		return

	var movement: float = event.global_position.distance_to(
		_press_position
	)

	if movement > selection_drag_threshold:
		_press_was_dragged = true


func _select_unit_card(card_example: UnitCardExample) -> void:
	if selected_card and selected_card != card_example:
		selected_card.set_selected(false)

	selected_card = card_example
	selected_card_id = card_example.card_id

	selected_card.set_selected(true)

	unit_card_example_show.card_id = selected_card_id
	unit_card_example_show.visible = true
	_update_unit_deck_buttons()


func _reset_press() -> void:
	_pressed_card = null
	_press_was_dragged = false

func _hide_unit_deck_buttons() -> void:
	add_unit_in_deck_button.visible = false
	remove_unit_in_deck_button.visible = false
	
func _update_unit_deck_buttons() -> void:
	var has_selection: bool = (
		selected_card != null
		and is_instance_valid(selected_card)
		and selected_card_id != 0
	)

	add_unit_in_deck_button.visible = has_selection
	remove_unit_in_deck_button.visible = has_selection

	if not has_selection:
		return

	var is_in_deck: bool = CardManager.is_card_in_deck(selected_card_id)

	add_unit_in_deck_button.disabled = is_in_deck
	remove_unit_in_deck_button.disabled = not is_in_deck
	
func _on_add_unit_in_deck_button_pressed() -> void:
	if selected_card_id == 0:
		return

	if CardManager.add_card_to_deck(selected_card_id):
		_update_selected_card_deck_state()


func _on_remove_unit_in_deck_button_pressed() -> void:
	if selected_card_id == 0:
		return

	if CardManager.remove_card_from_deck(selected_card_id):
		_update_selected_card_deck_state()
		
func _update_selected_card_deck_state() -> void:
	if selected_card and is_instance_valid(selected_card):
		selected_card.update_deck_indicator()

	unit_card_example_show.update_deck_indicator()
	_update_unit_deck_buttons()
