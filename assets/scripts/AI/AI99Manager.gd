extends Node2D

@export var player_game:PlayerController;
@export var num_ai: int = 9
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false

var games:Array[PlayerController]
# Called when the node enters the scene tree for the first time.
func _on_ready():
	Engine.time_scale = time_scale
	init_ai_players();
	
func init_ai_players():
	games = []
	var x_pos:int = 0
	var y_pos:int = 0
	for i in range(0, num_ai):
		var game:PlayerController = play_package.instantiate()
		game.ai_controlled = true
		game.mute_sound = true
		game.auto_retry = false
		game.training = false
		game.ai_mutation_rate = 0
		var player_name = "ai%s"%(i)
		game.player_name = player_name
		game.config_path = "res://ai.cfg"
		game.default_config_path = "res://default.json"
		game.scale.x = 0.3
		game.scale.y = 0.3
		game.position = Vector2(x_pos, y_pos)
		
		x_pos += 310
		if i >0 and (i+1) % 3 == 0:
			x_pos = 0
			y_pos += 310
		ai_games_node.add_child(game)
		game.init()
		games.append(game)
	#player_game.opponents = games
	games.append(player_game)
	
	for game in games:
		game.opponents = games
	
