extends TextureButton

@export var audio_player: AudioStreamPlayer
var normal_bitmap
var hover_bitmap
var pressed_bitmap
# Called when the node enters the scene tree for the first time.
func _on_ready():
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
	if audio_player:
		audio_player.play()

func _on_mouse_exited():
	texture_click_mask = normal_bitmap

func _on_button_down():
	texture_click_mask = pressed_bitmap

func _on_button_up():
	texture_click_mask = normal_bitmap
	get_tree().quit()
