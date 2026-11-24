class_name LegendTutorial
extends Node

## Legends tutorial, once, after the first clear of A05 OR A06 (whichever comes first):
##   1. VictoryState: unlock_legends() (Knight + Witch) -> legend_reveal.tscn (black square, click)
##   2. Zone A: Tavi points at the Collection (ZoneController)
##   3. Collection: Legends tab -> pick a legend -> hold to read the effect -> Set -> done.
## Ids: TutorialManager.LEGEND_REVEAL (legends given), LEGEND_TUTORIAL (collection part done).

const REVEAL_SCENE_PATH: String = "res://tutorial/legend_tutorial/legend_reveal.tscn"
const TRIGGER_LEVEL_IDS: Array[String] = ["A05", "A06"]
const LEGEND_IDS: Array[int] = [31000, 31001]  # Knight, Witch
## Seconds the effect stays readable after the player holds the legend.
const READ_EFFECT_TIME: float = 1.2

var _collection: Collection
var _tavi: TaviHelper


static func should_reveal() -> bool:
	if TutorialManager.is_completed(TutorialManager.LEGEND_REVEAL):
		return false

	for level_id in TRIGGER_LEVEL_IDS:
		if LevelManager.is_level_defeated(level_id):
			return true

	return false


## Gives the legends and marks the reveal as done (so A05 and A06 never both trigger it).
static func unlock_legends() -> void:
	for legend_id in LEGEND_IDS:
		LegendManager.unlock_legend(legend_id)

	TutorialManager.complete(TutorialManager.LEGEND_REVEAL)


static func is_collection_prompt_pending() -> bool:
	return (
		TutorialManager.is_completed(TutorialManager.LEGEND_REVEAL)
		and not TutorialManager.is_completed(TutorialManager.LEGEND_TUTORIAL)
	)


static func start(collection: Collection) -> void:
	var tutorial := LegendTutorial.new()
	tutorial.name = "LegendTutorial"
	collection.add_child(tutorial)
	tutorial._run.call_deferred(collection)  # after the legends are created


func _run(collection: Collection) -> void:
	_collection = collection
	_tavi = TaviHelper.create(collection)

	# 1. Legends tab.
	if not _collection.legend_panel.visible:
		_tavi.say(TaviLines.LEGEND_OPEN_TAB, TaviHelper.Face.WAVE)
		_tavi.point_at_control(_collection.legends_button, TaviHelper.ArrowSide.BOTTOM)
		await _collection.legends_tab_opened

	# 2. Pick a legend.
	var legend: LegendExample = _find_legend(LEGEND_IDS[0])

	if legend == null:
		push_warning("LegendTutorial: no legend in the collection.")
		_finish()
		return

	_tavi.say(TaviLines.LEGEND_SELECT % legend.get_legend_name(), TaviHelper.Face.POINT)
	_tavi.point_at_control(legend, TaviHelper.ArrowSide.RIGHT)
	await _collection.legend_selected

	# 3. Hold to read the full effect.
	_tavi.say(TaviLines.LEGEND_HOLD, TaviHelper.Face.PRESENT)
	_tavi.point_at_control(_collection.legend_example_show, TaviHelper.ArrowSide.LEFT)
	await _collection.legend_info_shown
	_tavi.clear_arrows()
	await get_tree().create_timer(READ_EFFECT_TIME).timeout

	# 4. Put it in the deck (skipped if the selected one is already equipped).
	if LegendManager.get_equipped_legend_id() != _collection.selected_legend_id:
		_tavi.say(TaviLines.LEGEND_SET, TaviHelper.Face.POINT)
		_tavi.point_at_control(_collection.set_legend_in_deck_button, TaviHelper.ArrowSide.LEFT)
		await _collection.legend_equipped

	_tavi.clear_arrows()
	await _tavi.say_and_wait(TaviLines.LEGEND_DONE, TaviHelper.Face.WAVE)
	_finish()


func _finish() -> void:
	TutorialManager.complete(TutorialManager.LEGEND_TUTORIAL)
	_tavi.say(TaviLines.COLLECTION_EXIT, TaviHelper.Face.WAVE)
	_tavi.point_at_control(_collection.exit_button, TaviHelper.ArrowSide.RIGHT)


func _find_legend(legend_id: int) -> LegendExample:
	var first: LegendExample = null

	for child in _collection.legends_grid_container.get_children():
		var legend := child as LegendExample

		if legend == null:
			continue

		if legend.legend_id == legend_id:
			return legend

		if first == null:
			first = legend

	return first
