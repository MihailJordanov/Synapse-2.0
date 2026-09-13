class_name VictoryState extends State

const VICTORY_SFX = preload("uid://cwy2yyi6qott0")

@onready var victory_panel: Panel = %VictoryPanel
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var victory_info_label: RichTextLabel = %VictoryInfoLabel
@onready var music_auto_trigger: MusicAutoTrigger = %MusicAutoTrigger


func enter() -> void:
	fsm.game_finished.emit(true)

	VisualEffects.camera_shake(10)

	if fsm.card_dragger != null:
		fsm.card_dragger.set_play_context(false, [])

	fsm.level_controller.hide_pause_button()
	
	victory_info_label.text = "You reached the required score first!"

	victory_panel.show()
	music_auto_trigger.pause_music()
	Audio.play_spatial_sound( VICTORY_SFX, Vector2( 800, 450) )
	
	animation_player.play("on_victory_show")

	print("Victory!")
