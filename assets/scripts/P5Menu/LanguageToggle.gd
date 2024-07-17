extends TextureButton
class_name LanguageToggle
signal language_toggle

# Called when the node enters the scene tree for the first time.
func _ready():
	update_state()

func update_state():
	if Global.language == "jp":
		button_pressed = false
	else:
		button_pressed = true

func _on_toggled(is_button_pressed):
	if is_button_pressed:
		Global.language = "en"
	else:
		Global.language = "jp"
	emit_signal("language_toggle", Global.language)
