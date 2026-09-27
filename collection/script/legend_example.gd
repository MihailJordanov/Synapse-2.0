class_name LegendExample extends Control


@export var show_deck_indicator: bool = true

@export var legend_id: int = 0:
	set(value):
		legend_id = value

		if is_node_ready():
			setup_legend()


@onready var selection_panel: Panel = %SelectionPanel
@onready var texture_rect: TextureRect = %TextureRect
@onready var is_in_deck_texture_rect: TextureRect = %IsInDeckTextureRect


var legend: Legend
var is_selected: bool = false

var legend_name: String = ""
var description: String = ""
var activation_animation_name: StringName = &""
var effect: LegendEffect


func _ready() -> void:
	setup_legend()
	set_selected(false)


func setup_legend() -> void:
	_clear_legend()

	var loaded_legend: Legend = LegendManager.get_legend(
		legend_id
	)

	if loaded_legend == null:
		update_deck_indicator()
		return

	legend = loaded_legend
	legend_name = legend.legend_name
	description = legend.description
	activation_animation_name = (
		legend.activation_animation_name
	)
	effect = legend.effect
	texture_rect.texture = legend.texture

	update_deck_indicator()


func _clear_legend() -> void:
	legend = null
	legend_name = ""
	description = ""
	activation_animation_name = &""
	effect = null
	texture_rect.texture = null
	is_in_deck_texture_rect.visible = false
	


func set_selected(value: bool) -> void:
	is_selected = value
	selection_panel.visible = is_selected


func update_deck_indicator() -> void:
	is_in_deck_texture_rect.visible = (
		show_deck_indicator
		and legend_id != 0
		and LegendManager.get_equipped_legend_id()
			== legend_id
	)


func get_legend() -> Legend:
	return legend


func get_legend_name() -> String:
	return legend_name


func get_description() -> String:
	return description


func get_effect() -> LegendEffect:
	return effect
