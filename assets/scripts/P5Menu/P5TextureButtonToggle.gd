extends TextureButton

@export var audio_player: AudioStreamPlayer
@export var settings_label: RichTextLabel
@export var settings_title: String

# Called when the node enters the scene tree for the first time.
func _on_ready():
	settings_label.text = "[right]%s[/right]"%[settings_title]


func _on_mouse_entered():
	pass

func _on_mouse_exited():
	pass

func _on_button_down():
	if audio_player:
		audio_player.play()
	pass

func _on_button_up():
	pass
