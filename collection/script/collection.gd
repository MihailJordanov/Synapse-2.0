class_name Collection extends CanvasLayer


const MIN_UNIT_DECK_CARDS: int = 10
const MAX_UNIT_DECK_CARDS: int = 40

const MIN_SPELL_DECK_CARDS: int = 0
const MAX_SPELL_DECK_CARDS: int = 15

const DECK_COUNT_DEFAULT_COLOR: String = "#FFFFFF"
const DECK_COUNT_FULL_COLOR: String = "#FFE58A"
const DECK_COUNT_INVALID_COLOR: String = "#FF5555"

const DECK_COUNT_POP_SCALE: Vector2 = Vector2(1.1, 1.1)
const DECK_COUNT_POP_DURATION: float = 0.08

const DEFAULT_DECK_LEGEND_ICON: Texture2D = preload("uid://xciqo3d2po72")

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
@onready var unit_deck_count_rich_text_label: RichTextLabel = %UnitDeckCountRichTextLabel

@onready var spell_panel: Panel = %SpellPanel
@onready var spell_card_examlpe_show: SpellCardExample = %SpellCardExamlpeShow
@onready var add_spell_in_deck_button: Button = %AddSpellInDeckButton
@onready var remove_spell_in_deck_button: Button = %RemoveSpellInDeckButton
@onready var spell_scroll_container: ScrollContainer = %SpellScrollContainer
@onready var spell_cards_grid_container: GridContainer = %SpellCardsGridContainer
@onready var spell_deck_count_rich_text_label: RichTextLabel = %SpellDeckCountRichTextLabel


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

@onready var deck_panel: Panel = %DeckPanel
@onready var deck_legend_example: LegendExample = %DeckLegendExample
@onready var deck_legend_name_label: RichTextLabel = %DeckLegendNameLabel
@onready var deck_info_label: RichTextLabel = %DeckInfoLabel
@onready var deck_units_scroll_container: ScrollContainer = %DeckUnitsScrollContainer
@onready var deck_spell_scroll_container: ScrollContainer = %DeckSpellScrollContainer
@onready var deck_legend_info_panel: Panel = %DeckLegendInfoPanel
@onready var deck_legend_info_rich_text_label: RichTextLabel = %DeckLegendInfoRichTextLabel
@onready var deck_units_grid_container: GridContainer = %DeckUnitsGridContainer
@onready var deck_spell_grid_container: GridContainer = %DeckSpellGridContainer




@onready var legends_button: Button = %LegendsButton
@onready var spells_button: Button = %SpellsButton
@onready var units_button: Button = %UnitsButton
@onready var deck_button: Button = %DeckButton


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

var _unit_count_tween: Tween
var _spell_count_tween: Tween

var _deck_legend: Legend

func _ready() -> void:
	await get_tree().process_frame
	unit_deck_count_rich_text_label.bbcode_enabled = true
	spell_deck_count_rich_text_label.bbcode_enabled = true
	unit_deck_count_rich_text_label.pivot_offset = (unit_deck_count_rich_text_label.size / 2.0)
	spell_deck_count_rich_text_label.pivot_offset = (spell_deck_count_rich_text_label.size / 2.0)
	_refresh_deck_counts(false)
	deck_panel.visible = false
	deck_legend_info_panel.visible = false
	deck_legend_name_label.bbcode_enabled = true
	deck_info_label.bbcode_enabled = true
	deck_legend_info_rich_text_label.bbcode_enabled = true
	deck_legend_info_panel.mouse_filter = (Control.MOUSE_FILTER_IGNORE)
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
	deck_button.pressed.connect(_on_deck_button_pressed)
	deck_legend_example.gui_input.connect(_on_deck_legend_example_gui_input)
	deck_legend_example.mouse_exited.connect(_hide_deck_legend_info)
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
	card_example.show_count_deck_indicator = true
	card_example.show_count_collection_indicator = true
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
	unit_deck_count_rich_text_label.visible = false
	
func _update_unit_deck_buttons() -> void:
	var has_selection: bool = (
		selected_card != null
		and is_instance_valid(selected_card)
		and selected_card_id != 0
	)

	add_unit_in_deck_button.visible = has_selection
	remove_unit_in_deck_button.visible = has_selection
	unit_deck_count_rich_text_label.visible = has_selection

	if not has_selection:
		return

	_update_unit_deck_limit_buttons(
		CardManager.get_unit_deck().size()
	)
	
	
func _on_add_unit_in_deck_button_pressed() -> void:
	if selected_card_id == 0:
		return

	if CardManager.add_card_to_deck(selected_card_id):
		_update_selected_card_deck_state()
		_update_unit_deck_count(
			CardManager.get_unit_deck().size(),
			true
		)


func _on_remove_unit_in_deck_button_pressed() -> void:
	if selected_card_id == 0:
		return

	if CardManager.remove_card_from_deck(selected_card_id):
		_update_selected_card_deck_state()
		_update_unit_deck_count(
			CardManager.get_unit_deck().size(),
			true
		)
		
func _update_selected_card_deck_state() -> void:
	if selected_card and is_instance_valid(selected_card):
		selected_card.update_card_counts()

	unit_card_example_show.update_card_counts()
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
	spell_example.show_count_deck_indicator = true
	spell_example.show_count_collection_indicator = true
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
	spell_deck_count_rich_text_label.visible = false
	
	
func _update_spell_deck_buttons() -> void:
	var has_selection: bool = (
		selected_spell_card != null
		and is_instance_valid(selected_spell_card)
		and selected_spell_card_id != 0
	)

	add_spell_in_deck_button.visible = has_selection
	remove_spell_in_deck_button.visible = has_selection
	spell_deck_count_rich_text_label.visible = has_selection

	if not has_selection:
		return

	_update_spell_deck_limit_buttons(
		CardManager.get_spell_deck().size()
	)
	
	
func _on_add_spell_in_deck_button_pressed() -> void:
	if selected_spell_card_id == 0:
		return

	if CardManager.add_card_to_deck(
		selected_spell_card_id
	):
		_update_selected_spell_card_deck_state()
		_update_spell_deck_count(
			CardManager.get_spell_deck().size(),
			true
		)
		
func _on_remove_spell_in_deck_button_pressed() -> void:
	if selected_spell_card_id == 0:
		return

	if CardManager.remove_card_from_deck(
		selected_spell_card_id
	):
		_update_selected_spell_card_deck_state()
		_update_spell_deck_count(
			CardManager.get_spell_deck().size(),
			true
		)
		
func _update_selected_spell_card_deck_state() -> void:
	if (
		selected_spell_card
		and is_instance_valid(selected_spell_card)
	):
		selected_spell_card.update_card_counts()

	spell_card_examlpe_show.update_card_counts()
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
	deck_panel.visible = false

func _show_spells_panel() -> void:
	units_panel.visible = false
	spell_panel.visible = true
	legend_panel.visible = false
	deck_panel.visible = false

func _show_legends_panel() -> void:
	units_panel.visible = false
	spell_panel.visible = false
	legend_panel.visible = true
	deck_panel.visible = false

func _update_deck_counts(
	unit_count: int,
	spell_count: int,
	animate: bool = false
) -> void:
	_update_unit_deck_count(unit_count)
	_update_spell_deck_count(spell_count)

	_update_unit_deck_limit_buttons(unit_count)
	_update_spell_deck_limit_buttons(spell_count)

	if animate:
		_pop_unit_deck_count()
		_pop_spell_deck_count()
		
		
func _update_unit_deck_count(
	unit_count: int,
	animate: bool = false
) -> void:
	var color: String = _get_deck_count_color(
		unit_count,
		MIN_UNIT_DECK_CARDS,
		MAX_UNIT_DECK_CARDS
	)

	unit_deck_count_rich_text_label.text = (
		"[center][color=%s]%d/%d[/color][/center]"
		% [
			color,
			unit_count,
			MAX_UNIT_DECK_CARDS
		]
	)

	_update_unit_deck_limit_buttons(unit_count)

	if animate:
		_pop_unit_deck_count()
		
		
func _update_spell_deck_count(
	spell_count: int,
	animate: bool = false
) -> void:
	var color: String = _get_deck_count_color(
		spell_count,
		MIN_SPELL_DECK_CARDS,
		MAX_SPELL_DECK_CARDS
	)

	spell_deck_count_rich_text_label.text = (
		"[center][color=%s]%d/%d[/color][/center]"
		% [
			color,
			spell_count,
			MAX_SPELL_DECK_CARDS
		]
	)

	_update_spell_deck_limit_buttons(spell_count)

	if animate:
		_pop_spell_deck_count()
		
		
func _get_deck_count_color(
	count: int,
	minimum: int,
	maximum: int
) -> String:
	if count < minimum or count > maximum:
		return DECK_COUNT_INVALID_COLOR

	if count == maximum:
		return DECK_COUNT_FULL_COLOR

	return DECK_COUNT_DEFAULT_COLOR
	

func _update_unit_deck_limit_buttons(
	unit_count: int
) -> void:
	var has_valid_card: bool = (
		selected_card_id != 0
	)

	var can_add_selected_card: bool = (
		has_valid_card
		and CardManager.can_add_card_to_deck(
			selected_card_id
		)
	)

	var can_remove_selected_card: bool = (
		has_valid_card
		and CardManager.can_remove_card_from_deck(
			selected_card_id
		)
	)

	add_unit_in_deck_button.disabled = (
		unit_count >= MAX_UNIT_DECK_CARDS
		or not can_add_selected_card
	)

	remove_unit_in_deck_button.disabled = (
		unit_count <= MIN_UNIT_DECK_CARDS
		or not can_remove_selected_card
	)
	

func _update_spell_deck_limit_buttons(
	spell_count: int
) -> void:
	var has_valid_card: bool = (
		selected_spell_card_id != 0
	)

	var can_add_selected_card: bool = (
		has_valid_card
		and CardManager.can_add_card_to_deck(
			selected_spell_card_id
		)
	)

	var can_remove_selected_card: bool = (
		has_valid_card
		and CardManager.can_remove_card_from_deck(
			selected_spell_card_id
		)
	)

	add_spell_in_deck_button.disabled = (
		spell_count >= MAX_SPELL_DECK_CARDS
		or not can_add_selected_card
	)

	remove_spell_in_deck_button.disabled = (
		spell_count <= MIN_SPELL_DECK_CARDS
		or not can_remove_selected_card
	)


func _pop_unit_deck_count() -> void:
	if (
		_unit_count_tween
		and _unit_count_tween.is_valid()
	):
		_unit_count_tween.kill()

	unit_deck_count_rich_text_label.scale = Vector2.ONE

	_unit_count_tween = create_tween()
	_unit_count_tween.set_trans(Tween.TRANS_BACK)
	_unit_count_tween.set_ease(Tween.EASE_OUT)

	_unit_count_tween.tween_property(
		unit_deck_count_rich_text_label,
		"scale",
		DECK_COUNT_POP_SCALE,
		DECK_COUNT_POP_DURATION
	)

	_unit_count_tween.tween_property(
		unit_deck_count_rich_text_label,
		"scale",
		Vector2.ONE,
		DECK_COUNT_POP_DURATION
	)
	
func _pop_spell_deck_count() -> void:
	if (
		_spell_count_tween
		and _spell_count_tween.is_valid()
	):
		_spell_count_tween.kill()

	spell_deck_count_rich_text_label.scale = Vector2.ONE

	_spell_count_tween = create_tween()
	_spell_count_tween.set_trans(Tween.TRANS_BACK)
	_spell_count_tween.set_ease(Tween.EASE_OUT)

	_spell_count_tween.tween_property(
		spell_deck_count_rich_text_label,
		"scale",
		DECK_COUNT_POP_SCALE,
		DECK_COUNT_POP_DURATION
	)

	_spell_count_tween.tween_property(
		spell_deck_count_rich_text_label,
		"scale",
		Vector2.ONE,
		DECK_COUNT_POP_DURATION
	)
	
	

	
	
func _refresh_deck_counts(
	animate: bool = false
) -> void:
	var unit_count: int = (
		CardManager.get_unit_deck().size()
	)

	var spell_count: int = (
		CardManager.get_spell_deck().size()
	)

	_update_unit_deck_count(unit_count, animate)
	_update_spell_deck_count(spell_count, animate)
	
	
func _on_deck_button_pressed() -> void:
	_show_deck_panel()
	
func _show_deck_panel() -> void:
	units_panel.visible = false
	spell_panel.visible = false
	legend_panel.visible = false
	deck_panel.visible = true

	_refresh_deck_panel()
	
func _refresh_deck_panel() -> void:
	_setup_deck_legend()
	_load_deck_unit_cards()
	_load_deck_spell_cards()
	_update_deck_info()
	
	
func _setup_deck_legend() -> void:
	_deck_legend = (
		LegendManager.get_equipped_legend()
	)

	deck_legend_example.show_deck_indicator = false
	deck_legend_example.set_selected(false)

	if _deck_legend != null:
		deck_legend_example.legend_id = (
			_deck_legend.legend_id
		)

		deck_legend_name_label.text = (
			"[center]"
			+ "[color=#D8C8FF]Legend:[/color]"
			+ "\n"
			+ "[color=#FFD966]"
			+ _deck_legend.legend_name
			+ "[/color]"
			+ "[/center]"
		)

		return

	deck_legend_example.legend_id = 0
	deck_legend_example.texture_rect.texture = (
		DEFAULT_DECK_LEGEND_ICON
	)

	deck_legend_name_label.text = (
		"[center]"
		+ "[color=#D8C8FF]Legend:[/color]"
		+ "\n"
		+ "[color=#B8B8B8]None[/color]"
		+ "[/center]"
	)
	
func _on_deck_legend_example_gui_input(
	event: InputEvent
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_show_deck_legend_info()
	else:
		_hide_deck_legend_info()
		
func _show_deck_legend_info() -> void:
	if _deck_legend == null:
		deck_legend_info_rich_text_label.text = (
			"[center]"
			+ "[color=#B8B8B8]No Legend[/color]"
			+ "\n\n"
			+ "[color=#8F96A3]No Effect[/color]"
			+ "[/center]"
		)

	else:
		deck_legend_info_rich_text_label.text = (
			"[center]"
			+ "[color=#FFD966]"
			+ _deck_legend.legend_name
			+ "[/color]"
			+ "\n\n"
			+ "[color=#F2F2F2]"
			+ _deck_legend.description
			+ "[/color]"
			+ "[/center]"
		)

	deck_legend_info_panel.visible = true
	
func _hide_deck_legend_info() -> void:
	deck_legend_info_panel.visible = false
	
func _clear_deck_grid(
	grid_container: GridContainer
) -> void:
	for child: Node in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
		
func _load_deck_unit_cards() -> void:
	_clear_deck_grid(deck_units_grid_container)

	var unit_deck: Array[int] = (
		CardManager.get_unit_deck()
	)

	unit_deck.sort()

	for card_id: int in unit_deck:
		_create_deck_unit_card(card_id)

	deck_units_scroll_container.scroll_vertical = 0
	

func _create_deck_unit_card(
	card_id: int
) -> void:
	if unit_card_example_scene == null:
		push_error(
			"Collection: UnitCardExample scene is not assigned."
		)
		return

	var card_example := (
		unit_card_example_scene.instantiate()
		as UnitCardExample
	)

	if card_example == null:
		push_error(
			"Collection: Could not instantiate UnitCardExample."
		)
		return

	card_example.card_id = card_id
	card_example.show_count_deck_indicator = false
	card_example.show_count_collection_indicator = false
	card_example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_example.focus_mode = Control.FOCUS_NONE

	deck_units_grid_container.add_child(
		card_example
	)

	card_example.set_selected(false)
	_disable_control_input(card_example)
	
func _disable_control_input(
	control: Control
) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE

	for child: Node in control.get_children():
		if child is Control:
			_disable_control_input(child as Control)
			
			
func _load_deck_spell_cards() -> void:
	_clear_deck_grid(deck_spell_grid_container)

	var spell_deck: Array[int] = (
		CardManager.get_spell_deck()
	)

	spell_deck.sort()

	for card_id: int in spell_deck:
		_create_deck_spell_card(card_id)

	deck_spell_scroll_container.scroll_vertical = 0
	
	
func _create_deck_spell_card(
	card_id: int
) -> void:
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
	spell_example.show_count_deck_indicator = false
	spell_example.show_count_collection_indicator = false
	spell_example.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_example.focus_mode = Control.FOCUS_NONE

	deck_spell_grid_container.add_child(
		spell_example
	)

	spell_example.set_selected(false)
	_disable_control_input(spell_example)
	
	
func _update_deck_info() -> void:
	var unit_count: int = (
		CardManager.get_unit_deck().size()
	)

	var spell_count: int = (
		CardManager.get_spell_deck().size()
	)

	var total_points: int = (
		CardManager.get_unit_deck_total_points()
	)

	var average_mana: float = (
		CardManager.get_spell_deck_average_mana()
	)

	deck_info_label.text = (
		"[color=#86E7FF]Units:[/color] "
		+ "[color=#FFFFFF]%d/%d[/color]"
		% [
			unit_count,
			MAX_UNIT_DECK_CARDS
		]
		+ "\n"
		+ "[color=#D7A6FF]Spells:[/color] "
		+ "[color=#FFFFFF]%d/%d[/color]"
		% [
			spell_count,
			MAX_SPELL_DECK_CARDS
		]
		+ "\n"
		+ "[color=#FFE58A]Sum points:[/color] "
		+ "[color=#FFFFFF]%d[/color]"
		% total_points
		+ "\n"
		+ "[color=#8FCBFF]Avr mana:[/color] "
		+ "[color=#FFFFFF]%.1f[/color]"
		% average_mana
	)
	
	
