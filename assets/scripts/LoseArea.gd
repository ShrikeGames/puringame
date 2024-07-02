extends Area2D
class_name LoseArea
var purin_in_danger:bool = false;
@export var gameover_count_down:AnimatedSprite2D;

func _on_body_entered(body:Purin):
	if is_instance_of(body, Purin) and body.linear_velocity.y > 0:
		body.set_meta("purin_in_danger", true);
		gameover_count_down.position = body.position;

func _on_body_exited(body):
	body.set_meta("purin_in_danger", false);
		
func start_countdown():
	if not gameover_count_down.is_playing():
		gameover_count_down.visible = true;
		gameover_count_down.play();
		
func stop_countdown():
	gameover_count_down.visible = false;
	gameover_count_down.stop();

