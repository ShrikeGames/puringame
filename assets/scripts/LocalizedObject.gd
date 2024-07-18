extends Node2D
class_name LocalizedObject

@export var en:String
@export var jp:String
var resource:Resource
@export var language_toggle:LanguageToggle

# Called when the node enters the scene tree for the first time.
func _ready():
	if language_toggle:
		language_toggle.subscribe_object(self)
	update(Global.language)

func update(toggled_language):
	if  toggled_language == "jp" and jp:
		resource = load(jp)
	else:
		resource = load(en)
	for child in self.get_children():
		child.queue_free()
	add_child(resource.instantiate())
