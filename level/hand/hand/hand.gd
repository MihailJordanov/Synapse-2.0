class_name Hand extends Node2D

signal deck_changed

@export var height: float = 0.0
@export var is_enemy: bool = false
@export var card_spacing: float = 150.0
@export var max_arc_angle: float = 12.0
@export var arc_height_offset: float = 0.0
@export var animation_duration: float = 0.3
@export var deck_sprite: Sprite2D

var cards_in_hand: Array[Card] = []
var deck: Array[Card] = []
var _card_tweens: Dictionary = {}

func setup_deck(source_cards: Array) -> void:
	clear_hand_and_deck()
	for item in source_cards:
		var card := item as Card
		if card:
			card.is_enemy_card = is_enemy
			card.is_card_hide = is_enemy
			deck.append(card)
	deck.shuffle()

func draw_card() -> Card:
	if deck.is_empty():
		return null

	var card: Card = deck[0]
	deck.remove_at(0)

	if not is_instance_valid(card):
		push_error("Hand.draw_card: Invalid card in deck.")
		return null

	deck_changed.emit()
	add_existing_card(card)
	return card

func add_existing_card(card: Card) -> void:
	if card == null or cards_in_hand.has(card):
		return
	cards_in_hand.append(card)
	card.is_enemy_card = is_enemy
	card.is_card_hide = is_enemy
	if card.get_parent() == null:
		add_child(card)
	elif card.get_parent() != self:
		card.reparent(self, true)
	if deck_sprite:
		card.global_position = deck_sprite.global_position
		card.global_rotation = deck_sprite.global_rotation
	rearrange_hand()

func remove_card(card: Card) -> bool:
	if not cards_in_hand.has(card):
		return false
	cards_in_hand.erase(card)
	_cancel_card_tween(card)
	rearrange_hand()
	return true

func rearrange_hand() -> void:
	var size := cards_in_hand.size()
	if size == 0:
		return
	var total_width := float(size - 1) * card_spacing
	var start_x := -total_width / 2.0
	for i in range(size):
		var card := cards_in_hand[i]
		_cancel_card_tween(card)
		var center_index := float(size - 1) / 2.0
		var normalized := 0.0 if center_index <= 0.0 else (float(i) - center_index) / center_index
		var local_x := start_x + float(i) * card_spacing
		var curve_y := -pow(normalized, 2.0) * arc_height_offset
		var local_y := height + curve_y
		var target_rotation := normalized * deg_to_rad(max_arc_angle)
		if is_enemy:
			local_x = -local_x
			local_y = height - curve_y
			target_rotation = -target_rotation + PI
		var tween := card.create_tween().set_parallel(true)
		_card_tweens[card.get_instance_id()] = tween
		tween.tween_property(card, "global_position", to_global(Vector2(local_x, local_y)), animation_duration)
		tween.tween_property(card, "rotation", target_rotation, animation_duration)
		card.z_index = i

func clear_hand_and_deck() -> void:
	for card in cards_in_hand + deck:
		if is_instance_valid(card) and card.get_parent():
			card.get_parent().remove_child(card)
	cards_in_hand.clear()
	deck.clear()
	_card_tweens.clear()

func _cancel_card_tween(card: Card) -> void:
	var id := card.get_instance_id()
	if _card_tweens.has(id):
		var tween := _card_tweens[id] as Tween
		if tween and tween.is_valid():
			tween.kill()
		_card_tweens.erase(id)

func set_deck(new_deck: Array[Card]) -> void:
	deck = new_deck
	deck_changed.emit()

func get_deck_size() -> int:
	return deck.size()
