extends TabContainer
class_name SettingsTabs

@export var tab_labels_en:Array[String] = [""]
@export var tab_labels_jp:Array[String] = [""]
@export var language_toggle:LanguageToggle

# Called when the node enters the scene tree for the first time.
func _ready():
	update(Global.language)
	if is_instance_valid(language_toggle):
		language_toggle.subscribe_settings_tabs(self)
		
func update(language):
	if language == "jp":
		for i in range(0, self.get_child_count()):
			self.get_child(i).name = tab_labels_jp[i]
	else:
		for i in range(0, self.get_child_count()):
			self.get_child(i).name = tab_labels_en[i]
