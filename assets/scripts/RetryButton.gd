extends TextureButton
@export var gameover_screen: Node2D
@export var text_label: RichTextLabel
@export var text: String


func _ready():
	text_label.bbcode_enabled = true
	text_label.text = "[center]%s[/center]" % [text]


func _on_pressed():
	Input.action_press("retry")
	get_tree().paused = false
