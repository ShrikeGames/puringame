extends Node2D

@export var num_ai: int = 8
var play_package: Resource = load("res://assets/scenes/PlayAreaBowl.tscn")
@export var ai_games_node: Node2D
@export var time_scale: float = 2
@export var camera:Camera2D
@export var graph:Graph

@export var generation:int = 1
@export var max_idle_time:float = 40

var total_score:float = 0
var best_score:float = 0
var game_count:int = 0
var training_data:Array
var multi_thread_training:bool = true

func _on_ready() -> void:
	init_ai_players()
	

func init_ai_players():
	Engine.time_scale = time_scale
	print("Begin Generation %s"%[generation])
	camera.ai_games_node = ai_games_node
	game_count = 0
	total_score = 0
	
	var x_pos:int = 17
	var y_pos:int = 0
	for i in range(0, num_ai):
		var game:PlayerController = play_package.instantiate()
		game.ai_controlled = true
		game.temperature = max(0.4, (i+1) / float(num_ai))
		game.training = true
		game.mute_sound = true
		game.debug = true
		var player_name = "ai%s"%(i)
		game.player_name = player_name
		game.position = Vector2(x_pos, y_pos)
		game.random_initial_board_state = false
		
		x_pos += 1056
		if i >0 and (i+1) % 2 == 0:
			x_pos = 17
			y_pos += 1080
		ai_games_node.add_child(game)
		game.connect("gameover", game_died)
		game.connect("train", train)
	
	Global.async_trainer.connect("training_completed", training_completed)

func training_completed():
	graph.add_point("return", Global.best_brain.metrics_avg_return)
	graph.add_point("advantage", Global.best_brain.metrics_avg_advantage)
	graph.add_point("policy", Global.best_brain.metrics_policy_loss)
	graph.add_point("value", Global.best_brain.metrics_value_loss)


func train(experience_pool:ExperiencePool):
	# train on whatever is there
	var batch_size: int = experience_pool.get_buffer_size()
	train_on_batch(experience_pool, batch_size)
	
func game_died(experience_pool:ExperiencePool, player_name:String, score:float, total_rewards:float):
	total_score += score
	graph.add_point("score", score)
	graph.add_point("rewards", total_rewards)
	game_count += 1
	if score > best_score:
		best_score = score
		print("[Metric] New best score of %s from %s"%[best_score, player_name])
	else:
		print("[Metric] Score of %s from %s"%[score, player_name])
	print("[Metric] Average Score: %s from %s games"%[total_score/float(game_count), game_count])
	
	# train on whatever is there
	var batch_size: int = experience_pool.get_buffer_size()
	train_on_batch(experience_pool, batch_size)

func train_on_batch(experience_pool:ExperiencePool, batch_size:int):
	# Ensure we have enough experience
	print("Training on batch of size: ", batch_size)
	# Sample random experiences from buffer
	var batch = experience_pool.sample_batch(batch_size)
	
	# Prepare batch
	var states_data: Array = []
	var actions_data: Array = []
	var rewards_data: Array = []
	var next_states_data: Array = []
	var dones_data: Array = []
	
	# Collect batch data
	for experience in batch:
		states_data.append(experience["state"])
		actions_data.append(experience["action"])
		rewards_data.append(experience["reward"])
		next_states_data.append(experience["next_state"])
		dones_data.append(experience["done"])
	experience_pool.buffer.clear()
	# Train on batch
	if multi_thread_training:
		Global.async_trainer.enqueue_training(states_data, actions_data, rewards_data, next_states_data, dones_data)
	else:
		print("Before train function")
		Global.best_brain.train(states_data, actions_data, rewards_data, next_states_data, dones_data)
		print("After train function")
		Global.best_brain.save_model(Global.ai_brain_path)
		print("After save function")
		training_completed()
