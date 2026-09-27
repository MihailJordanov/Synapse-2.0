class_name Collection extends CanvasLayer


@export var unit_card_example_scene: PackedScene
@export var spell_card_example_scene: PackedScene
@export var legend_example_scene: PackedScene
@export_range(1.0, 64.0, 1.0) var selection_drag_threshold: float = 16.0


@onready var units_panel: Panel = %UnitsPanel
@onready var unit_card_example_show: UnitCardExample = %UnitCardExampleShow
@onready var scroll_container: ScrollContainer = %UnitScrollContainer
@onready var unit_cards_grid_container: GridContainer = %UnitCardsGridContainer
@onready var add_unit_in_deck_button: Button = %AddUnitInDeckButton
@onready var remove_unit_in_deck_button: Button = %RemoveUnitInDeckButton

@onready var spell_panel: Panel = %SpellPanel
@onready var spell_card_examlpe_show: SpellCardExample = %SpellCardExamlpeShow
@onready var add_spell_in_deck_button: Button = %AddSpellInDeckButton
@onready var remove_spell_in_deck_button: Button = %RemoveSpellInDeckButton
@onready var spell_scroll_container: ScrollContainer = %SpellScrollContainer
@onready var spell_cards_grid_container: GridContainer = %SpellCardsGridContainer


@onready var legend_panel: Panel = %LegendPanel
@onready var legend_example_show: LegendExample = %LegendExampleShow
@onready var set_legend_in_deck_button: Button = %SetLegendInDeckButton
@onready var remove_legend_from_deck_button: Button = %RemoveLegendFromDeckButton
@onready var legend_info_panel: Panel = %LegendInfoPanel
@onready var legend_info_rich_text_label: RichTextLabel = %LegendInfoRichTextLabel
@onready var legend_scroll_container: ScrollContainer = %LegendScrollContainer
@onready var legends_grid_container: GridContainer = %LegendsGridContainer
@onready var name_legend_rich_text_label: RichTextLabel = %NameLegendRichTextLabel
@onready var press_and_hold_rich_text_label: RichTextLabel = %PressAndHoldRichTextLabel

@onready var legends_button: Button = %LegendsButton
@onready var spells_button: Button = %SpellsButton
@onready var units_button: Button = %UnitsButton


var selected_card: UnitCardExample
var selected_card_id: int = 0
var _pressed_card: UnitCardExample
var _press_position: Vector2
var _press_was_dragged: bool = false

var selected_spell_card: SpellCardExample
var selected_spell_card_id: int = 0
var _pressed_spell_card: SpellCardExample
var _spell_press_position: Vector2
var _spell_press_was_dragged: bool = false

var selected_legend_example: LegendExample
var selected_legend_id: int = 0
var _pressed_legend_example: LegendExample
var _legend_press_position: Vector2
var _legend_press_was_dragged: bool = false


func _ready() -> void:
	unit_card_example_show.visible = false
	spell_card_examlpe_show.visible = false
	legend_example_show.visible = false
	legend_info_panel.visible = false
	legend_info_rich_text_label.bbcode_enabled = true
	name_legend_rich_text_label.bbcode_enabled = true
	scroll_container.scroll_deadzone = int(selection_drag_threshold)
	spell_scroll_container.scroll_deadzone = int(selection_drag_threshold)
	legend_scroll_container.scroll_deadzone = int(selection_drag_threshold)
	legend_info_panel.mouse_filter = (Control.MOUSE_FILTER_IGNORE)
	add_unit_in_deck_button.pressed.connect(_on_add_unit_in_deck_button_pressed)
	remove_unit_in_deck_button.pressed.connect(_on_remove_unit_in_deck_button_pressed)
	add_spell_in_deck_button.pressed.connect(_on_add_spell_in_deck_button_pressed)
	remove_spell_in_deck_button.pressed.connect(_on_remove_spell_in_deck_button_pressed)
	set_legend_in_deck_button.pressed.connect(_on_set_legend_in_deck_button_pressed)
	remove_legend_from_deck_button.pressed.connect(_on_remove_legend_from_deck_button_pressed)
	legend_example_show.gui_input.connect(_on_legend_example_show_gui_input)
	legend_example_show.mouse_exited.connect(_hide_selected_legend_info)
	units_button.pressed.connect(_on_units_button_pressed)
	spells_button.pressed.connect(_on_spells_button_pressed)
	legends_button.pressed.connect(_on_legends_button_pressed)
	_show_units_panel()
	_hide_legend_deck_buttons()
	_load_legend_collection()
	_hide_unit_deck_buttons()
	_hide_spell_deck_buttons()
	_load_unit_collection()
	_load_spell_collection()


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


func _load_spell_collection() -> void:
	_clear_spell_collection()

	for card_id: int in CardManager.get_spell_collection():
		_create_spell_card_example(card_id)


func _clear_spell_collection() -> void:
	for child: Node in spell_cards_grid_container.get_children():
		child.queue_free()

	selected_spell_card = null
	selected_spell_card_id = 0
	spell_card_examlpe_show.visible = false

	_hide_spell_deck_buttons()
	
func _create_spell_card_example(card_id: int) -> void:
	if spell_card_example_scene == null:
		push_error(
			"Collection: SpellCardExample scene is not assigned."
		)
		return

	var spell_example := (
		spell_card_example_scene.instantiate()
		as SpellCardExample
	)

	if spell_example == null:
		push_error(
			"Collection: Could not instantiate SpellCardExample."
		)
		return

	spell_example.card_id = card_id
	spell_example.show_deck_indicator = false
	spell_example.mouse_filter = Control.MOUSE_FILTER_PASS

	spell_cards_grid_container.add_child(spell_example)

	spell_example.gui_input.connect(_on_spell_card_gui_input.bind(spell_example))
	
	
func _on_spell_card_gui_input(
	event: InputEvent,
	spell_example: SpellCardExample
) -> void:
	if event is InputEventMouseButton:
		_handle_spell_card_mouse_button(
			event,
			spell_example
		)

	elif event is InputEventMouseMotion:
		_handle_spell_card_mouse_motion(event)
		
func _handle_spell_card_mouse_button(
	event: InputEventMouseButton,
	spell_example: SpellCardExample
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_pressed_spell_card = spell_example
		_spell_press_position = event.global_position
		_spell_press_was_dragged = false
		return

	if _pressed_spell_card != spell_example:
		_reset_spell_press()
		return

	var movement: float = event.global_position.distance_to(
		_spell_press_position
	)

	if (
		movement <= selection_drag_threshold
		and not _spell_press_was_dragged
	):
		_select_spell_card(spell_example)

	_reset_spell_press()
	
	
func _handle_spell_card_mouse_motion(
	event: InputEventMouseMotion
) -> void:
	if _pressed_spell_card == null:
		return

	if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		return

	var movement: float = event.global_position.distance_to(
		_spell_press_position
	)

	if movement > selection_drag_threshold:
		_spell_press_was_dragged = true
		
func _reset_spell_press() -> void:
	_pressed_spell_card = null
	_spell_press_was_dragged = false
	
func _select_spell_card(
	spell_example: SpellCardExample
) -> void:
	if (
		selected_spell_card
		and selected_spell_card != spell_example
	):
		selected_spell_card.set_selected(false)

	selected_spell_card = spell_example
	selected_spell_card_id = spell_example.card_id

	selected_spell_card.set_selected(true)

	spell_card_examlpe_show.card_id = selected_spell_card_id
	spell_card_examlpe_show.visible = true

	_update_spell_deck_buttons()
	
func _hide_spell_deck_buttons() -> void:
	add_spell_in_deck_button.visible = false
	remove_spell_in_deck_button.visible = false
	
	
func _update_spell_deck_buttons() -> void:
	var has_selection: bool = (
		selected_spell_card != null
		and is_instance_valid(selected_spell_card)
		and selected_spell_card_id != 0
	)

	add_spell_in_deck_button.visible = has_selection
	remove_spell_in_deck_button.visible = has_selection

	if not has_selection:
		return

	var is_in_deck: bool = CardManager.is_card_in_deck(
		selected_spell_card_id
	)

	add_spell_in_deck_button.disabled = is_in_deck
	remove_spell_in_deck_button.disabled = not is_in_deck
	
	
func _on_add_spell_in_deck_button_pressed() -> void:
	if selected_spell_card_id == 0:
		return

	if CardManager.add_card_to_deck(
		selected_spell_card_id
	):
		_update_selected_spell_card_deck_state()
		
func _on_remove_spell_in_deck_button_pressed() -> void:
	if selected_spell_card_id == 0:
		return

	if CardManager.remove_card_from_deck(
		selected_spell_card_id
	):
		_update_selected_spell_card_deck_state()
		
func _update_selected_spell_card_deck_state() -> void:
	if (
		selected_spell_card
		and is_instance_valid(selected_spell_card)
	):
		selected_spell_card.update_deck_indicator()

	spell_card_examlpe_show.update_deck_indicator()
	_update_spell_deck_buttons()

func _load_legend_collection() -> void:
	_clear_legend_collection()

	for legend_id: int in (
		LegendManager.get_unlocked_legend_ids()
	):
		_create_legend_example(legend_id)
		

func _clear_legend_collection() -> void:
	for child: Node in legends_grid_container.get_children():
		child.queue_free()

	selected_legend_example = null
	selected_legend_id = 0

	legend_example_show.visible = false
	legend_info_panel.visible = false
	name_legend_rich_text_label.text = ""

	_hide_legend_deck_buttons()
	
	
func _create_legend_example(legend_id: int) -> void:
	if legend_example_scene == null:
		push_error(
			"Collection: LegendExample scene is not assigned."
		)
		return

	var legend_example := (
		legend_example_scene.instantiate()
		as LegendExample
	)

	if legend_example == null:
		push_error(
			"Collection: Could not instantiate LegendExample."
		)
		return

	legend_example.legend_id = legend_id
	legend_example.mouse_filter = Control.MOUSE_FILTER_PASS

	legends_grid_container.add_child(legend_example)

	legend_example.gui_input.connect(
		_on_legend_example_gui_input.bind(
			legend_example
		)
	)
	
	
func _on_legend_example_gui_input(
	event: InputEvent,
	legend_example: LegendExample
) -> void:
	if event is InputEventMouseButton:
		_handle_legend_mouse_button(
			event,
			legend_example
		)

	elif event is InputEventMouseMotion:
		_handle_legend_mouse_motion(event)
		
func _handle_legend_mouse_button(
	event: InputEventMouseButton,
	legend_example: LegendExample
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_pressed_legend_example = legend_example
		_legend_press_position = event.global_position
		_legend_press_was_dragged = false
		return

	if _pressed_legend_example != legend_example:
		_reset_legend_press()
		return

	var movement: float = event.global_position.distance_to(
		_legend_press_position
	)

	if (
		movement <= selection_drag_threshold
		and not _legend_press_was_dragged
	):
		_select_legend(legend_example)

	_reset_legend_press()
	
func _handle_legend_mouse_motion(
	event: InputEventMouseMotion
) -> void:
	if _pressed_legend_example == null:
		return

	if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		return

	var movement: float = event.global_position.distance_to(
		_legend_press_position
	)

	if movement > selection_drag_threshold:
		_legend_press_was_dragged = true
		
func _reset_legend_press() -> void:
	_pressed_legend_example = null
	_legend_press_was_dragged = false
	
func _select_legend(
	legend_example: LegendExample
) -> void:
	if (
		selected_legend_example
		and selected_legend_example != legend_example
	):
		selected_legend_example.set_selected(false)

	selected_legend_example = legend_example
	selected_legend_id = legend_example.legend_id

	selected_legend_example.set_selected(true)

	legend_example_show.legend_id = selected_legend_id
	legend_example_show.visible = true
	legend_example_show.set_selected(false)

	name_legend_rich_text_label.text = (
		"[center][font_size=42][color=#FFD966]"
		+ legend_example.legend_name
		+ "[/color][/font_size][/center]"
	)

	_update_legend_deck_buttons()
	
func _hide_legend_deck_buttons() -> void:
	set_legend_in_deck_button.visible = false
	remove_legend_from_deck_button.visible = false
	press_and_hold_rich_text_label.visible = false
	
func _update_legend_deck_buttons() -> void:
	var has_selection: bool = (
		selected_legend_example != null
		and is_instance_valid(
			selected_legend_example
		)
		and selected_legend_id != 0
	)

	set_legend_in_deck_button.visible = has_selection
	remove_legend_from_deck_button.visible = has_selection
	press_and_hold_rich_text_label.visible = has_selection

	if not has_selection:
		return

	var equipped_legend_id: int = (
		LegendManager.get_equipped_legend_id()
	)

	var selected_is_equipped: bool = (
		equipped_legend_id == selected_legend_id
	)

	set_legend_in_deck_button.disabled = (
		selected_is_equipped
	)

	remove_legend_from_deck_button.disabled = (
		not selected_is_equipped
	)
	
func _on_set_legend_in_deck_button_pressed() -> void:
	if selected_legend_id == 0:
		return

	if LegendManager.equip_legend(
		selected_legend_id
	):
		_update_all_legend_deck_indicators()
		_update_legend_deck_buttons()
		

func _on_remove_legend_from_deck_button_pressed() -> void:
	if selected_legend_id == 0:
		return

	if (
		LegendManager.get_equipped_legend_id()
		!= selected_legend_id
	):
		return

	if LegendManager.unequip_legend():
		_update_all_legend_deck_indicators()
		_update_legend_deck_buttons()

func _update_all_legend_deck_indicators() -> void:
	for child: Node in legends_grid_container.get_children():
		if child is LegendExample:
			var legend_example := child as LegendExample
			legend_example.update_deck_indicator()

	legend_example_show.update_deck_indicator()
	
	
func _on_legend_example_show_gui_input(
	event: InputEvent
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_show_selected_legend_info()
	else:
		_hide_selected_legend_info()
		
		
func _show_selected_legend_info() -> void:
	var selected_legend: Legend = (
		legend_example_show.get_legend()
	)

	if selected_legend == null:
		return

	legend_info_rich_text_label.text = (
		"[center]"
		+ "[font_size=52][color=#FFD966]"
		+ selected_legend.legend_name
		+ "[/color][/font_size]"
		+ "\n\n"
		+ "[font_size=34][color=#F2F2F2]"
		+ selected_legend.description
		+ "[/color][/font_size]"
		+ "[/center]"
	)

	legend_info_panel.visible = true
	
func _hide_selected_legend_info() -> void:
	legend_info_panel.visible = false

func _on_units_button_pressed() -> void:
	_show_units_panel()

func _on_spells_button_pressed() -> void:
	_show_spells_panel()

func _on_legends_button_pressed() -> void:
	_show_legends_panel()
	
func _show_units_panel() -> void:
	units_panel.visible = true
	spell_panel.visible = false
	legend_panel.visible = false

func _show_spells_panel() -> void:
	units_panel.visible = false
	spell_panel.visible = true
	legend_panel.visible = false

func _show_legends_panel() -> void:
	units_panel.visible = false
	spell_panel.visible = false
	legend_panel.visible = true
