extends Node2D

@export var language_toggle: LanguageToggle
@export var menu_container: Node2D
@export var hide_logo:bool = false
@export var collapse_menu:bool = false
@export var show_menu_button: TextureButton
var menu
func _on_ready():
	Global.load_settings()
	update_menu()
	if language_toggle and not language_toggle.is_connected("language_toggle", language_toggled):
		language_toggle.connect("language_toggle", language_toggled)
	if Global.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
func update_menu():
	for child in menu_container.get_children():
		child.queue_free()
		menu = null
	
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
	if menu:
		menu_container.add_child(menu)
		if language_toggle:
			menu.add_external_menu_button(language_toggle)
		if hide_logo:
			menu.logo.queue_free()
		if collapse_menu and show_menu_button:
			menu.visible = false
			show_menu_button.visible = true
			

func language_toggled(_language):
	Global.save_settings()
	update_menu()
