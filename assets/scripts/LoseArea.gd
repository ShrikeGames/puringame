extends Area2D
@export var gameover_screen:Node2D;

func _on_body_entered(body:Purin):
	if is_instance_of(body, Purin) and body.linear_velocity.y > 0:
		print("Game Over");
		get_tree().paused = true;
		gameover_screen.visible = true;
