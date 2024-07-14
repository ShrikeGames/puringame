extends AnimatedSprite2D
class_name PurinIndicator

var level:int
var evil:bool = false
@export var evil_visual:Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	set_frame(level)
	pause()
	if evil and evil_visual!=null:
		evil_visual.visible = true
	else:
		evil_visual.visible = false

