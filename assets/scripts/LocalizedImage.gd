extends Node2D
class_name LocalizedImage

@export var en:String
@export var jp:String
@export var image:Sprite2D
@export var language_toggle:LanguageToggle

var texture:Texture2D
# Called when the node enters the scene tree for the first time.
func _on_ready():
	if language_toggle:
		language_toggle.subscribe_image(self)
	update(Global.language)
		
func update(toggled_language):
	if toggled_language == "jp" and jp:
		texture = load(jp)
	else:
		texture = load(en)
	image.texture = texture

