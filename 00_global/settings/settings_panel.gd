class_name SettingsPanel
extends CanvasLayer

## Settings popup (volume for Music / SFX / UI). Reusable in any scene:
##   SettingsPanel.open(self)
## Values live in the Audio autoload and are saved to user://settings.json.

const SCENE_PATH: String = "res://00_global/settings/settings_panel.tscn"

@onready var dim: ColorRect = %Dim
@onready var window: Control = %Window
@onready var close_button: Button = %CloseButton

## bus name -> [HSlider, value Label]
@onready var _rows: Dictionary = {
	"Music": [%MusicSlider, %MusicValue],
	"SFX": [%SfxSlider, %SfxValue],
	"UI": [%UiSlider, %UiValue],
}

static var _open_panel: SettingsPanel = null


## Opens the panel (only one at a time). Works while the game is paused.
static func open(parent: Node) -> SettingsPanel:
	if is_instance_valid(_open_panel):
		return _open_panel

	var panel := (load(SCENE_PATH) as PackedScene).instantiate() as SettingsPanel
	parent.add_child(panel)
	_open_panel = panel
	return panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for bus_name: String in _rows:
		var slider: HSlider = _rows[bus_name][0]
		slider.min_value = 0
		slider.max_value = Audio.VOLUME_STEPS
		slider.step = 1
		slider.tick_count = Audio.VOLUME_STEPS + 1
		slider.ticks_on_borders = true
		slider.set_value_no_signal(Audio.get_volume_step(bus_name))
		_update_value_label(bus_name)
		slider.value_changed.connect(_on_slider_changed.bind(bus_name))
		slider.drag_ended.connect(_on_slider_drag_ended)

	close_button.pressed.connect(close)

	# Pop in.
	dim.modulate.a = 0.0
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.85, 0.85)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(window, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Audio.save_volume_settings()
	Audio.ui_select()

	if _open_panel == self:
		_open_panel = null

	close_button.disabled = true
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 0.0, 0.15)
	tween.tween_property(window, "scale", Vector2(0.85, 0.85), 0.15)
	tween.chain().tween_callback(queue_free)


func _on_slider_changed(value: float, bus_name: String) -> void:
	Audio.set_volume_step(bus_name, int(value), false)
	_update_value_label(bus_name)

	# Preview: a short click on the bus that changed (music is heard anyway).
	match bus_name:
		"UI":
			Audio.ui_focus_change()
		"SFX":
			if Audio.ui_select_audio != null:
				Audio.play_spatial_sound(Audio.ui_select_audio, get_viewport().get_visible_rect().size * 0.5)


func _on_slider_drag_ended(_value_changed: bool) -> void:
	Audio.save_volume_settings()


func _update_value_label(bus_name: String) -> void:
	var label: Label = _rows[bus_name][1]
	var step: int = Audio.get_volume_step(bus_name)
	label.text = "Off" if step == 0 else str(step)
