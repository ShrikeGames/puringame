extends Node2D

@export var settings_label: RichTextLabel
@export var settings_title: String
@export var audio_player: AudioStreamPlayer
@export var bar:Sprite2D
# Called when the node enters the scene tree for the first time.
func _on_ready():
	settings_label.text = "[right][color=FFFFFF]%s[/color][/right]"%[settings_title]



func _on_button_down():
	var mouse_pos = get_viewport().get_mouse_position()
	if audio_player:
		audio_player.play()
	bar.scale.x = mouse_pos.x / 1000.0
