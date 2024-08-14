extends Camera2D

@export var camera_move_speed: float = 1080
@export var camera_zoom_speed: float = 0.1
var games:Array[PlayerController] = []
var following_game:PlayerController = null
var index:int = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if following_game and not is_instance_valid(following_game):
		var new_games_list:Array[PlayerController] = []
		for game in games:
			if is_instance_valid(game):
				new_games_list.append(game)
		games = new_games_list
		index = 0
		following_game = games[0]
		
	if not following_game or not is_instance_valid(following_game):
		var i:int = 0
		for game in games:
			if is_instance_valid(game) and is_instance_valid(game.source_network) and (not is_instance_valid(following_game) or (game.source_network.fitness > following_game.source_network.fitness and game.player_name != following_game.player_name)):
				following_game = game
				index = i
				break
			i += 1 
	
	if Input.is_action_just_pressed("scroll_down") or Input.is_action_just_pressed("move_down"):
		index = wrapi(index+2, 0, len(games)-1)
		following_game = games[index]
	if Input.is_action_just_pressed("scroll_up") or Input.is_action_just_pressed("move_up"):
		index = wrapi(index-2, 0, len(games)-1)
		following_game = games[index]
	if Input.is_action_just_pressed("move_right"):
		for i in range(games.size()):
			if is_instance_valid(games[i]) and games[i].source_network.fitness > following_game.source_network.fitness:
				index = i
				following_game = games[index]
	if Input.is_action_just_pressed("move_left"):
		for i in range(games.size()):
			if is_instance_valid(games[i]) and games[i].source_network.fitness < following_game.source_network.fitness:
				index = i
				following_game = games[index]
	
	if following_game and is_instance_valid(following_game):
		position.x = 960
		position.y = following_game.position.y + 535
	
