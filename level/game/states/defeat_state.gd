class_name DefeatState extends State

const DEFEAT_SFX = preload("uid://ba7yp1k5xa8we")

@onready var lose_panel: Panel = %LosePanel
@onready var defeat_info_label: RichTextLabel = %DefeatInfoLabel
@onready var exit_on_defeat_button: Button = %ExitOnDefeatButton
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var music_auto_trigger: MusicAutoTrigger = %MusicAutoTrigger


func enter() -> void:
	fsm.game_finished.emit(false)

	VisualEffects.camera_shake(10)

	if fsm.card_dragger != null:
		fsm.card_dragger.set_play_context(false, [])

	fsm.level_controller.hide_pause_button()

	if fsm.enemy_score >= fsm.enemy_winning_score:
		defeat_info_label.text = "The enemy reached the required score before you."
	else:
		defeat_info_label.text = "You have no more cards you can play."

	lose_panel.show()
	music_auto_trigger.pause_music()
	Audio.play_spatial_sound( DEFEAT_SFX, Vector2( 800, 450) )
	animation_player.play("on_defeat_show")

	print("Defeat!")
