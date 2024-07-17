extends TextureButton

@export var audio_player: AudioStreamPlayer

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	pass

func _on_button_down():
	if audio_player:
		audio_player.play()

func _on_button_up():
	pass


func _on_ready():
	pass # Replace with function body.
