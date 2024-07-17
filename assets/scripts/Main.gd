extends Node2D

@export var language_toggle: LanguageToggle
@export var menu_container: Node2D

var menu
func _on_ready():
	Global.load_settings()
	update_menu()
	if language_toggle:
		language_toggle.connect("language_toggle", language_toggled)

func update_menu():
	if Global.language == "jp":
		if language_toggle:
			language_toggle.button_pressed = false
		var menu_en: Resource = load("res://assets/scenes/P5Menu/jp/P5Menu.tscn")
		menu = menu_en.instantiate()
	else:
		if language_toggle:
			language_toggle.button_pressed = true
		var menu_jp: Resource = load("res://assets/scenes/P5Menu/en/P5Menu.tscn")
		menu = menu_jp.instantiate()
		
	menu_container.add_child(menu)

func language_toggled(_language):
	Global.save_settings()
	for child in menu_container.get_children():
		child.queue_free()
	update_menu()
