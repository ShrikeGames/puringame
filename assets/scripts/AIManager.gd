extends Node2D

@export var num_ai: int = 2
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
var ai_games_node: Node2D
var generation: int
@export var camera: Camera2D
@export var best_ratio: float = 0.1
@export var time_scale: float = 1.0
@export var debug: bool = false
var average_score: float = 0.0
var best_average_score: float = 0.0
var currently_watching_game: Game = null
var global_best_score_history = []
var global_average_best_score_history = []
var gen_best_score_history = []
var config_path: String = "user://%s.cfg" % ["best_v3"]


# Called when the node enters the scene tree for the first time.
func _ready():
	ai_games_node = get_node("AIGames")
	generation = 0
	Engine.time_scale = time_scale


func rank_players(player1, player2):
	var p1_score = player1["ai_adjusted_highscore"]
	#+ (player1["previous_ai_adjusted_highscore"] * 0.25)
	var p2_score = player2["ai_adjusted_highscore"]
	#+ (player2["previous_ai_adjusted_highscore"] * 0.25)
	if float(p1_score) > float(p2_score):
		return true
	return false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# prematurely kill any stragglers if they're under performing andholding us up
#	if ai_games_node and ai_games_node.get_child_count() <= num_ai * best_ratio:
#		for game in ai_games_node.get_children():
#			if is_instance_of(game, Game) and game.score < average_score * 0.75:
#				game.save_scores();
#				game.queue_free();

	# check if all games are done
	if ai_games_node and ai_games_node.get_child_count() <= 0:
		print("===Generation %s has concluded.===" % [generation])
		var best_config = "best"
		var config = ConfigFile.new()
		print(config_path)
		config.load(config_path)
		var best_score: float = config.get_value(best_config, "highscore", 0)
		print("The all time best score is: %s" % (best_score))
		global_best_score_history.append(best_score)

		var total_score: float = 0
		var contenders_total_score: float = 0
		var this_generation_total_score: float = 0
		var this_generation_contenders_total_score: float = 0
		var this_generation_contenders_total_actual_score: float = 0

		var ranked_players: Array = []
		var MAX_POSSIBLE_PLAYERS = 300
		for i in range(0, MAX_POSSIBLE_PLAYERS):
			var player = "AI%d" % [i]
			var player_stats = {
				"highscore": config.get_value(player, "highscore", i),
				"ai_adjusted_highscore": config.get_value(player, "ai_adjusted_highscore", i),
				"previous_highscore": config.get_value(player, "previous_highscore", i),
				"previous_ai_adjusted_highscore":
				config.get_value(player, "previous_ai_adjusted_highscore", i),
				"x": config.get_value(player, "x", 1),
				"y": config.get_value(player, "y", 1),
				"l": config.get_value(player, "l", 1),
				"s": config.get_value(player, "s", 1),
				"c": config.get_value(player, "c", 1),
				"d1": config.get_value(player, "d1", 1),
				"d2": config.get_value(player, "d2", 1),
				"drop_bias": config.get_value(player, "drop_bias", 1),
				"np": config.get_value(player, "np", 1),
				"player_name": player,
				"highest_level_reached": config.get_value(player, "highest_level_reached", 0)
			}
			ranked_players.append(player_stats)
		ranked_players.sort_custom(rank_players)

		var num_players = min(len(ranked_players), num_ai)
		var num_best_players = num_players * best_ratio
		var x_pos: int = 60
		var y_pos: int = 0
		# TOP CONTENDERS
		for i in range(0, num_best_players):
			var game: Game = play_package.instantiate()
			var player_configs = ranked_players[i]
			print(
				(
					"%s. CONTENDER %s: %s (%s)"
					% [
						i,
						player_configs["player_name"],
						player_configs["previous_highscore"],
						player_configs["previous_ai_adjusted_highscore"]
					]
				)
			)
			game.ai_controlled = true
			game.training = true
			# show debug info for the contenders
			game.debug = true
			game.player_name = player_configs["player_name"]
			game.AI_X_WEIGHT = player_configs["x"]
			game.AI_Y_WEIGHT = player_configs["y"]
			game.AI_LEVEL_WEIGHT = player_configs["l"]
			game.AI_STACKED_WEIGHT = player_configs["s"]
			game.AI_EASY_COMBINE_WEIGHT = player_configs["c"]
			game.AI_DROP_DELAY_SECONDS = player_configs["d1"]
			game.AI_DROP_DELAY_PANIC_SECONDS = player_configs["d2"]
			game.drop_bias = player_configs["drop_bias"]
			game.next_purin_weight = player_configs["np"]
			game.highscore = player_configs["highscore"]
			game.ai_adjusted_highscore = player_configs["ai_adjusted_highscore"]
			game.mute_sound = true
			game.position = Vector2(x_pos, y_pos)
			game.mutation_rate = 2
			game.ai_use_best_rate = 0
			game.ai_use_personal_rate = 100
			total_score += player_configs["ai_adjusted_highscore"]
			contenders_total_score += player_configs["ai_adjusted_highscore"]
			this_generation_total_score += player_configs["previous_ai_adjusted_highscore"]
			this_generation_contenders_total_actual_score += player_configs["previous_highscore"]
			this_generation_contenders_total_score += player_configs["previous_ai_adjusted_highscore"]
			ai_games_node.add_child(game)
			x_pos += 1000
			if i == 1:
				x_pos = 60
				y_pos += 1100
			if i > 1 and i % 10 == 0:
				x_pos = 60
				y_pos += 1100
		# FEEDERS
		for i in range(num_best_players, num_players):
			var game: Game = play_package.instantiate()
			var player_configs = ranked_players[i]
			game.ai_controlled = true
			game.debug = debug
			game.player_name = player_configs["player_name"]
			game.training = true
			game.mute_sound = true
			game.mutation_rate = 10
			# if it had a good game last generation then let it try again
			if player_configs["previous_ai_adjusted_highscore"] > 80000:
				print(
					(
						"%s. FEEDER %s: %s (%s) will try to improve its personal best"
						% [
							i,
							player_configs["player_name"],
							player_configs["previous_highscore"],
							player_configs["previous_ai_adjusted_highscore"]
						]
					)
				)
				game.ai_use_best_rate = 0
				game.ai_use_personal_rate = 100
			else:
				# otherwise tell it to reference a random best player instead of always the "best" entry
				game.reference_ai_name = ranked_players[randi_range(0, num_best_players)]["player_name"]
				print(
					(
						"%s. FEEDER %s: %s (%s) will copy %s"
						% [
							i,
							player_configs["player_name"],
							player_configs["previous_highscore"],
							player_configs["previous_ai_adjusted_highscore"],
							game.reference_ai_name
						]
					)
				)
				game.ai_use_best_rate = 100
				game.ai_use_personal_rate = 0
			total_score += player_configs["ai_adjusted_highscore"]
			this_generation_total_score += player_configs["previous_ai_adjusted_highscore"]
			game.position = Vector2(x_pos, y_pos)
			ai_games_node.add_child(game)
			x_pos += 1000
			if i % 10 == 0:
				x_pos = 60
				y_pos += 1100

		print("=Global Total Average Adjusted Highscores: %s=" % [total_score / num_ai])
		print(
			(
				"=Global CONTENDER Average Adjusted Highscores: %s="
				% [contenders_total_score / num_best_players]
			)
		)
		print(
			(
				"=Gen %s Total Average Adjusted Highscores: %s="
				% [generation, this_generation_total_score / num_ai]
			)
		)
		print(
			(
				"=Gen %s CONTENDER Average Adjusted Highscores: %s="
				% [generation, this_generation_contenders_total_score / num_best_players]
			)
		)
		print(
			(
				"=Gen %s CONTENDER Average Actual Highscores: %s="
				% [generation, this_generation_contenders_total_actual_score / num_best_players]
			)
		)
		generation += 1
		print("===Begin generation %s===" % [generation])
	else:
		if currently_watching_game == null and num_ai > 2:
			for game in ai_games_node.get_children():
				if is_instance_of(game, Game):
					print("Now watching %s" % [game.player_name])
					game.mute_sound = true
					camera.position.x = game.position.x + 910
					camera.position.y = game.position.y + 538
					camera.zoom.x = 1
					camera.zoom.y = 1
					currently_watching_game = game
					break
