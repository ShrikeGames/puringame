extends VSplitContainer
class_name SettingsCheckbox

@export var button:CheckButton
@export var config_name:String = ""
@export var label_text_en:String = ""
@export var label_text_jp:String = ""
@export var language_toggle:LanguageToggle
@export var toggle_object:Node2D

var audio_bus_index:int = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	update(Global.language)
	if is_instance_valid(language_toggle):
		language_toggle.subscribe_settings_checkbox(self)
		
func update(language):
	if language == "jp":
		button.text = label_text_jp
	else:
		button.text = label_text_en
	if config_name == "drop_troggle":
		button.button_pressed = Global.drop_troggle
	elif config_name == "numbered_purin":
		button.button_pressed = Global.numbered_purin
	elif config_name == "enable_rain":
		button.button_pressed = Global.enable_rain
		if toggle_object and is_instance_valid(toggle_object):
			toggle_object.visible = button.button_pressed
	elif config_name == "fullscreen":
		button.button_pressed = Global.fullscreen
		
func _on_check_button_toggled(button_pressed):
	if config_name == "drop_troggle":
		Global.drop_troggle = button_pressed
	elif config_name == "numbered_purin":
		Global.numbered_purin = button_pressed
	elif config_name == "enable_rain":
		Global.enable_rain = button_pressed
		if toggle_object and is_instance_valid(toggle_object):
			toggle_object.visible = button_pressed
	elif config_name == "fullscreen":
		Global.fullscreen = button_pressed
		if button_pressed:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	Global.save_settings()
