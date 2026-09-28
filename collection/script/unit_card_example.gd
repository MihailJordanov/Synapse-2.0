class_name UnitCardExample extends Control

const MAX_TYPES_COUNT: int = 8

@export var card_id: int = 0:
	set(value):
		card_id = value

		if is_node_ready():
			setup_card()
@export var show_deck_indicator: bool = true

@onready var unit_card_example_attack_h_box_container: HBoxContainer = %UnitCardExampleAttackHBoxContainer
@onready var a_sword: TextureRect = %A_Sword
@onready var a_shield: TextureRect = %A_Shield
@onready var a_axe: TextureRect = %A_Axe
@onready var a_shurikane: TextureRect = %A_Shurikane
@onready var a_wand: TextureRect = %A_Wand
@onready var a_magical_wand: TextureRect = %"A_Magical Wand"
@onready var a_mace: TextureRect = %A_Mace
@onready var a_teeth: TextureRect = %A_Teeth

@onready var unit_card_example_deffense_h_box_container: HBoxContainer = %UnitCardExampleDeffenseHBoxContainer
@onready var d_sword: TextureRect = %D_Sword
@onready var d_shield: TextureRect = %D_Shield
@onready var d_axe: TextureRect = %D_Axe
@onready var d_shurikane: TextureRect = %D_Shurikane
@onready var d_wand: TextureRect = %D_Wand
@onready var d_magical_wand: TextureRect = %"D_Magical Wand"
@onready var d_mace: TextureRect = %D_Mace
@onready var d_teeth: TextureRect = %D_Teeth

@onready var unit_card_example_card_texture: TextureRect = %UnitCardExampleCardTexture
@onready var unit_card_example_point_panel: Panel = %UnitCardExamplePointPanel
@onready var points_label: Label = %PointsLabel
@onready var selection_panel: Panel = %SelectionPanel
@onready var is_in_deck_texture_rect: TextureRect = $IsInDeckTextureRect


var is_selected: bool = false

func _ready() -> void:
	setup_card()
	set_selected(false)

func setup_card() -> void:
	_clear_card()

	var card_data: Dictionary = CardManager.get_unit_card_data(card_id)

	if card_data.is_empty():
		return

	_apply_types(card_data.get("target_types", []), true)
	_apply_types(card_data.get("source_types", []), false)
	_apply_texture(str(card_data.get("texture_path", "")))
	points_label.text = str(int(card_data.get("points", 0)))
	
	update_deck_indicator()

func _clear_card() -> void:
	unit_card_example_card_texture.texture = null
	points_label.text = "0"
	is_in_deck_texture_rect.visible = false

	for type_index in range(1, MAX_TYPES_COUNT + 1):
		var attack_icon: TextureRect = _get_icon_by_index(type_index, true)
		var defense_icon: TextureRect = _get_icon_by_index(type_index, false)

		if attack_icon:
			attack_icon.visible = false

		if defense_icon:
			defense_icon.visible = false

func _apply_types(types_data: Variant, is_target: bool) -> void:
	if not types_data is Array:
		return

	for value: Variant in types_data:
		var type_index: int = int(value)
		var icon: TextureRect = _get_icon_by_index(type_index, is_target)

		if icon:
			icon.visible = true

func _apply_texture(texture_path: String) -> void:
	if texture_path.is_empty():
		return

	if not ResourceLoader.exists(texture_path):
		push_warning(
			"UnitCardExample: Texture does not exist: %s"
			% texture_path
		)
		return

	var texture: Texture2D = load(texture_path) as Texture2D

	if texture == null:
		push_warning(
			"UnitCardExample: Resource is not a Texture2D: %s"
			% texture_path
		)
		return

	unit_card_example_card_texture.texture = texture

func _get_icon_by_index(type_index: int,is_target: bool) -> TextureRect:
	match type_index:
		1:
			return a_sword if is_target else d_sword
		2:
			return a_shield if is_target else d_shield
		3:
			return a_axe if is_target else d_axe
		4:
			return a_shurikane if is_target else d_shurikane
		5:
			return a_wand if is_target else d_wand
		6:
			return a_magical_wand if is_target else d_magical_wand
		7:
			return a_mace if is_target else d_mace
		8:
			return a_teeth if is_target else d_teeth
		_:
			return null

func set_selected(value: bool) -> void:
	is_selected = value
	selection_panel.visible = is_selected
	
func update_deck_indicator() -> void:
	is_in_deck_texture_rect.visible = (
		show_deck_indicator
		and card_id != 0
		and CardManager.is_card_in_deck(card_id)
	)
