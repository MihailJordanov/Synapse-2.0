class_name SettingsButton
extends TextureButton

## Drop this button in any scene: it opens the SettingsPanel.


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	Audio.ui_select()
	SettingsPanel.open(get_tree().current_scene)
