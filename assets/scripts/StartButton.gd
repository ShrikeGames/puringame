extends TextureButton

@export var scene_to_change_to:PackedScene;
@export var text_label:RichTextLabel;
@export var text:String;

func _ready():
	text_label.bbcode_enabled = true;
	text_label.text = "[center]%s[/center]"%[text];
	
func _process(delta):
	if Input.is_action_pressed("accept"):
		self._on_button_down();
		
func _on_button_down():
	get_tree().change_scene_to_packed(scene_to_change_to);
