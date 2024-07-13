extends Node2D

@export var num_ai: int = 12
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false
@export var camera:Camera2D
@export var generation_length_sec:float = 400
var generation_timer:float = 0.0

var games:Array[PlayerController]
var generation:int = 0
var following_game:PlayerController
func _on_ready() -> void:
	Engine.time_scale = time_scale
	init_ai_players();
	
func init_ai_players():
	generation += 1
	print("Begin Generation %s"%[generation])
	generation_timer = 0.0
	var x_pos:float = 0
	var y_pos:float = 0
	var original_population = []
	for i in range(0, num_ai):
		var game:PlayerController = play_package.instantiate()
		game.ai_controlled = true
		game.mute_sound = true
		game.auto_retry = true
		game.ai_mutation_rate = 0
		game.training = true
		var player_name = "ai%s"%(i)
		game.player_name = player_name
		# for now all save to the same file instead of individual
		# working to improve just one result
		# TODO change later
		game.config_path = "user://ai.json"
		game.default_config_path = "res://ai.json"
		game.position = Vector2(40 + (x_pos*1020), y_pos)
		game.init()
		x_pos += 1
		if i > 0 and (i+1) % 2 == 0:
			y_pos += 1080
			x_pos = 0
		original_population.append(game)
	original_population.sort_custom(rank_ai_players)
	games = []
	var rank:int = 0
	for game in original_population:
		rank += 1
		game.rank = rank
		if rank < num_ai * 0.25:
			game.ai_mutation_rate = 0.05
		elif rank < num_ai * 0.5:
			game.ai_mutation_rate = 0.1
		else:
			game.ai_mutation_rate = 0.2
		games.append(game)
		
	games.sort_custom(rank_ai_players)
	for game in ai_games_node.get_children():
		ai_games_node.queue_free()
	
	for game in games:
		ai_games_node.add_child(game)
		game.init()
		game.set_up_game()
		print("%s. %s (%s) %s %s"%[game.rank, game.player_name, game.highscore, game.ai_controller.weights, game.ai_controller.biases])
	
	following_game = games[0]
	camera.position.y = 535
	
func rank_ai_players(player1:PlayerController, player2:PlayerController):
	if player1.highscore > player2.highscore:
		return true
	if player1.highscore > player2.highscore:
		return true
	return false
	
func _process(delta):
	generation_timer += delta
	if generation_timer >= 100 and snappedi(generation_timer, 0) % 100 == 0:
		print("Generation %s Age: %s"%[generation, generation_timer])
	
	# reached the end of the generation so toggle off retries
	if generation_timer > generation_length_sec:
		for game in games:
			if is_instance_valid(game):
				game.auto_retry = false
	if ai_games_node.get_child_count() <= 0:
		init_ai_players();
	
	if camera != null and not games.is_empty() and not is_instance_valid(following_game):
		for game in games:
			if is_instance_valid(game):
				camera.position.y = game.position.y + 535
				following_game = game
				break
	
