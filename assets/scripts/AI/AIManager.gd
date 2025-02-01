extends Node2D

@export var num_ai: int = 12
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 1.0
@export var debug: bool = false
@export var camera:Camera2D
@export var battle_mode:bool = false
var generation_ended:bool = false
var generation_timer:float = 0.0

var games:Array[PlayerController]
@export var generation:int = 0

var training_data:Array
func _on_ready() -> void:
	init_ai_players()
	
func init_ai_players():
	Engine.time_scale = time_scale
	print("Begin Generation %s"%[generation])
	# TODO
