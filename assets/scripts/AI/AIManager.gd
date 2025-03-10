extends Node2D

@export var num_ai: int = 24
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var camera:Camera2D

@export var generation:int = 1
@export var max_idle_time:float = 30
@export var ai_default_brain_path: String = "res://ai_brain_model.json"
@export var ai_brain_path: String = "user://ai_brain_model.json"

var total_score:int = 0
var best_score:int = 0
var game_count:int = 0
var training_data:Array
var best_brain:BrainAdvanced
func _on_ready() -> void:
	init_ai_players()
	
func init_ai_players():
	Engine.time_scale = time_scale
	print("Begin Generation %s"%[generation])
	camera.ai_games_node = ai_games_node
	game_count = 0
	total_score = 0
	
	if FileAccess.file_exists(ai_brain_path):
		best_brain = BrainAdvanced.new(BrainAdvanced.methods.SGD)
		best_brain.load_model(ai_brain_path)
		best_brain.mutate(0.05)
	elif FileAccess.file_exists(ai_default_brain_path):
		best_brain = BrainAdvanced.new(BrainAdvanced.methods.SGD)
		best_brain.load_model(ai_default_brain_path)
		best_brain.mutate(0.005)
	
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
		if best_brain:
			game.brain = best_brain
		
		x_pos += 1056
		if i >0 and (i+1) % 2 == 0:
			x_pos = 17
			y_pos += 1080
		ai_games_node.add_child(game)
		game_count += 1
		
func _process(delta: float) -> void:
	for game in ai_games_node.get_children():
		if game.time_since_last_score >= max_idle_time + (ai_games_node.get_child_count()*0.5) or game.gameover_screen.visible or is_bad_state(game):
			if game.score > 0:
				total_score += game.score
				if game.score > best_score:
					best_score = game.score
					print("New best score of %s from %s"%[best_score, game.player_name])
					game.brain.save_model(game.ai_brain_path)
					best_brain = game.brain.copy_model(true)
				else:
					print("Score of %s from %s"%[game.score, game.player_name])
					# degrade the best score to avoid local minimas
					best_score = best_score *0.99
					best_brain.mutate(0.005)
				print("Average Score: %s"%[total_score/float(game_count)])
				game_count += 1
			game.restart_game()
			

func is_bad_state(game:PlayerController) -> bool:
	# if they have a lot of the same purin size then it's not optimal enough
	if game.purin_node.get_child_count() <=0:
		return false
	
	var purin_size_counts:Array[int] = [0,0,0,0,0,0,0,0,0,0]
	for purin in game.purin_node.get_children():
		var purin_level:int = purin.get_meta("level", 0)
		purin_size_counts[purin_level] += 1
		if purin.position.y < 0 :
			return true
	
	for i in range(0, purin_size_counts.size()):
		if purin_size_counts[i] >= 6:
			return true
	return false
