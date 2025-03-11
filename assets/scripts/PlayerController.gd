extends Node2D
class_name PlayerController
# random number generator seed
var initial_seed:String

@export_category("Configs")
@export var player_name: String = "player"
@export var config_path: String = "user://player.json"
@export var default_config_path: String = "res://default.json"

@export var ai_controlled: bool = false
@export var vs_player: bool = false
@export var debug:bool = false

@export_category("Brain")
@export var fov_degrees:float = 120
# how many raycasts are done within the fov
@export var num_raycasts:int = 40
# distance raycasts will travel to look for collisions
@export var sight:float = 800
# Number of input neurons
@export var input_nodes: int = -1
# 
@export var hidden_sizes: Array[int] = Global.BRAIN_HIDDEN_LAYERS
# Number of output neurons
@export var output_nodes: int = -1
@export var predict_every_sec:float = 0.24
@export var random_initial_board_state:bool = false


var time_since_last_prediction_sec:float = 0
var time_since_last_score:float = 0

@export_category("References")
@export var eyes:Eyes
@export var leaderboard:Leaderboard
@export var noir: NoiR
@export var purin_bag: PurinBag
@export var top_edge: Node2D
@export var left_edge: Node2D
@export var right_edge: Node2D
@export var bottom_edge: Node2D
@export var purin_node: Node2D
@export var scoreorb_node: Node2D
@export var scoreorb_target: Node2D
@export var prediction_icon: Sprite2D
@export var best_icon: Sprite2D
@export var sfx_pop_player: AudioStreamPlayer
@export var sfx_bonk_player: AudioStreamPlayer
@export var mute_sound: bool = false
@export var opponents: Array[PlayerController] = []
@export var gameover_screen: Node2D
@export var player_label: RichTextLabel
@export var debug_label: RichTextLabel
@export var score_label: RichTextLabel
@export_category("Stats")
@export var move_speed: float = 450.0
@export var last_mouse_pos:Vector2 = Vector2(0.0, 0.0)
@export var max_score_history_length:int = 10

var can_drop_early: bool =false
var auto_drop:bool = false
var config_json:Dictionary
var default_config_json:Dictionary

var score: int = 0
var dropped_purin_count: int = 0
var last_dropped_purin:Purin = null
var last_dropped_purin_touched_something:bool = false

var time_since_last_dropped_purin_sec: float = 0
var drop_purin_cooldown_sec: float = 0.25
var previous_highest_prediction_index:int = 0

var skip_saving:bool = false
var training:bool = true

var board_value:float = 0
var previous_board_value:float = 0
var previous_state: Tensor = null
var previous_action: int = -1
var previous_score: int = 0
var waiting_for_action_resolution: bool = false

func _on_ready():
	if initial_seed:
		seed(initial_seed.hash())
	
	# set game speed
	if not ai_controlled:
		Engine.time_scale = Global.game_speed
	init()


func init():
	#print("Init player controller for ",player_name)
	load_configs()
	# set up the game, can be called to restart at anytime
	set_up_game()

func load_configs():
	config_json = Global.read_json(config_path)
	default_config_json = Global.read_json(default_config_path)
	if config_json == null:
		config_json = default_config_json
	
func get_configurations(key: String, default_default_value = {}, random:bool=true, config_index:int=0):
	var config_value = {}
	var default_value = default_default_value
	var default_history_run:Dictionary
	if random:
		default_history_run = default_config_json.get("history", [{}]).pick_random()
	else:
		default_history_run = default_config_json.get("history", [{}])[min(config_index, len(default_config_json.get("history", [{}]))-1)]
	
	if default_history_run.has(key):
		default_value = default_history_run.get(key)
	
	var config_history_run:Dictionary 
	if random:
		config_history_run = config_json.get("history", [{}]).pick_random()
	else:
		config_history_run = config_json.get("history", [{}])[min(config_index, len(config_json.get("history", [{}]))-1)]
	
	if config_history_run.has(key):
		config_value = config_history_run.get(key, default_value)
	else:
		config_value = default_value
	
	return config_value

func restart_game():
	print("Restart game for ", player_name)
	set_up_game()

func set_up_game():
	
	# clear the game of any dropped purin
	remove_all_purin()
	# reset progress
	score = 0
	board_value = 0
	time_since_last_score = 0
	previous_state = null
	previous_action = -1
	previous_score = 0
	previous_board_value = 0
	waiting_for_action_resolution = false
	dropped_purin_count = 0
	time_since_last_prediction_sec = 0
	drop_purin_cooldown_sec = 0.25
	time_since_last_dropped_purin_sec = drop_purin_cooldown_sec
	previous_highest_prediction_index = 0
	skip_saving = false
	can_drop_early = false
	# Generate a new bag of purin (what you get next to drop)
	# for AI and such that don't need a visual representation of their bag shown
	if purin_bag == null:
		purin_bag = PurinBag.new()
		purin_bag.visible = false
		self.add_child(purin_bag)
	purin_bag.max_purin_level = 0
	purin_bag.bag = []
	purin_bag.generate_purin_bag()
	noir.change_held_purin(purin_bag.get_current_purin())
	player_label.text = player_name
	update_score_label()

	gameover_screen.visible = false
	debug_label.visible = debug
	last_dropped_purin = null
	
	if ai_controlled:
		if not eyes.initialized:
			eyes.init(fov_degrees, num_raycasts, sight)
		if random_initial_board_state:
			noir.position.x = randi_range(20, 780)
			spawn_purin(Vector2(randf_range(20,780), 780), {"level": 0, "evil": false})
			#last_dropped_purin = purin_node.get_child(0)
		else:
			noir.position.x = 400
		
		if input_nodes < 0:
			input_nodes = 1 + ((num_raycasts + 1) * 3)
			output_nodes = Global.OUTPUT_NODES
		
		if not Global.best_brain:
			Global.best_brain = PPO.new(input_nodes, hidden_sizes, output_nodes)
		
	
func remove_all_purin():
	for purin in purin_node.get_children():
		purin.queue_free()
		
func update_score_label():
	if score_label != null:
		score_label.text = "[center]%s[/center]" % [score]

func rank_history(run1:Dictionary, run2:Dictionary):
	if run1.get("score", 0) > run2.get("score", 0):
		return true
	return false
	
func save_results():
	if skip_saving:
		return
	
	# cannot save to read-only res:// location
	if config_path.contains("res://"):
		return
	# get latest copies of the configs before updating themsa
	config_json = Global.read_json(config_path)
	default_config_json = Global.read_json(default_config_path)
	if config_json == null:
		config_json = default_config_json
	if config_json == null:
		print("No config_json was loaded? ", config_path)
		return
	# update config
	var history:Array = config_json.get("history", [])
	
	# only save the last 10 after sorting
	config_json["history"] = history.slice(0, min(max_score_history_length+1, len(history)))
	
	# save the results
	var json_string := JSON.stringify(config_json)
	# We will need to open/create a new file for this data string
	var file_access := FileAccess.open(config_path, FileAccess.WRITE)
	if not file_access:
		print("An error happened while saving data: ", FileAccess.get_open_error())
		return
		
	file_access.store_line(json_string)
	file_access.close()
	if leaderboard:
		leaderboard.update()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if check_game_over(delta):
		return

	time_since_last_dropped_purin_sec += delta
	if not ai_controlled:
		process_player(delta)
	else:
		process_ai(delta)


func check_game_over(delta):
	if gameover_screen.visible == true:
		
		if Input.is_action_pressed("retry"):
			#print("retry action pressed? ", Input.is_action_pressed("retry"))
			#print("auto_retry? ", auto_retry)
			save_results()
			get_tree().paused = false
			restart_game()
			if not ai_controlled and opponents:
				for opponent in opponents:
					if is_instance_valid(opponent):
						opponent.gameover_screen.visible = true
						opponent.save_results()
						opponent.restart_game()
		return true
	for purin in purin_node.get_children():
		if not is_instance_of(purin, Purin):
			continue
		# if the purin's game over time reaches the threshold you lose
		if ( 
			purin.game_over_timer_sec >= Global.game_over_threshold_sec
		):
			if not ai_controlled:
				print("GameOver %s"%[score])
			gameover_screen.visible = true
			purin.game_over_timer_sec = Global.game_over_threshold_sec
			
			if not ai_controlled:
				get_tree().paused = true
			
			return true
		if purin.position.x < left_edge.position.x:
			purin.position.x = left_edge.position.x
		elif purin.position.x > right_edge.position.x:
			purin.position.x = right_edge.position.x
#		elif purin.position.y < top_edge.position.y:
#			purin.position.y = top_edge.position.y
		
		# if the purin is above the height threshold start increasing its conter
		if (purin.position.y - purin.get_meta("radius") < top_edge.position.y):
			purin.game_over_timer_sec += delta
			#completely off screen
			if purin.position.y+purin.get_meta("radius") < 0:
				purin.game_over_timer_sec = Global.game_over_threshold_sec
			# if the counter is under 3 sec then start the 3sec countdown animation too
			# allows longer count downs even though the animation only counts down from 3
			if purin.game_over_timer_sec > Global.game_over_threshold_sec - 3:
				purin.game_over_countdown.visible = true
				if not purin.game_over_countdown.is_playing():
					purin.game_over_countdown.play()
			else:
				purin.game_over_countdown.visible = false
				purin.game_over_countdown.stop()
		else:
			# otherwise it's safe, so reset its counter if needed and hide the animation
			purin.game_over_timer_sec = 0
			purin.game_over_countdown.visible = false
			purin.game_over_countdown.stop()
	return false

func process_player(delta):
	if gameover_screen.visible:
		return
	# reposition the player
	update_noir_position(delta)
	# check inputs
	var just_pressed:bool = Input.is_action_just_pressed("drop_purin")
	var just_released:bool = Input.is_action_just_released("drop_purin")
	
	# accessibility setting will cause you to always drop until toggled off
	if just_released and Global.drop_troggle:
		# toggle between auto drop on or off
		auto_drop = not auto_drop
	if (
		(just_pressed and time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec) 
		or (Global.drop_troggle and auto_drop  and time_since_last_dropped_purin_sec >= max(drop_purin_cooldown_sec, Global.auto_drop_cooldown_sec))
	):
		drop_purin()

func drop_purin():
	spawn_purin()
	noir.change_held_purin(purin_bag.get_current_purin())
	time_since_last_dropped_purin_sec = 0
	last_dropped_purin_touched_something = false
	if opponents and not opponents.is_empty():
		for opponent in opponents:
			if is_instance_valid(opponent):
				opponent.can_drop_early = true
			else:
				remove_dead_opponents()

func update_noir_position(delta):
	
	if Input.is_action_pressed("move_left"):
		Global.active_controls = "not_mouse"
		noir.position.x = valid_x_pos(noir.position.x - (move_speed*delta))
	elif Input.is_action_pressed("move_right"):
		Global.active_controls = "not_mouse"
		noir.position.x = valid_x_pos(noir.position.x + (move_speed*delta))
	else:
		# get mouse position in local coords instead of global
		var mouse_pos = to_local(get_viewport().get_mouse_position())
		if mouse_pos.x != last_mouse_pos.x and mouse_pos.y != last_mouse_pos.y:
			Global.active_controls = "mouse"
		last_mouse_pos = mouse_pos
		if Global.active_controls == "mouse":
			noir.position.x = valid_x_pos(mouse_pos.x)
	
func valid_x_pos(x_pos: float):
	return max(left_edge.position.x + 20, min(x_pos, right_edge.position.x - 20))


func spawn_purin(
	initial_position: Vector2 = noir.position,
	purin_info = purin_bag.drop_purin()
):
	# level is 0-indexed
	var purin: Purin = Global.purin_object_scene.instantiate()
	purin.position = Vector2(valid_x_pos(initial_position.x), initial_position.y)
	var level = purin_info["level"]
	purin.colour = Global.purin_colours_by_level[level]
	purin.set_meta("colour", purin.colour)
	var evil = purin_info["evil"]
	purin.set_meta("level", level)
	purin.set_meta("combined", false)
	if evil:
		purin.image.texture = Global.evil_purin_textures[level]
	else:
		purin.image.texture = Global.purin_textures[level]
	purin.image.scale = self.scale
	purin.mass = pow(1.4, level)
	# update collider shape to be appropriate size
	var new_shape = CircleShape2D.new()
	var new_radius: float = get_purin_radius(level)
	new_shape.radius = new_radius
	purin.set_meta("radius", new_radius)
	purin.collider.shape = new_shape
	purin.particle_system.scale = Vector2(2+level, 2+level)
	purin.particle_system.process_material.emission_sphere_radius = new_radius * 0.5
	
	# if it's an evil purin then make that visible
	if evil and not training:
		purin.evil = true
		# if it's evil then make have more mass than normal
		purin.mass = pow(1.4, level+2)
		# evil ones spawn at the bottom
		purin.position = Vector2(purin.position.x, purin.position.y)
		

	# listen to its signals for combining or bonking
	purin.connect("combine", combine_purin)
	purin.connect("bonk", bonk_purin)

	# add it to the stage
	purin_node.call_deferred("add_child", purin)
	
	# keep track of how many total were spawned for scoring purposes
	dropped_purin_count += 1
	last_dropped_purin = purin
	return purin

func get_purin_radius(level: int):
	return (Global.purin_sizes[level] * 0.5) * 1.17 * self.scale.x

func score_by_level(level:int):
	#return int(pow(level+1, 3))
	return int(pow(level+1, 2)) * int(1 + (dropped_purin_count * 0.1))

func combine_purin(purin1: Purin, purin2: Purin):
	# if they were already freed then we have nothing to do
	if not is_instance_valid(purin1) or not is_instance_valid(purin2):
		return
	# if both were evil before, so is the new one, otherwise it'll be normal
	var evil = purin1.evil and purin2.evil
	var partial_evil = purin1.evil or purin2.evil

	if not evil and partial_evil:
		# one is evil and not the other, cannot merge >:D
		return
		
	if purin1.get_meta("level") != purin2.get_meta("level"):
		print("Error: Cannot combine two purin of different levels")
		return

	# average position between the two
	var spawn_x = (purin1.position.x + purin2.position.x) * 0.5
	var spawn_y = (purin1.position.y + purin2.position.y) * 0.5

	# also average their rotate and velocity
	var spawn_rotation = (purin1.rotation + purin2.rotation) * 0.5
	var spawn_angular_velocity = (purin1.angular_velocity + purin2.angular_velocity) * 0.5
	var spawn_linear_velocity = (purin1.linear_velocity + purin2.linear_velocity) * 0.5

	
	# combined purin will be of 1 level higher up to the max
	var new_level = purin1.get_meta("level") + 1
	
	if is_instance_valid(last_dropped_purin) and (last_dropped_purin == purin1 or last_dropped_purin == purin2):
		last_dropped_purin_touched_something = true
	
	
	# remove the two purin
	purin1.queue_free()
	purin2.queue_free()
	var new_purin
	
	if new_level <= Global.highest_possible_purin_level:
		# create new purin of highest level
		new_purin = spawn_purin(Vector2(spawn_x, spawn_y), {"level": new_level, "evil": false})
		# set its new values based on the combined stats
		new_purin.rotation = spawn_rotation
		if training:
			new_purin.evil = false
		else:
			new_purin.evil = evil
		
		if evil and not training:
			# if it's evil then make have more mass than normal
			new_purin.mass = pow(1.2, new_level+2)
		elif not opponents.is_empty() and new_level >= Global.evil_purin_spawn_level_threshold:
			remove_dead_opponents()
			if not opponents.is_empty() and not training:
				# if it's not evil then depending on level it could spawn an evil purin in opponent's game
				var opponent: PlayerController = opponents.pick_random()
				if is_instance_valid(opponent) and opponent.player_name != player_name:
					var evilorb: EvilOrb = Global.evil_orb_scene.instantiate()
					evilorb.purin_level = new_level
					evilorb.position = to_global(new_purin.position)
					evilorb.opponent = opponent
					if opponent.purin_bag.visible == true:
						evilorb.target_position = opponent.purin_bag.position
					else:
						evilorb.target_position = opponent.position
					evilorb.connect("evilguh", add_evil_purin)
					get_tree().root.add_child(evilorb)
		new_purin.angular_velocity = spawn_angular_velocity
		new_purin.linear_velocity = spawn_linear_velocity
		# play sfx if not muted
		if not mute_sound:
			sfx_pop_player.play()
		

	if new_level > purin_bag.max_purin_level:
		purin_bag.max_purin_level = new_level
		purin_bag.bag.append_array(
			purin_bag.generate_purin_bag()
		)
	# give the player score based on the size of the purin that was combined into
	# and give a multiplier that increases the more purin they have placed
	# so the value goes up the longer they play giving it a non-linear curve
	var score_increase = score_by_level(new_level)
	var scoreorb:ScoreOrb = Global.score_orb_scene.instantiate()
	scoreorb.score_worth = score_increase
	scoreorb.position = Vector2(spawn_x, spawn_y)
	scoreorb.target_position = scoreorb_target.position
	scoreorb_node.add_child(scoreorb)
	time_since_last_score = 0
	scoreorb.connect("scored", gain_score)
	
	if new_purin:
		last_dropped_purin = new_purin
		last_dropped_purin_touched_something = false
		return new_purin
	return null
	
func add_evil_purin(level, opponent):
	if not is_instance_valid(opponent):
		remove_dead_opponents()
		return
	opponent.purin_bag.add_evil_purin(level)
	opponent.noir.change_held_purin(opponent.purin_bag.get_current_purin())
	
	
func gain_score(score_amount:int):
	score += score_amount
	update_score_label()

func bonk_purin(purin1: Purin, purin2: Purin):
	# TODO later maybe use the bodys to do something else
	# for now just play audio file
	if not mute_sound:
		sfx_bonk_player.play()
	if is_instance_valid(last_dropped_purin) and (last_dropped_purin == purin1 or last_dropped_purin == purin2):
		last_dropped_purin_touched_something = true

func remove_dead_opponents():
	if opponents.is_empty():
		return
	var updated_opponents:Array[PlayerController] = []
	for opponent in opponents:
		if is_instance_valid(opponent):
			updated_opponents.append(opponent)
	opponents = updated_opponents

func purin_is_moving(purin: Purin) -> bool:
	if not is_instance_valid(purin):
		return false
	
	# Make vertical velocity threshold stricter
	var horizontal_velocity_threshold: float = 2
	var vertical_velocity_threshold: float = 2  # Stricter for vertical movement
	var angular_threshold: float = 0.1
	
	# Check both linear and angular movement
	# Separate horizontal and vertical velocity checks
	var is_moving = (
		abs(purin.linear_velocity.x) > horizontal_velocity_threshold or 
		abs(purin.linear_velocity.y) > vertical_velocity_threshold or
		abs(purin.angular_velocity) > angular_threshold or
		not purin.get_contact_count() > 0
	)
	
	return is_moving

func evaluate_board_value():
	if purin_node.get_child_count() <=0:
		return 0
	var new_board_value:float = 0
	var purin_size_counts:Array[int] = [0,0,0,0,0,0,0,0,0,0]
	var largest_purin_level_on_right:int = -1
	var largest_purin_x:float = 0
	var smallest_purin_level_on_left:int = -1
	var smallest_purin_x:float = 0
	var largest_purin_size:int = 0
	var smallest_purin_size:int = 0
	var noir_position_score:float = 0
	# give rewards for purin being roughly going from small->big on the x-axis and for being closer to the bottom
	for purin in purin_node.get_children():
		var purin_level:int = purin.get_meta("level", 0)
		if purin.position.x + Global.purin_sizes[purin_level] > largest_purin_x:
			largest_purin_x = purin.position.x + Global.purin_sizes[purin_level]
			largest_purin_level_on_right = purin_level
		elif purin.position.x - Global.purin_sizes[purin_level] < smallest_purin_x:
			smallest_purin_x = purin.position.x - Global.purin_sizes[purin_level]
			smallest_purin_level_on_left = purin_level
		if purin_level > largest_purin_size:
			largest_purin_size = purin_level
		elif purin_level < smallest_purin_size:
			smallest_purin_size = purin_level

		purin_size_counts[purin_level] += 1

	new_board_value += noir_position_score
	if noir.held_purin.level >= largest_purin_size-1:
		# have a matching size for the largest available purin
		# should drop on it, so reward being closer
		var noir_target:Vector2 = Vector2(largest_purin_x, 0)
		noir_position_score += (200 - abs(noir_target.distance_to(noir.position)))*2

	# rewards for largest on the right, smallest on the left
	if largest_purin_size == largest_purin_level_on_right:
		new_board_value += pow(largest_purin_size+1, 2)
	if smallest_purin_size == smallest_purin_level_on_left:
		new_board_value += pow(smallest_purin_size+1, 2)

	# reward only having 0 or 1 of each
	for i in range(0, 10):
		if purin_size_counts[i] <= 1:
			new_board_value += (purin_size_counts[i]+1)*pow(i+1, 2)

	return new_board_value

func calculate_board_state_reward():
	# how much score did we get between last action and now
	var score_reward:float = (score - previous_score) * 0.5
	# how much did the board's overall state improve
	var board_value_reward:float = (board_value - previous_board_value) * 0.5
	
	var total_reward:float = score_reward + board_value_reward
#	if total_reward !=0:
#		print("score_reward", score_reward)
#		print("board_value_reward", board_value_reward)
#		print("total_reward", total_reward)
	return total_reward

#func get_board_state():
#	var board_state_vector:Array = []
#	# noir x position
#	board_state_vector.append(min(1,max(0.0001,noir.position.x/800.0)))
#	# score (normalized)
#	board_state_vector.append(min(1,max(0.0001,score/999999.0)))
#	# held purin level (normalized)
#	board_state_vector.append((noir.held_purin.level+1)/10.0)
#	board_state_vector.append((purin_bag.get_next_purin().get("level", 0)+1)/10.0)
#	# for each purin give the level, x, y
#	# first is always what is directly under noir
#	if noir.purin_collide_level >= 0:
#		board_state_vector.append((noir.purin_collide_level+1)/10.0)
#		board_state_vector.append((0.5+(noir.purin_collide_level-noir.held_purin.level)/10.0))
#		board_state_vector.append(min(1,max(0.0001,int(pow(noir.purin_collide_level+2, 2))/999999.0)))
#	# then the rest of them starting from the highest band to lowest
#	for y in range(0, 800, 10):
#		for purin in purin_node.get_children():
#			if is_instance_valid(purin) and purin.position.y >= y and purin.position.y < y + 10:
#				var purin_level:int = purin.get_meta("level", 0)
#				#var target:Vector2 = Vector2(Global.purin_sizes[purin_level], 800-Global.purin_sizes[purin_level])
#				board_state_vector.append((purin_level+1)/10.0)
#				board_state_vector.append(min(1,max(0.0001,purin.position.x/800.0)))
#				board_state_vector.append(min(1,max(0.0001,purin.position.y/800.0)))
#				#board_state_vector.append(min(1,max(0.0001,abs(target.x-purin.position.x)/800.0)))
#				#board_state_vector.append(min(1,max(0.0001,abs(target.x-purin.position.y)/800.0)))
#	# if the vector is not long enough pad it out to INPUT_SIZE with 0s
#	if len(board_state_vector) < Global.INPUT_SIZE:
#		for i in range(len(board_state_vector), Global.INPUT_SIZE):
#			board_state_vector.append(0)
#	if len(board_state_vector) > Global.INPUT_SIZE:
#		board_state_vector = board_state_vector.slice(0, Global.INPUT_SIZE)
#
#	return board_state_vector


func process_ai(delta):
	time_since_last_prediction_sec += delta
	time_since_last_score += delta
	if gameover_screen.visible or not Global.best_brain:
		return
	
	# If we're waiting for action resolution
	if waiting_for_action_resolution:
		# Check if purin has stopped moving or touched something
		if not is_instance_valid(last_dropped_purin) or not purin_is_moving(last_dropped_purin):
			waiting_for_action_resolution = false
			
			# Get current state after action resolved
			var results = eyes.get_inputs_from_raycasts(noir, noir.held_purin.level, purin_bag.get_next_purin_level())
			var current_state_inputs = results[0]
			current_state_inputs.append(noir.position.x/800.0)
			var current_state = Tensor.from_array(PackedFloat32Array(current_state_inputs))
			board_value = evaluate_board_value()
			
			# Calculate reward based on the action's outcome
			var reward = calculate_board_state_reward()
			
			
			# Store experience only if we have a previous state
			if previous_state != null and previous_action != -1:
				Global.add_experience({
					"state": previous_state,
					"action": previous_action,
					"reward": reward,
					"next_state": current_state,
					"done": gameover_screen.visible
				})
				# Train on batch if enough steps have passed
				if Global.steps_since_training >= Global.training_interval:
					train_on_batch()
					#Global.experience_buffer.clear()

	# Only take new action if we're not waiting for resolution and enough time has passed
	elif time_since_last_prediction_sec >= predict_every_sec:
		# Get current state
		var results = eyes.get_inputs_from_raycasts(noir, noir.held_purin.level, purin_bag.get_next_purin_level())
		var state_inputs = results[0]
		state_inputs.append(noir.position.x/800.0)
		var state = Tensor.from_array(PackedFloat32Array(state_inputs))
		
			# Store current state and score before action
		previous_state = state
		previous_score = score
		previous_board_value = board_value
		
		# Get action from policy
		var action = Global.best_brain.select_action(state.data)
		previous_action = action
		
		# Execute action
#		if action == 0:
#			noir.position.x = valid_x_pos(noir.position.x - (move_speed*delta))
#		elif time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec and action == 1:
#			drop_purin()
#		elif action == 2:
#			noir.position.x = valid_x_pos(noir.position.x + (move_speed*delta))
		noir.position.x = valid_x_pos(action)
		# allow it to do nothing/wait by using the 0th action
		if action > 0:
			drop_purin()
			# Start waiting for action resolution
		waiting_for_action_resolution = true
		time_since_last_prediction_sec = 0

func is_bad_state(game:PlayerController) -> bool:
	# if they have a lot of the same purin size then it's not optimal enough
	if game.purin_node.get_child_count() <=0:
		return false
	
	var purin_size_counts:Array[int] = [0,0,0,0,0,0,0,0,0,0]
	for purin in game.purin_node.get_children():
		var purin_level:int = purin.get_meta("level", 0)
		purin_size_counts[purin_level] += 1
		if purin.position.y < 0 :
			return true
	
	for i in range(0, purin_size_counts.size()):
		if purin_size_counts[i] >= 6:
			return true
	return false

func calculate_reward(old_score: int) -> float:
	var reward = 0.0
	if gameover_screen.visible:
		reward = -9999
	# Score-based reward
	reward += (score - old_score) * 0.1
	
	# Height penalty - discourage stacking too high
	var lowest_y:float = 900
	for purin in purin_node.get_children():
		if purin.position.y < lowest_y:
			lowest_y = purin.position.y
	reward -= (800-lowest_y)*0.1
	
	# Combo reward
	if last_dropped_purin_touched_something:
		reward += 0.5
	
	return reward

func train_on_batch():
	print("Experience buffer size: ", Global.experience_pool.get_buffer_size())
	
	# Ensure we have enough experiences
	if Global.experience_pool.get_buffer_size() < Global.batch_size:
		print("not enough experiences in buffer")
		return
	var batch_size:int = min(Global.batch_size, Global.experience_pool.get_buffer_size())
	print("Training on batch of size: ", batch_size)
	# Sample random experiences from buffer
	var batch = Global.experience_pool.sample_batch(batch_size)
	
	# Prepare batch tensors
	var states_data = PackedFloat32Array()
	var actions_data = PackedFloat32Array()
	var rewards_data = PackedFloat32Array()
	var next_states_data = PackedFloat32Array()
	var dones_data = PackedFloat32Array()
	
	# Collect batch data
	for experience in batch:
		# Each state has input_nodes elements
		for i in range(input_nodes):
			if i < experience["state"].data.size():
				states_data.append(experience["state"].data[i])
			else:
				states_data.append(0.0)
				
		actions_data.append(experience["action"])
		rewards_data.append(experience["reward"])
		
		# Each next_state has input_nodes elements
		for i in range(input_nodes):
			if i < experience["next_state"].data.size():
				next_states_data.append(experience["next_state"].data[i])
			else:
				next_states_data.append(0.0)
				
		dones_data.append(1.0 if experience["done"] else 0.0)
	
	# Create tensors from batch data
	var states_tensor = Tensor.from_array(states_data)
	var actions_tensor = Tensor.from_array(actions_data)
	var rewards_tensor = Tensor.from_array(rewards_data)
	var next_states_tensor = Tensor.from_array(next_states_data)
	var dones_tensor = Tensor.from_array(dones_data)
	# save current best brain
	Global.best_brain.save_model(Global.ai_brain_path)
	# load it as a new brain to avoid conflicts
	var new_brain:PPO = PPO.new(124, Global.BRAIN_HIDDEN_LAYERS, Global.OUTPUT_NODES)
	new_brain.load_model(Global.ai_brain_path)
	# Train on batch
	var training_data = {
		"states": states_tensor,
		"actions": actions_tensor,
		"rewards": rewards_tensor,
		"next_states": next_states_tensor,
		"dones": dones_tensor,
		"ppo": new_brain,
	}
	
	Global.async_trainer.enqueue_training(training_data)
	Global.steps_since_training = 0
