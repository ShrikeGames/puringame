extends Node2D

@export var num_ai: int = 12
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false
@export var auto_retry: bool = false
@export var neural_training: bool = false
@export var max_retry_attempts: int = 999
@export var camera:Camera2D
@export var battle_mode:bool = false
var generation_ended:bool = false
var generation_timer:float = 0.0

var games:Array[PlayerController]
@export var generation:int = 0
var following_game:PlayerController
var nna:NeuralNetworkAdvanced

func _on_ready() -> void:
	nna = Global.load_ml(false)
	Global.save_ml_file(nna)
	init_ai_players();
	
func init_ai_players():
	Engine.time_scale = time_scale
	Node2D.print_orphan_nodes()
	if generation >= 1:
		var config_json = Global.read_json("user://ai_v2_%s.json"%[generation])
		
		if config_json:
			var history:Array = config_json.get("history", [])
			history.sort_custom(rank_history)
			var total_score:int = 0
			var total_count:int = 0
			var highest_score:int = 0
			var minimum:int = 9999999
			
			for config in history:
				if config.get("score") > highest_score:
					highest_score = config.get("score")
				if config.get("score") < minimum:
					minimum = config.get("score")
				total_score += config.get("score")
				total_count += 1
				
			var average:float = total_score / float(total_count)
			print("[Stats] Minimum Score for Generation %s was %s"%[generation, minimum])
			print("[Stats] Average Score for Generation %s was %s"%[generation, average])
			print("[Stats] Highest Score for Generation %s was %s"%[generation, highest_score])
			
		var history:Array = config_json.get("history", [])
		config_json["history"] = history.slice(0, round(num_ai*0.5))
		# save the results
		var json_string := JSON.stringify(config_json)
		# We will need to open/create a new file for this data string
		var file_access := FileAccess.open("user://ai_v2.json", FileAccess.WRITE)
		if not file_access:
			print("An error happened while saving data: ", FileAccess.get_open_error())
			return
			
		file_access.store_line(json_string)
		file_access.close()
		# take best NN and use that going forward
		if not Global.neural_training_models.is_empty():
			# sort the trained models
			Global.neural_training_models.sort_custom(best_nna_sort)
			# take only the best one
			nna = Global.neural_training_models[0]
			# cross breed it with the 2nd best
			if len(Global.neural_training_models) > 1:
				nna.cross_breed(Global.neural_training_models[1], 0.5)
			print("Generation %s Results:"%[generation])
			print("Best Total Loss: %s"%nna.total_loss)
			print("Best Total Score: %s"%nna.total_score)
			print("Average Loss: %s"%[Global.neural_training_total_loss/Global.neural_training_total_models])
			print("Average Score: %s"%[Global.neural_training_total_score/Global.neural_training_total_models])
			Global.save_ml_file(nna)
			# clear the list
			Global.neural_training_models = []
			Global.neural_training_total_loss = 0
			Global.neural_training_total_score = 0
			Global.neural_training_total_models = 0
		
	generation += 1
	for game in ai_games_node.get_children():
		ai_games_node.queue_free()
		
	games = []
	print("Begin Generation %s"%[generation])
	var x_pos:float = 0
	var y_pos:float = 0
	generation_ended = false
	generation_timer = 0
	
	for i in range(0, num_ai):
		var game:PlayerController = play_package.instantiate()
		game.ai_controlled = true
		game.mute_sound = true
		game.auto_retry = auto_retry
		game.neural_training = neural_training
		game.max_retry_attempts = max_retry_attempts
		
		game.training = true
		var player_name = "ai%s_%s"%[generation, i]
		game.player_name = player_name
		
		# save to your own generation file
		game.config_path = "user://ai_v2_%s.json"%[generation]
		if generation <= 1:
			game.default_config_path = "res://ai_v2.json"
		else:
			# use previous generation
			game.default_config_path = "user://ai_v2_%s.json"%[generation-1]
		
		game.position = Vector2(40 + (x_pos*1020), y_pos)
		ai_games_node.add_child(game)
		game.debug = debug
		# make own copy of the best NN (with mutations)
		# larger mutation rates for the later population members
		var generation_mutation_rate = 0.15 + i
		if generation == 1:
			# mutate everything randomly in gen 1
			# so we have a very diverse initial population
			generation_mutation_rate = 1
		game.source_network = Global.load_ml(true, generation_mutation_rate)
		# reset stats
		game.source_network.total_loss = 0
		game.source_network.total_score = 0
		# give it a reference to the current best one as well
		game.best_nna = nna
		game.init()
		game.set_up_game()
		game.ai_controller.debug = debug
		games.append(game)
		x_pos += 1
		if i > 0 and (i+1) % 2 == 0:
			y_pos += 1280
			x_pos = 0
	if battle_mode:
		# set them as opponents in pairs
		for i in range(0, len(games), 2):
			games[i+1].opponents = [games[i]]
			games[i].opponents = [games[i+1]]
			
	following_game = games[0]
	camera.position.x = 960
	camera.position.y = following_game.position.y + 535
	
	

func rank_history(run1:Dictionary, run2:Dictionary):
	if run1.get("score", 0) > run2.get("score", 0):
		return true
	return false
		
func rank_ai_players_hs(player1:PlayerController, player2:PlayerController):
	if player1.highscore > player2.highscore:
		return true
	return false
		
func rank_ai_players(player1:PlayerController, player2:PlayerController):
	if player1.last_score > player2.last_score:
		return true
	return false

func _process(delta):
	generation_timer += delta
	if ai_games_node.get_child_count() <= 0:
		init_ai_players();
	
	if camera != null and not games.is_empty():
		var updated:bool = false
		for game in games:
			if not is_instance_valid(following_game) or (is_instance_valid(game) and game.score > 20000 and game.score > following_game.score and game.player_name != following_game.player_name):
				following_game = game
				updated = true
		if updated:
			camera.position.x = 960
			camera.position.y = following_game.position.y + 535
			
	
func best_nna_sort(nna1:NeuralNetworkAdvanced, nna2:NeuralNetworkAdvanced):
	#nna1.total_loss < nna2.total_loss and 
	if nna1.total_score > nna2.total_score:
		return true
	return false
