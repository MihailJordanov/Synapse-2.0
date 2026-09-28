class_name SpellCardExample extends Control


@export var card_id: int = 0:
	set(value):
		card_id = value

		if is_node_ready():
			setup_card()

@export var show_deck_indicator: bool = true

@onready var selection_panel: Panel = %SelectionPanel
@onready var spell_card_example_texture: TextureRect = %SpellCardExampleTexture
@onready var spell_card_example_description_rich_text_label: RichTextLabel = %SpellCardExampleDescriptionRichTextLabel
@onready var mana_label: Label = %ManaLabel
@onready var is_in_deck_texture_rect: TextureRect = %IsInDeckTextureRect

var is_selected: bool = false

func _ready() -> void:
	spell_card_example_description_rich_text_label.bbcode_enabled = true
	setup_card()
	set_selected(false)


func setup_card() -> void:
	_clear_card()

	var card_data: Dictionary = CardManager.get_spell_card_data(
		card_id
	)

	if card_data.is_empty():
		update_deck_indicator()
		return

	_apply_texture(str(card_data.get("texture_path", "")))

	spell_card_example_description_rich_text_label.text = str(
		card_data.get("description", "")
	)

	mana_label.text = str(
		maxi(int(card_data.get("mana_cost", 0)), 0)
	)

	update_deck_indicator()


func _clear_card() -> void:
	spell_card_example_texture.texture = null
	spell_card_example_description_rich_text_label.text = ""
	mana_label.text = "0"
	is_in_deck_texture_rect.visible = false


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


func update_deck_indicator() -> void:
	is_in_deck_texture_rect.visible = (
		show_deck_indicator
		and card_id != 0
		and CardManager.is_card_in_deck(card_id)
	)
