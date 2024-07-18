extends Node2D

@export var en:String
@export var jp:String
var resource:Resource

# Called when the node enters the scene tree for the first time.
func _ready():
	if Global.language == "jp" and jp:
		resource = load(jp)
	else:
		resource = load(en)
		
	add_child(resource.instantiate())
