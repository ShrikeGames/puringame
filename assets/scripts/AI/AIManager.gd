extends Node2D

@export var num_ai: int = 12
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false
@export var camera:Camera2D

var generation_ended:bool = false
var generation_timer:float = 0.0

var games:Array[PlayerController]
var generation:int = 0
var following_game:PlayerController
func _on_ready() -> void:
	init_ai_players();
	
func init_ai_players():
	Engine.time_scale = time_scale
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
		game.auto_retry = true
		game.ai_mutation_rate = 0.05 + (i*0.01)
		game.training = true
		var player_name = "ai%s_%s"%[generation, i]
		game.player_name = player_name
		game.config_path = "user://ai.json"
		game.default_config_path = "res://ai.json"
		game.position = Vector2(40 + (x_pos*1020), y_pos)
		ai_games_node.add_child(game)
		game.init()
		game.set_up_game()
		games.append(game)
		x_pos += 1
		if i > 0 and (i+1) % 2 == 0:
			y_pos += 1080
			x_pos = 0
	following_game = games[0]
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
			if is_instance_valid(game) and game.score > 30000 and game.score > following_game.score and game.player_name != following_game.player_name:
				following_game = game
				updated = true
		if updated:
			camera.position.x = 960
			camera.position.y = following_game.position.y + 535
			
	
