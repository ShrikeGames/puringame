extends Node
class_name LocalizedObject

@export var en:String
@export var jp:String

@export var language_toggle:LanguageToggle
var object_en
var object_jp
# Called when the node enters the scene tree for the first time.
func _ready():
	if language_toggle:
		language_toggle.subscribe_object(self)
	for child in self.get_children():
		child.queue_free()
	var resource_en:Resource = load(en)
	var resource_jp:Resource = load(jp)
	object_en = resource_en.instantiate()
	object_en.visible = false
	add_child(object_en)
	object_jp = resource_jp.instantiate()
	object_jp.visible = false
	add_child(object_jp)
	update(Global.language)

func update(toggled_language):
	if  toggled_language == "jp":
		object_en.visible = false
		object_jp.visible = true
	else:
		object_en.visible = true
		object_jp.visible = false
	
	
