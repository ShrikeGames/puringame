extends Node2D

@export var num_ai: int = 12
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	Engine.time_scale = time_scale
	init_ai_players();
	
func init_ai_players():
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# check if all games are done
	if ai_games_node and ai_games_node.get_child_count() <= 0:
		init_ai_players();
