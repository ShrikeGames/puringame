extends VSplitContainer
class_name SettingsSlider

@export var label:Label
@export var slider:Slider
@export var config_name:String = ""
@export var label_text_en:String = ""
@export var label_text_jp:String = ""
@export var language_toggle:LanguageToggle
@export var override_min:float = 0.0
@export var override_max:float = 100.0
var audio_bus_index:int = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	update(Global.language)
	slider.min_value = override_min
	slider.max_value = override_max
	
	if is_instance_valid(language_toggle):
		language_toggle.subscribe_settings_slider(self)
		
func update(language):
	if language == "jp":
		label.text = label_text_jp
	else:
		label.text = label_text_en
	
	if config_name == "volume_master":
		slider.value = Global.volume_master * 100
		audio_bus_index = AudioServer.get_bus_index("Master")
	elif config_name == "volume_menu":
		slider.value = Global.volume_menu * 100
		audio_bus_index = AudioServer.get_bus_index("Menu")
	elif config_name == "volume_game_sfx":
		slider.value = Global.volume_game_sfx * 100
		audio_bus_index = AudioServer.get_bus_index("Game")
	elif config_name == "volume_voices":
		slider.value = Global.volume_voices * 100
		audio_bus_index = AudioServer.get_bus_index("Voice")
	elif config_name == "volume_music":
		slider.value = Global.volume_music * 100
		audio_bus_index = AudioServer.get_bus_index("Music")
	elif config_name == "game_speed":
		slider.value = Global.game_speed * 100
	
	Global.update_volume(audio_bus_index, slider.value)
	

func _on_slider_value_changed(value):
	var scaled_value:float = value*0.01
	if config_name == "volume_master":
		Global.volume_master = scaled_value
	elif config_name == "volume_menu":
		Global.volume_menu = scaled_value
	elif config_name == "volume_game_sfx":
		Global.volume_game_sfx = scaled_value
	elif config_name == "volume_voices":
		Global.volume_voices = scaled_value
	elif config_name == "volume_music":
		Global.volume_music = scaled_value
	elif config_name == "game_speed":
		Global.game_speed = scaled_value
	Global.update_volume(audio_bus_index, value)
	Global.save_settings()


