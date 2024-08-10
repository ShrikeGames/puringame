extends Node2D

@export var num_ai: int = 12
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false
@export var auto_retry: bool = false
@export var max_retry_attempts: int = 999
@export var camera:Camera2D
@export var battle_mode:bool = false
var generation_ended:bool = false
var generation_timer:float = 0.0

var games:Array[PlayerController]
@export var generation:int = 0
var following_game:PlayerController
func _on_ready() -> void:
	init_ai_players();
	
func init_ai_players():
	Engine.time_scale = time_scale
	
	if generation >= 1:
		var config_json = Global.read_json("user://ai_v2_%s.json"%[generation])
		
		var stats:Dictionary ={
			"0":{},
			"1":{},
			"2":{},
			"3":{},
			"4":{},
			"5":{},
			"6":{},
			"7":{},
			"8":{},
			"9":{},
			"10":{}
		}
		if config_json:
			var history:Array = config_json.get("history", [])
			history.sort_custom(rank_history)
			# only save the top 50%
			history = history.slice(0, round(num_ai*0.5))
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
				var configurations:Dictionary = config.get("configurations")
				if configurations:
					var total_weights:Array = stats.get("total_weights", [0,0,0,0,0,0])
					var purin_weights:Array = configurations.get("weights")
					for i in range(0, len(total_weights)):
						total_weights[i] += purin_weights[i]
					stats["total_weights"] = total_weights
					
			
			var total_weights:Array = stats["total_weights"]
			var average_weights:Array = [0,0,0,0,0,0]
			for i in range(0, 6):
				average_weights[i] = total_weights[i]/float(total_count)
			print("Average Weights for Generation %s's was %s"%[generation, average_weights])
			
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
		game.max_retry_attempts = max_retry_attempts
		if generation == 1 and i > 9:
			game.ai_mutation_rate = 1
		else:
			if i < num_ai * 0.5:
				game.ai_mutation_rate = 0.1
			else:
				game.ai_mutation_rate = 0.2
		game.training = true
		var player_name = "ai%s_%s"%[generation, i]
		game.player_name = player_name
		game.rank = i
		
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
			if not is_instance_valid(following_game) or (is_instance_valid(game) and game.score > 90000 and game.score > following_game.score and game.player_name != following_game.player_name):
				following_game = game
				updated = true
		if updated:
			camera.position.x = 960
			camera.position.y = following_game.position.y + 535
			
	
