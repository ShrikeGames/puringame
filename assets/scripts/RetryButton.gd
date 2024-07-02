extends Button

@export var game:Game;
@export var gameover_screen:Node2D;

func _on_pressed():
	gameover_screen.visible = false;
	game.start_game();
	get_tree().paused = false;
