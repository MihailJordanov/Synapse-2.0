# Audio global script
extends Node

enum REVERB_TYPE { NONE, SMALL, MEDIUM, LARGE }

signal player_made_sound( pos : Vector2, volume : float )

@export var ui_focus_audio : AudioStream
@export var ui_select_audio : AudioStream
@export var ui_cancel_audio : AudioStream
@export var ui_success_audio : AudioStream
@export var ui_error_audio : AudioStream

var current_track : int = 0
var music_tweens : Array[ Tween ] 
var ui_audio_player : AudioStreamPlaybackPolyphonic
var audio_pool : Array[ AudioStreamPlayer2D ]
var audio_index : int = 0

@onready var music_1: AudioStreamPlayer = %Music1
@onready var music_2: AudioStreamPlayer = %Music2
@onready var ui: AudioStreamPlayer = %UI

func _ready() -> void:
	ui.play()
	ui_audio_player = ui.get_stream_playback()
	for i in 32:
		var audio_player : AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		add_child( audio_player )
		audio_player.bus = "SFX"
		audio_pool.append( audio_player )
		pass
	pass

func play_music(audio: AudioStream,loop: bool = true,volume_db: float = 0.0) -> void:
	if audio == null:
		return

	_set_stream_loop(audio, loop)

	var current_player: AudioStreamPlayer = get_music_player(current_track)

	if current_player.stream == audio:
		current_player.volume_db = volume_db
		return

	var next_track: int = wrapi(current_track + 1, 0, 2)
	var next_player: AudioStreamPlayer = get_music_player(next_track)

	next_player.stream = audio
	next_player.volume_db = -80.0
	next_player.play()

	for t in music_tweens:
		t.kill()

	music_tweens.clear()

	fade_track_out(current_player)
	fade_track_in(next_player, volume_db)

	current_track = next_track

func get_music_player( i : int ) -> AudioStreamPlayer:
	if i == 0:
		return music_1
	else:
		return music_2
	
func fade_track_out( player : AudioStreamPlayer ) -> void:
	var tween: Tween = create_tween()
	music_tweens.append(tween)
	tween.tween_property(player,"volume_db",-80.0,1.5)
	tween.tween_callback(player.stop)
	
func fade_track_in( player : AudioStreamPlayer, target_volume_db: float = 0.0	 ) -> void:
	var tween: Tween = create_tween()
	music_tweens.append(tween)
	tween.tween_property(player,"volume_db",target_volume_db,1.0)
	
func set_reverb( type : REVERB_TYPE ) -> void:
	var reverb_fx : AudioEffectReverb = AudioServer.get_bus_effect( 1, 0 )
	if not reverb_fx:
		return
		
	AudioServer.set_bus_effect_enabled( 1, 0, true )
	match type:
		REVERB_TYPE.NONE:
			AudioServer.set_bus_effect_enabled( 1, 0, false )
		REVERB_TYPE.SMALL:
			reverb_fx.room_size = 0.2
		REVERB_TYPE.MEDIUM:
			reverb_fx.room_size = 0.5
		REVERB_TYPE.LARGE:
			reverb_fx.room_size = 0.8
	pass
	
func play_spatial_sound( audio : AudioStream,
		 pos : Vector2,
		 ignore_pool : bool = false,
		 was_player : bool = false,
		volume : float = 0.5
		) -> void:
	if ignore_pool:
		var ap : AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		add_child( ap )
		ap.bus = "SFX"
		ap.global_position = pos
		ap.stream = audio
		ap.finished.connect( ap.queue_free )
		ap.play()
	else:
		var ap : AudioStreamPlayer2D = audio_pool[ audio_index ]
		ap.global_position = pos
		ap.stream = audio
		ap.play()
		audio_index = wrapi( audio_index + 1, 0, 32 )
		pass
	
	if was_player:
		player_made_sound.emit( pos, volume )
	pass
	
#region /// ui functions
func play_ui_audio(audio: AudioStream, end_offset: float = 0.0) -> void:
	if not ui_audio_player or audio == null:
		return

	var stream_id: int = ui_audio_player.play_stream(audio)

	if end_offset <= 0.0:
		return

	var play_duration: float = max(0.0,audio.get_length() - end_offset)

	await get_tree().create_timer(play_duration).timeout

	if ui_audio_player.is_stream_playing(stream_id):
		ui_audio_player.stop_stream(stream_id)

func ui_focus_change() -> void:
	play_ui_audio( ui_focus_audio )
	pass
	
func ui_select() -> void:
	play_ui_audio( ui_select_audio )
	pass

func ui_cancel() -> void:
	play_ui_audio( ui_cancel_audio )
	pass
	
func ui_success() -> void:
	play_ui_audio( ui_success_audio )
	pass
	
func ui_error() -> void:
	play_ui_audio( ui_error_audio )
	pass
#endregion

func setup_button_audio( node : Node ) -> void:
	for c in node.find_children( "*", "Button" ):
		c.pressed.connect( ui_select )
		c.focus_entered.connect( ui_focus_change )
	pass

func _set_stream_loop(audio: AudioStream, loop: bool) -> void:
	if audio is AudioStreamOggVorbis:
		audio.loop = loop

	elif audio is AudioStreamMP3:
		audio.loop = loop

	elif audio is AudioStreamWAV:
		if loop:
			audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
			audio.loop_begin = 0
			audio.loop_end = audio.get_length() * audio.mix_rate
		else:
			audio.loop_mode = AudioStreamWAV.LOOP_DISABLED
