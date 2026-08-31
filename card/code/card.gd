@icon("res://resources/icons/card.svg")
class_name Card extends Node2D

signal hovered(card: Card)
signal hovered_off(card: Card)
signal card_pressed(card: Card)

enum CardType { UNIT, SPELL }
const INVALID_CARD_ID: int = -1
const INVALID_BOARD_ID: int = -1

var card_id: int = INVALID_CARD_ID
var card_type: CardType = CardType.UNIT
var board_id: int = INVALID_BOARD_ID
var is_card_hide: bool = false: set = set_card_hide
var is_enemy_card: bool = false
var current_slot: CardSlot
var is_hovered: bool = false

var invalid_feedback_tween: Tween = null

func _ready() -> void:
	_update_back_sprite_visibility()

func destroy() -> void:
	if current_slot:
		current_slot.clear_slot(false)
		current_slot = null
	var parent_hand := get_parent() as Hand
	if parent_hand:
		parent_hand.remove_card(self)
	queue_free()

func set_card_hide(value: bool) -> void:
	is_card_hide = value
	_update_back_sprite_visibility()

func _update_back_sprite_visibility() -> void:
	var back_sprite := get_node_or_null("%BackCardSprite2D") as CanvasItem
	if back_sprite:
		back_sprite.visible = is_card_hide

func _on_area_2d_mouse_entered() -> void:
	is_hovered = true
	hovered.emit(self)

func _on_area_2d_mouse_exited() -> void:
	is_hovered = false
	hovered_off.emit(self)
	
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if (mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed):
			card_pressed.emit(self)
			get_viewport().set_input_as_handled()
