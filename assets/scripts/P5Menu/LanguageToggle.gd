extends P5TextureButton
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
	if is_button_pressed and Global.language != "en":
		Global.language = "en"
		Global.save_settings()
	elif not is_button_pressed and Global.language != "jp":
		Global.language = "jp"
		Global.save_settings()
	active = false
	emit_signal("language_toggle", Global.language)
	

func subscribe_image(image:LocalizedImage):
	if not self.is_connected("language_toggle", image.update):
		self.connect("language_toggle", image.update)

func subscribe_object(object:LocalizedObject):
	if not self.is_connected("language_toggle", object.update):
		self.connect("language_toggle", object.update)

func do_action():
	button_pressed = not button_pressed
	_on_toggled(button_pressed)
	
