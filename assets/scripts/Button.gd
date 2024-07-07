extends TextureButton

@export var scene_to_change_to:String = "res://assets/scenes/Main.tscn";
@export var text_label:RichTextLabel;
@export var text:String;
func _ready():
	if text_label != null:
		text_label.bbcode_enabled = true;
		text_label.text = "[center]%s[/center]"%[text];
	
func _on_button_down():
	if scene_to_change_to != null:
		get_tree().change_scene_to_file(scene_to_change_to)
		
