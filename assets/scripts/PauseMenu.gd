extends Node2D


func _process(_delta):
	if Input.is_action_just_pressed("pause"):
		self.visible = not self.visible
		get_tree().paused = self.visible
