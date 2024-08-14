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

var training_data:Array
func _on_ready() -> void:
	Global.nna = Global.load_ml(false)
	Global.nna.learning_rate = 1
	var training_filepath:String = "user://training.txt"
	if not FileAccess.file_exists(training_filepath):
		training_filepath = "res://training.txt"
		
	#training_data = Global.nna.load_data_from_file(training_filepath, -1)
	#Global.nna.train_bulk_cached(training_data)
	Global.save_ml_file(Global.nna)
	
	init_ai_players();#
	
func init_ai_players():
	Engine.time_scale = time_scale
	Node2D.print_orphan_nodes()
		
	if generation >= 1:
#		print("Train global best on training data before next generation starts")
#		if not FileAccess.file_exists("user://training.txt"):
#			Global.nna.train_bulk("res://training.txt", 1000)
#		else:
#			Global.nna.train_bulk("user://training.txt", 1000)
#
		if not Global.neural_training_models.is_empty():
			# sort the trained models
			Global.neural_training_models.sort_custom(best_nna_sort)
			print("[Stats] Global Best Total Loss: %s"%Global.nna.total_loss)
			print("[Stats] Global Best Total Score: %s"%Global.nna.total_score)
			print("[Stats] Global Best FItness: %s"%Global.nna.fitness)
			print("[Stats] Global Best Layer Configuration: %s"%Global.nna.get_string_info())
			print("Generation %s Results:"%[generation])
			print("[Stats] Best Total Loss: %s"%Global.neural_training_models[0].total_loss)
			print("[Stats] Best Total Score: %s"%Global.neural_training_models[0].total_score)
			print("[Stats] Best FItness: %s"%Global.neural_training_models[0].fitness)
			print("[Stats] Best Layer Configuration: %s"%Global.neural_training_models[0].get_string_info())
			var num_models:int = len(Global.neural_training_models)
			print("[Stats] Average Loss: %s"%[Global.neural_training_total_loss/num_models])
			print("[Stats] Average Score: %s"%[Global.neural_training_total_score/num_models])
			print("[Stats] Average Fitness: %s"%[Global.neural_training_total_fitness/num_models])
			
	generation += 1
	for game in ai_games_node.get_children():
		ai_games_node.queue_free()
		
	games = []
	
	var x_pos:float = 0
	var y_pos:float = 0
	generation_ended = false
	generation_timer = 0
	# take only the top half of the population
	Global.neural_training_models = Global.neural_training_models.slice(0, int(len(Global.neural_training_models)*0.5))
	
	for i in range(0, num_ai):
		var game:PlayerController = play_package.instantiate()
		game.mute_sound = true
		game.training = true
		game.neural_training = true
		game.ai_controlled = true
		game.auto_retry = auto_retry
		game.neural_training = neural_training
		game.max_retry_attempts = max_retry_attempts
		game.debug = true
		
		var player_name = "ai%s_%s"%[generation, i]
		game.player_name = player_name
		
		# save to your own generation file
		game.config_path = "user://ai_v2.json"
		game.default_config_path = "res://ai_v2.json"
		
		game.position = Vector2(40 + (x_pos*1020), y_pos)
		ai_games_node.add_child(game)
		game.debug = debug
		
		var generation_mutation_rate = min(0.75, 0.03 + (i*0.03))
		if len(Global.neural_training_models) > 1 and generation > 1:
			# higher generations start cross breeding
			if i < num_ai*0.2:
				if i == 0:
					game.source_network = Global.nna.copy(true)
					# the new best NNA all others will use to judge themselves
					if Global.neural_training_models[0].fitness > Global.nna.fitness:
						print("New best model")
						Global.nna = Global.neural_training_models[0].copy(false)
						Global.save_ml_file(Global.nna)
				else:
					var parent1:NeuralNetworkAdvanced = Global.nna.copy(false)
					parent1.mutation_rate = generation_mutation_rate
					var parent2:NeuralNetworkAdvanced = Global.neural_training_models[i-1]
					parent2.mutation_rate = generation_mutation_rate
					game.source_network = parent1.cross_breed(parent2)
			else:
				var parent1_index:int = randi_range(0, int(len(Global.neural_training_models)*0.1))
				var parent1:NeuralNetworkAdvanced = Global.neural_training_models[parent1_index]
				parent1.mutation_rate = generation_mutation_rate
				var parent2_index:int = randi_range(0, int(len(Global.neural_training_models)*0.2))
				var parent2:NeuralNetworkAdvanced = Global.neural_training_models[parent2_index]
				parent2.mutation_rate = generation_mutation_rate
				game.source_network = parent1.cross_breed(parent2)
			
		else:
			game.source_network = Global.nna.copy(true, 1)
		
		# reset stats
		game.source_network.total_loss = 0
		game.source_network.total_score = 0
		game.source_network.fitness = 0
		game.source_network.learning_rate = 0.0001+randf()
		game.generation = generation
		
		game.init()
		game.set_up_game()
		
		game.ai_controller.debug = true
		game.ai_controller.epsilon = max(0.1, 0.5 - (generation*0.01))
		
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
			
	camera.games = games
	
	# clear the stats for previous generation
	Global.neural_training_models = []
	Global.neural_training_total_loss = 0
	Global.neural_training_total_score = 0
	Global.neural_training_total_fitness = 0 
	print("Begin Generation %s"%[generation])

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
	
			
	
func best_nna_sort(nna1:NeuralNetworkAdvanced, nna2:NeuralNetworkAdvanced):
	if nna1.fitness > nna2.fitness:
		return true
	return false
