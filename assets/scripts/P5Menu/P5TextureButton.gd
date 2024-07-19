extends TextureButton
class_name P5TextureButton
signal rolled_over
@export var scene_to_change_to: String = "res://assets/scenes/Game.tscn"
@export var audio_player: AudioStreamPlayer
var normal_bitmap
var hover_bitmap
var pressed_bitmap
@export var active:bool = false
@export var menu_index:int
@export var allow_texture_updates:bool = true
@export var active_image:Sprite2D

var normal_texture:Texture2D
# Called when the node enters the scene tree for the first time.
func _on_ready():
	normal_texture = texture_normal
	if texture_normal:
		# Get the image from the texture normal
		var image = texture_normal.get_image()
		# Create the BitMap
		normal_bitmap = BitMap.new()
		# Fill it from the image alpha
		normal_bitmap.create_from_image_alpha(image)
		# Assign it to the mask
		texture_click_mask = normal_bitmap
	if texture_hover:
		var image = texture_hover.get_image()
		hover_bitmap = BitMap.new()
		hover_bitmap.create_from_image_alpha(image)
	if texture_pressed:
		var image = texture_pressed.get_image()
		pressed_bitmap = BitMap.new()
		pressed_bitmap.create_from_image_alpha(image)
	
func _on_mouse_entered():
	texture_click_mask = hover_bitmap
	if not active:
		z_index = 99
	emit_signal("rolled_over", self)
	if audio_player:
		audio_player.play()

func _on_mouse_exited():
	texture_click_mask = normal_bitmap
	active = false
	texture_normal = normal_texture
	z_index = 0
	
func _on_button_down():
	texture_click_mask = pressed_bitmap
	return

func _on_button_up():
	texture_click_mask = normal_bitmap
	Engine.time_scale = 1
	do_action()

func do_action():
	if scene_to_change_to != null and not scene_to_change_to.is_empty():
		get_tree().paused = false
		get_tree().change_scene_to_file(scene_to_change_to)
