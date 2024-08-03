extends TextureButton

@export var object_to_toggle:Node2D

func _on_toggled(toggle_value):
	if object_to_toggle:
		object_to_toggle.visible = toggle_value
		get_tree().paused = toggle_value

func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		self.button_pressed = not self.button_pressed
