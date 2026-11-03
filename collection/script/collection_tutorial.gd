class_name CollectionTutorial
extends Node

## Collection tutorial (Tavi). Started by Collection._ready() until it is completed.
## Steps: select a card -> Add/Remove explained -> press Add -> press Remove
##        -> open Deck -> units/spells explained -> point at Exit (tutorial completed).
## All lines are in TaviLines (tutorial/tavi_helper/tavi_lines.gd).

## Tavi's spot in the deck tab (bottom right, over the empty spells area).
const DECK_TAB_LAYOUT_POSITION: Vector2 = Vector2(700, 560)
const DECK_TAB_BUBBLE_WIDTH: float = 620.0

var _collection: Collection
var _tavi: TaviHelper


static func start(collection: Collection) -> void:
	var tutorial := CollectionTutorial.new()
	tutorial.name = "CollectionTutorial"
	collection.add_child(tutorial)
	tutorial._run.call_deferred(collection)  # after the cards are created


func _run(collection: Collection) -> void:
	_collection = collection
	_tavi = TaviHelper.create(collection)

	# 1. Select a card. Prefer the first card that can still be added to the deck,
	#    so the Add/Remove steps always work.
	var card: UnitCardExample = _pick_card()

	if card == null:
		_tavi.hide_tavi()
		return

	var can_add: bool = CardManager.can_add_card_to_deck(card.card_id)

	_tavi.say(TaviLines.COLLECTION_SELECT_CARD, TaviHelper.Face.POINT)
	_tavi.point_at_control(card, TaviHelper.ArrowSide.RIGHT)

	while true:
		var selected_id: int = await _collection.unit_card_selected
		if selected_id == card.card_id:
			break

	# 2. Add / Remove explained.
	_tavi.point_at_control(_collection.add_unit_in_deck_button, TaviHelper.ArrowSide.LEFT)
	await _tavi.say_and_wait(TaviLines.COLLECTION_ADD_REMOVE_INFO, TaviHelper.Face.PRESENT)

	# 3. Press Add once, then Remove once.
	if can_add:
		_tavi.say(TaviLines.COLLECTION_PRESS_ADD, TaviHelper.Face.POINT)
		_tavi.point_at_control(_collection.add_unit_in_deck_button, TaviHelper.ArrowSide.LEFT)
		await _collection.unit_added_to_deck

		_tavi.say(TaviLines.COLLECTION_PRESS_REMOVE, TaviHelper.Face.POINT)
		_tavi.point_at_control(_collection.remove_unit_in_deck_button, TaviHelper.ArrowSide.LEFT)
		await _collection.unit_removed_from_deck

	# 4. Open the Deck tab.
	_tavi.say(TaviLines.COLLECTION_OPEN_DECK, TaviHelper.Face.POINT)
	_tavi.point_at_control(_collection.deck_button, TaviHelper.ArrowSide.BOTTOM)
	await _collection.deck_tab_opened

	# 5. Units (left) and spells (right).
	_tavi.set_layout(DECK_TAB_LAYOUT_POSITION, DECK_TAB_BUBBLE_WIDTH)
	_tavi.point_at_control(_collection.deck_units_scroll_container, TaviHelper.ArrowSide.TOP)
	await _tavi.say_and_wait(TaviLines.COLLECTION_DECK_UNITS, TaviHelper.Face.PRESENT)

	_tavi.point_at_control(_collection.deck_spell_scroll_container, TaviHelper.ArrowSide.TOP)
	await _tavi.say_and_wait(TaviLines.COLLECTION_DECK_SPELLS, TaviHelper.Face.WAVE)

	# 6. Exit -> done.
	TutorialManager.complete(TutorialManager.COLLECTION_TUTORIAL)
	_tavi.say(TaviLines.COLLECTION_EXIT, TaviHelper.Face.WAVE)
	_tavi.point_at_control(_collection.exit_button, TaviHelper.ArrowSide.RIGHT)


func _pick_card() -> UnitCardExample:
	var first: UnitCardExample = null

	for child in _collection.unit_cards_grid_container.get_children():
		var card := child as UnitCardExample

		if card == null:
			continue

		if first == null:
			first = card

		if CardManager.can_add_card_to_deck(card.card_id):
			return card

	return first
