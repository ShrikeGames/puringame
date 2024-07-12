extends Node2D

@export var num_ai: int = 2
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
var generation: int
@export var camera: Camera2D
@export var best_ratio: float = 0.1
@export var time_scale: float = 1.0
@export var debug: bool = false


# Called when the node enters the scene tree for the first time.
func _ready():
	generation = 0
	Engine.time_scale = time_scale


func rank_players(player1, player2):
	var p1_score = (player1["ai_adjusted_highscore"] * 0.1) + (player1["previous_ai_adjusted_highscore"] * 0.9)
	var p2_score = (player2["ai_adjusted_highscore"] * 0.1) + (player2["previous_ai_adjusted_highscore"] * 0.9)
	if float(p1_score) > float(p2_score):
		return true
	return false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
			
