class_name SpellCardExample extends Control


@export var card_id: int = 0:
	set(value):
		card_id = value

		if is_node_ready():
			setup_card()

@export var show_count_deck_indicator: bool = true
@export var show_count_collection_indicator: bool = true

@onready var selection_panel: Panel = %SelectionPanel
@onready var spell_card_example_texture: TextureRect = %SpellCardExampleTexture
@onready var spell_card_example_description_rich_text_label: RichTextLabel = %SpellCardExampleDescriptionRichTextLabel
@onready var mana_label: Label = %ManaLabel
@onready var count_in_deck_info_label: RichTextLabel = %CountInDeckInfoLabel
@onready var count_in_collection_info_label: RichTextLabel = %CountInCollectionInfoLabel

var is_selected: bool = false
var collection_count: int = 0
var deck_count: int = 0
var max_deck_count: int = 0
var max_collection_count: int = 0

func _ready() -> void:
	spell_card_example_description_rich_text_label.bbcode_enabled = true
	count_in_deck_info_label.bbcode_enabled = true
	count_in_collection_info_label.bbcode_enabled = true

	setup_card()
	set_selected(false)


func setup_card() -> void:
	_clear_card()

	var card_data: Dictionary = CardManager.get_spell_card_data(
		card_id
	)

	if card_data.is_empty():
		_update_count_indicators()
		return

	_apply_texture(str(card_data.get("texture_path", "")))

	spell_card_example_description_rich_text_label.text = str(
		card_data.get("description", "")
	)

	mana_label.text = str(
		maxi(int(card_data.get("mana_cost", 0)), 0)
	)

	update_card_counts()


func _clear_card() -> void:
	spell_card_example_texture.texture = null
	spell_card_example_description_rich_text_label.text = ""
	mana_label.text = "0"

	count_in_deck_info_label.text = ""
	count_in_deck_info_label.visible = false

	count_in_collection_info_label.text = ""
	count_in_collection_info_label.visible = false


func _apply_texture(texture_path: String) -> void:
	if texture_path.is_empty():
		return

	if not ResourceLoader.exists(texture_path):
		push_warning(
			"SpellCardExample: Texture does not exist: %s"
			% texture_path
		)
		return

	var texture: Texture2D = ResourceLoader.load(
		texture_path
	) as Texture2D

	if texture == null:
		push_warning(
			"SpellCardExample: Resource is not a Texture2D: %s"
			% texture_path
		)
		return

	spell_card_example_texture.texture = texture


func set_selected(value: bool) -> void:
	is_selected = value
	selection_panel.visible = is_selected


func _update_count_indicators() -> void:
	count_in_deck_info_label.visible = (
		show_count_deck_indicator
		and card_id != 0
		and deck_count > 0
	)

	count_in_deck_info_label.text = ("%d" % deck_count)

	var collection_color: String = "#FFFFFF"

	if (
		max_collection_count > 0
		and collection_count >= max_collection_count
	):
		collection_color = "#FFE58A"

	count_in_collection_info_label.visible = (
		show_count_collection_indicator
		and card_id != 0
	)

	count_in_collection_info_label.text = (
		"[center][color=%s]%d/%d[/color][/center]"
		% [
			collection_color,
			collection_count,
			max_collection_count
		]
	)

func update_card_counts() -> void:
	collection_count = (
		CardManager.get_card_collection_count(card_id)
	)

	deck_count = (
		CardManager.get_card_deck_count(card_id)
	)

	max_deck_count = (
		CardManager.get_max_card_copies_in_deck(
			card_id
		)
	)

	max_collection_count = (
		CardManager
			.get_max_card_copies_in_collection(
				card_id
			)
	)

	_update_count_indicators()
