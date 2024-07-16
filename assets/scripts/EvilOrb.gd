extends Node2D
class_name EvilOrb
signal evilguh
@export var target_position:Vector2
var position_difference:Vector2
var weight:float = 0.05
var min_distance:Vector2 = Vector2(25, 25)
var purin_level:int = 0
var opponent:PlayerController

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if target_position and opponent:
		var xpos = lerpf(position.x, target_position.x, weight)
		var ypos = lerpf(position.y, target_position.y, weight)
		var scale_size = lerpf(0.5, purin_level+1, weight)
		position = Vector2(xpos, ypos)
		scale = Vector2(scale_size, scale_size)
		if abs(target_position - position) <= min_distance:
			evilguh.emit(purin_level, opponent)
			self.queue_free()
