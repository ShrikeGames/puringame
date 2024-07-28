extends VSplitContainer
class_name SettingsCheckbox

@export var button:CheckButton
@export var config_name:String = ""
@export var label_text_en:String = ""
@export var label_text_jp:String = ""
@export var language_toggle:LanguageToggle
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
	
func _on_check_button_toggled(button_pressed):
	if config_name == "drop_troggle":
		Global.drop_troggle = button_pressed
	elif config_name == "numbered_purin":
		Global.numbered_purin = button_pressed
	Global.save_settings()
