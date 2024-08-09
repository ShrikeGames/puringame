extends AnimatedSprite2D
class_name PurinIndicator

var level:int
var evil:bool = false
@export var number_label: RichTextLabel

# Called when the node enters the scene tree for the first time.
func _ready():
	set_frame(level)
	pause()
	if evil:
		set_animation("evil")
	else:
		set_animation("default")
	if Global.numbered_purin and number_label:
		number_label.text = "[center][color=fff]%s[/color][/center]"%[level]
		number_label.visible = true
