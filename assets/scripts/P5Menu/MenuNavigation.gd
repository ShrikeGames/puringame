extends Node2D

@export var menu_items_node:Node2D
@export var external_buttons:Array[Node] = []
@export var logo:RigidBody2D
var previous_texture_normal:Texture2D
var previous_button:P5TextureButton
var menu_buttons:Array[P5TextureButton]
var previous_button_index:int
# Called when the node enters the scene tree for the first time.
func _ready():
	init()
	
func init():
	menu_buttons = []
	previous_button_index = 0
	var index:int = 0
	if menu_items_node != null:
		# connect to each button to listen for when the mouse changes its state
		for menu_item in menu_items_node.get_children():
			if menu_item.visible and is_instance_valid(menu_item):
				var button:P5TextureButton = menu_item.get_node("Button")
				if is_instance_of(button, P5TextureButton):
					button.menu_index = index
					# listen to it for changes from the mouse
					if not button.is_connected("rolled_over", change_active_button):
						button.connect("rolled_over", change_active_button)
					menu_buttons.append(button)
					index += 1
					
	for external_button in external_buttons:
		if is_instance_of(external_button, P5TextureButton):
			add_external_menu_button(external_button)
		elif is_instance_of(external_button, LocalizedObject):
			for child in external_button.get_children():
				if is_instance_of(child, RigidBody2D):
					var button:P5TextureButton = child.get_node("Button")
					add_external_menu_button(button, true)
		
		
	# the first button we'll remember and make it active by default
	if previous_button == null and not menu_buttons.is_empty():
		previous_button = menu_buttons[0]
		previous_texture_normal = previous_button.texture_normal
		
func add_external_menu_button(external_button:P5TextureButton, allow_texture_updates:bool = false):
	menu_buttons.append(external_button)
	external_button.menu_index = len(menu_buttons) -1
	external_button.allow_texture_updates = allow_texture_updates
	if external_button.active_image:
		external_button.active_image.visible = false
	external_button.connect("rolled_over", change_active_button)
		
func change_active_button(new_button:P5TextureButton):
	# button changed, only care if it's a visible button
	if is_instance_valid(new_button) and new_button.visible:
		# is also triggering on roll over which isn't right
		
		# reset old button back to its normal state
		if previous_button != null:
			previous_button.active = false
			previous_button.z_index = 0
			if previous_button.allow_texture_updates:
				previous_button.texture_normal = previous_texture_normal
			if previous_button.active_image:
				previous_button.active_image.visible = false
		if new_button.allow_texture_updates:
			# remember the new button as the previous so we can restore it later
			previous_texture_normal = new_button.texture_normal
		previous_button = new_button
		previous_button_index = new_button.menu_index
		if new_button.allow_texture_updates:
			# replace its normal texture with its hover and flag as active
			new_button.texture_normal = new_button.texture_hover
		if new_button.active_image:
			new_button.active_image.visible = true
		new_button.active = true
		new_button.z_index = 99
		# make sure it plays its sound
		if new_button.audio_player:
			new_button.audio_player.play()
		
func get_visible_menu_items():
	var visible_items:Array = []
	for menu_item in menu_buttons:
		if menu_item.visible and menu_item.get_parent().visible:
			visible_items.append(menu_item)
	return visible_items

func get_real_index(visible_menu_items, button):
	var real_index:int = 0
	for item in visible_menu_items:
		if item == button:
			return real_index
		real_index += 1
	return real_index
	
func get_first_visible_button():
	var visible_menu_items:Array = get_visible_menu_items()
	if visible_menu_items.is_empty():
		return null
	return visible_menu_items[0]
	
func get_next_visible_button(target_button:P5TextureButton=previous_button):
	var visible_menu_items:Array = get_visible_menu_items()
	var real_index:int = get_real_index(visible_menu_items, target_button)
	var next_index:int = real_index + 1
	if next_index > len(visible_menu_items) - 1:
		next_index = 0
	return visible_menu_items[next_index]
	
func get_previous_visible_button(target_button:P5TextureButton=previous_button):
	var visible_menu_items:Array = get_visible_menu_items()
	var real_index:int = get_real_index(visible_menu_items, target_button)
	var prev_index:int = real_index - 1
	if prev_index < 0:
		prev_index = len(visible_menu_items)-1
	return visible_menu_items[prev_index]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("accept"):
		# action key pressed
		if previous_button:
			previous_button.do_action()
		return
	if Input.is_action_just_pressed("move_down"):
		# go to the next button
		if previous_button.active:
			change_active_button(get_next_visible_button())
		else:
			change_active_button(get_first_visible_button())
		
	elif Input.is_action_just_pressed("move_up"):
		# go to the next button
		if previous_button.active:
			change_active_button(get_previous_visible_button())
		else:
			change_active_button(get_first_visible_button())
	elif Input.is_action_just_pressed("move_right"):
		# if going right then skip to the end or back
		if previous_button.active:
			change_active_button(get_previous_visible_button(menu_buttons[0]))
		else:
			change_active_button(get_first_visible_button())
	elif Input.is_action_just_pressed("move_left"):
		# if going right then skip to the end or back
		if previous_button.active:
			change_active_button(get_next_visible_button(menu_buttons[len(menu_buttons)-1]))
		else:
			change_active_button(get_first_visible_button())
	else:
		# numbers 1-9 on keyboard to quickly switch to a menu item
		for i in range(1, 10):
			if Input.is_action_just_pressed("menu_%s"%[i]) and len(menu_buttons) >= i:
				if menu_buttons[i-1] == previous_button:
					menu_buttons[i-1].do_action()
					return
				change_active_button(menu_buttons[i-1])
				break
	
