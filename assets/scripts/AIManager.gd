extends Node2D

@export var num_ai:int = 2;
var play_package:Resource = load("res://assets/scenes/PlayAreaBowl.tscn");
var ai_games_node:Node2D;
var generation:int;
@export var camera:Camera2D;
@export var best_ratio:float = 0.1;
@export var time_scale:float = 1.0;
var average_score:float = 0.0;
var best_average_score:float = 0.0;
var currently_watching_game:Game = null;
var global_best_score_history = [];
var global_average_best_score_history = [];
var gen_best_score_history = [];
var config_path:String = "user://%s.cfg"%["best"];
# Called when the node enters the scene tree for the first time.
func _ready():
	ai_games_node = get_node("AIGames");
	generation = 0;
	Engine.time_scale = time_scale;
	

func rank_players(player1, player2):
	var p1_score = (player1["ai_adjusted_highscore"] *0.5) + (player1["previous_ai_adjusted_highscore"] *0.5);
	var p2_score = (player2["ai_adjusted_highscore"] *0.5) + (player2["previous_ai_adjusted_highscore"] *0.5);
	if p1_score > p2_score:
		return true;
	return false;

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
		print("Generation %s has concluded."%[generation]);
		var best_config = "best";
		var config = ConfigFile.new();
		print(config_path);
		config.load(config_path);
		var best_score:float = config.get_value(best_config, "highscore", 0);
		print("The all time best score is: %s"%(best_score));
		global_best_score_history.append(best_score);
		
		var total_score:float = 0;
		var ranked_players:Array = [];
		for i in range(0, 300):
			var player = "AI%d"%[i];
			var player_stats = {
				"highscore": config.get_value(player, "highscore", 0),
				"ai_adjusted_highscore": config.get_value(player, "ai_adjusted_highscore", 0),
				"previous_highscore": config.get_value(player, "previous_highscore", 0),
				"previous_ai_adjusted_highscore": config.get_value(player, "previous_ai_adjusted_highscore", 0),
				"x": config.get_value(player, "x", 1),
				"y": config.get_value(player, "y", 1),
				"l": config.get_value(player, "l", 1),
				"s": config.get_value(player, "s", 1),
				"c": config.get_value(player, "c", 1),
				"d1": config.get_value(player, "d1", 1),
				"d2": config.get_value(player, "d2", 1),
				"drop_bias": config.get_value(player, "drop_bias", 1),
				"np": config.get_value(player, "np", 1),
				"player_name": config.get_value(player, "player_name", player),
				"highest_level_reached": config.get_value(player, "highest_level_reached", 0)
			}
			ranked_players.append(player_stats.duplicate(true));
		ranked_players.sort_custom(rank_players);
		var num_players = min(len(ranked_players), num_ai);
		# take the best 50%
		var best_of_generation:Array = ranked_players.slice(0, round(num_players*best_ratio));
		# recreate those 50%
		var x_pos:int = 60;
		var y_pos:int = 0;
		var best_total_scores:float = 0.0;
		
		for i in range(0, len(best_of_generation)):
			var game:Game = play_package.instantiate();
			var player_configs = best_of_generation[i];
			
			total_score += config.get_value(player_configs["player_name"], "previous_highscore", 0);
			best_total_scores += config.get_value(player_configs["player_name"], "previous_highscore", 0);
			game.ai_controlled = true;
			game.training = true;
			game.debug=true;
			game.player_name = player_configs["player_name"];
			game.AI_X_WEIGHT = player_configs["x"];
			game.AI_Y_WEIGHT = player_configs["y"];
			game.AI_LEVEL_WEIGHT = player_configs["l"];
			game.AI_STACKED_WEIGHT = player_configs["s"];
			game.AI_EASY_COMBINE_WEIGHT = player_configs["c"];
			game.AI_DROP_DELAY_SECONDS = player_configs["d1"];
			game.AI_DROP_DELAY_PANIC_SECONDS = player_configs["d2"];
			game.drop_bias = player_configs["drop_bias"];
			game.next_purin_weight = player_configs["np"];
			game.highscore = player_configs["highscore"];
			game.ai_adjusted_highscore = player_configs["ai_adjusted_highscore"];
			game.mute_sound = true;
			game.position = Vector2(x_pos, y_pos);
			game.mutation_rate = 10;
			game.ai_use_best_rate = 0;
			game.ai_use_personal_rate = 100;
			
			ai_games_node.add_child(game);
			x_pos += 1000;
			if i == 1:
				x_pos = 60;
				y_pos += 1100;
			if  i > 1 and i % 10 == 0:
				x_pos = 60;
				y_pos += 1100;
		
		# for the rest generate as normal
		for i in range(len(best_of_generation), num_ai):
			var game:Game = play_package.instantiate();
			var player_configs = ranked_players[i];
			var prev_score = config.get_value(player_configs["player_name"], "previous_highscore", 0);
			total_score += prev_score;
			game.ai_controlled = true;
			game.debug=true;
			game.player_name = player_configs["player_name"];
			game.training = true;
			game.mute_sound = true;
			game.position = Vector2(x_pos, y_pos);
			if prev_score > 50000:
				game.mutation_rate = 10;
				game.ai_use_best_rate = 0;
				game.ai_use_personal_rate = 100;
			else:
				game.mutation_rate = 30;
				game.ai_use_best_rate = 100;
				game.ai_use_personal_rate = 0;
				
			ai_games_node.add_child(game);
			x_pos += 1000;
			if i > 0 and i % 10 == 0:
				x_pos = 40;
				y_pos += 1100;
		generation += 1;
		if camera and num_players > 2:
			camera.position.x = 980;
			camera.position.y = 538;
			camera.zoom.x = 1;
			camera.zoom.y = 1;
		for player in best_of_generation:
			print("%s: %s for a difference of %s"%[player["player_name"],  player["previous_highscore"],  player["previous_highscore"]-player["highscore"]])
		
		average_score = total_score / num_ai;
		print("The AVERAGE score for the last generation was: %s"%(average_score));
		best_average_score = best_total_scores / len(best_of_generation)
		print("The AVERAGE score among the BEST %s PLAYERS for the last generation was: %s"%[len(best_of_generation), best_average_score]);
		global_average_best_score_history.append(best_average_score);
		gen_best_score_history.append(best_of_generation[0]["previous_highscore"]);
		print("World Record History:", global_best_score_history);
		print("Generation Average Record History:", global_average_best_score_history);
		print("Generation Best Record History:", gen_best_score_history);
	else:
		if currently_watching_game == null and num_ai > 2:
			for game in ai_games_node.get_children():
				if is_instance_of(game, Game):
					print("Now watching %s"%[game.player_name]);
					game.mute_sound = false;
					camera.position.x = game.position.x + 910;
					camera.position.y = game.position.y + 538;
					camera.zoom.x = 1;
					camera.zoom.y = 1;
					currently_watching_game = game;
					break;
