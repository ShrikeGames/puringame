extends Node2D

@export var en:String
@export var jp:String
@export var image:Sprite2D
var texture:Texture2D
# Called when the node enters the scene tree for the first time.
func _ready():
	if Global.language == "jp" and jp:
		texture = load(jp)
	else:
		texture = load(en)
	image.texture = texture
