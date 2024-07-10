extends Node2D

@export var num_ai: int = 12
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false
@export var players_game: Game;
var config_path: String = "user://%s.cfg" % ["best_v3"]
var games:Array[Game];
var ai_games:Array[Game];

# Called when the node enters the scene tree for the first time.
func _ready():
	Engine.time_scale = time_scale
	init_ai_players();
	
func init_ai_players():
	games = [players_game]
	ai_games = []
	var config = ConfigFile.new()
	config.load(config_path)
	var x_pos: int = 0
	var y_pos: int = 0
	for i in range(0, num_ai):
		var game: Game = play_package.instantiate()
		game.ai_controlled = true
		game.debug = debug
		game.player_name = "AI%s" % [i]
		game.best_config = "best"
		game.training = false
		game.mute_sound = true
		game.mutation_rate = 30
		game.ai_use_best_rate = 100
		game.ai_use_personal_rate = 0
		game.position = Vector2(x_pos, y_pos)
		game.scale = Vector2(0.30, 0.30)
		games.append(game)
		ai_games.append(game)
		game.opposing_games = games
		ai_games_node.add_child(game)
		
		x_pos += 285
		if i > 0 and (i+1) % 3 == 0:
			x_pos = 0
			y_pos += 325
	players_game.opposing_games = ai_games
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# check if all games are done
	if ai_games_node and ai_games_node.get_child_count() <= 0:
		init_ai_players();
