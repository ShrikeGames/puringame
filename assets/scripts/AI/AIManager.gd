extends Node2D

@export var num_ai: int = 16
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 2.0
@export var camera:Camera2D

@export var generation:int = 1
@export var max_idle_time:float = 30

var total_score:int = 0
var best_score:int = 0
var game_count:int = 0
var training_data:Array

func _on_ready() -> void:
	init_ai_players()
	

func init_ai_players():
	Engine.time_scale = time_scale
	print("Begin Generation %s"%[generation])
	camera.ai_games_node = ai_games_node
	game_count = 0
	total_score = 0
	
	var x_pos:int = 17
	var y_pos:int = 0
	for i in range(0, num_ai):
		var game:PlayerController = play_package.instantiate()
		game.ai_controlled = true
		game.mute_sound = true
		game.debug = true
		var player_name = "ai%s"%(i)
		game.player_name = player_name
		game.position = Vector2(x_pos, y_pos)
		game.random_initial_board_state = true
		
		x_pos += 1056
		if i >0 and (i+1) % 2 == 0:
			x_pos = 17
			y_pos += 1080
		ai_games_node.add_child(game)
		
func _process(_delta: float) -> void:
	for game in ai_games_node.get_children():
		if game.time_since_last_score >= max_idle_time + (ai_games_node.get_child_count()*0.5) or game.gameover_screen.visible:
			if game.score > 0:
				total_score += game.score
				game_count += 1
				if game.score > best_score:
					best_score = game.score
					print("New best score of %s from %s"%[best_score, game.player_name])
					Global.best_brain.save_model(Global.ai_brain_path)
				else:
					print("Score of %s from %s"%[game.score, game.player_name])
				print("[Metric] Average Score: %s from %s games"%[total_score/float(game_count), game_count])
				
			game.restart_game()
			

