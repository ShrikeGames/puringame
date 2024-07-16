extends Node2D
class_name ScoreOrb
signal scored
@export var target_position:Vector2
var position_difference:Vector2
var weight:float = 0.2
var min_distance:Vector2 = Vector2(5, 5)
var score_worth:float = 0
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if target_position:
		position.x = lerpf(position.x, target_position.x, weight)
		position.y = lerpf(position.y, target_position.y, weight)
		var scale_size = lerpf(0.5, min(score_worth/100.0, 5), weight)
		scale = Vector2(scale_size, scale_size)
		if abs(target_position - position) <= min_distance:
			scored.emit(score_worth)
			self.queue_free()
