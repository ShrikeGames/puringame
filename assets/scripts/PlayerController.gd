extends Node2D
class_name PlayerController
signal gameover
# random number generator seed
var initial_seed: String

@export_category("Configs")
@export var player_name: String = "player"
@export var config_path: String = "user://player.json"
@export var default_config_path: String = "res://default.json"

@export var ai_controlled: bool = false
@export var vs_player: bool = false
@export var debug: bool = false

@export_category("Brain")
@export var eyes:Eyes
@export var fov_degrees: float = 30
# how many raycasts are done within the fov
@export var num_raycasts: int = 30
# distance raycasts will travel to look for collisions
@export var sight: float = 900
@export var predict_every_sec: float = 0.20
@export var random_initial_board_state: bool = false
var total_rewards:float = 0

var time_since_last_prediction_sec: float = 0
var time_since_last_score: float = 0

@export_category("References")
@export var leaderboard: Leaderboard
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
@export var last_mouse_pos: Vector2 = Vector2(0.0, 0.0)
@export var max_score_history_length: int = 10

var can_drop_early: bool = false
var auto_drop: bool = false
var config_json: Dictionary
var default_config_json: Dictionary

var score: int = 0
var dropped_purin_count: int = 0
var last_dropped_purin: Purin = null
var last_dropped_purin_touched_something: bool = false

var time_since_last_dropped_purin_sec: float = 0
var drop_purin_cooldown_sec: float = 0.25
var previous_highest_prediction_index: int = 0

var skip_saving: bool = false
var training: bool = true

var board_value: float = 0
var previous_board_value: float = 0
var previous_state: Array = []
var previous_action: int = -1
var previous_previous_action: int = -1
var previous_score: int = 0
var waiting_for_action_resolution: bool = false
var previous_purin_count: int = 0
var previous_purin_level: int = 0
var reward_mean: float = 0
var reward_std: float = 0
var highest_achieved_purin_level: int = 0
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
	
func get_configurations(key: String, default_default_value = {}, random: bool = true, config_index: int = 0):
	var config_value = {}
	var default_value = default_default_value
	var default_history_run: Dictionary
	if random:
		default_history_run = default_config_json.get("history", [ {}]).pick_random()
	else:
		default_history_run = default_config_json.get("history", [ {}])[min(config_index, len(default_config_json.get("history", [ {}])) - 1)]
	
	if default_history_run.has(key):
		default_value = default_history_run.get(key)
	
	var config_history_run: Dictionary
	if random:
		config_history_run = config_json.get("history", [ {}]).pick_random()
	else:
		config_history_run = config_json.get("history", [ {}])[min(config_index, len(config_json.get("history", [ {}])) - 1)]
	
	if config_history_run.has(key):
		config_value = config_history_run.get(key, default_value)
	else:
		config_value = default_value
	
	return config_value

func restart_game():
	emit_signal("gameover", player_name, score, total_rewards)
	print("Restart game for ", player_name, " who had score of ", score, " and rewards of ", total_rewards)
	set_up_game()
	gameover_screen.visible = false

func set_up_game():
	# clear the game of any dropped purin
	remove_all_purin()
	# reset progress
	score = 0
	board_value = 0
	reward_mean = 0
	reward_std = 0
	time_since_last_score = 0
	previous_state = []
	previous_action = -1
	previous_previous_action = -1
	previous_score = 0
	previous_purin_count = 0
	previous_board_value = 0
	previous_purin_level = 0
	total_rewards = 0
	highest_achieved_purin_level=0
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
		#if not noir.eyes.initialized:
		#	noir.eyes.init(fov_degrees, num_raycasts, sight)
		if not eyes.initialized:
			eyes.init(fov_degrees, num_raycasts, sight)
		if random_initial_board_state:
			noir.position.x = randi_range(20, 780)
			# spawn a purin in a random spot for training
			spawn_purin(Vector2(randf_range(20,780), 780), {"level": 0, "evil": false})
			spawn_purin(Vector2(randf_range(20,780), 780), {"level": 1, "evil": false})
			#last_dropped_purin = purin_node.get_child(0)
		else:
			noir.position.x = 400
		
		if not Global.best_brain:
			Global.best_brain = PPO.new(Global.INPUT_NODES, Global.BRAIN_HIDDEN_LAYERS, Global.OUTPUT_NODES)
		
	
func remove_all_purin():
	for purin in purin_node.get_children():
		purin.queue_free()
		
func update_score_label():
	if score_label != null:
		score_label.text = "[center]%s[/center]" % [score]

func rank_history(run1: Dictionary, run2: Dictionary):
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
	var history: Array = config_json.get("history", [])
	
	# only save the last 10 after sorting
	config_json["history"] = history.slice(0, min(max_score_history_length + 1, len(history)))
	
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
			print("GameOver %s" % [score])
#			Global.add_experience({
#				"state": previous_state,
#				"action": previous_action,
#				"reward": -10,
#				"next_state": calculate_inputs(),
#				"done": true
#			})
			if training:
				restart_game()
				return
			
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
			if purin.position.y + purin.get_meta("radius") < 0:
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
	var just_pressed: bool = Input.is_action_just_pressed("drop_purin")
	var just_released: bool = Input.is_action_just_released("drop_purin")
	
	# accessibility setting will cause you to always drop until toggled off
	if just_released and Global.drop_troggle:
		# toggle between auto drop on or off
		auto_drop = not auto_drop
	if (
		(just_pressed and time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec)
		or (Global.drop_troggle and auto_drop and time_since_last_dropped_purin_sec >= max(drop_purin_cooldown_sec, Global.auto_drop_cooldown_sec))
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
		noir.position.x = valid_x_pos(noir.position.x - (move_speed * delta))
	elif Input.is_action_pressed("move_right"):
		Global.active_controls = "not_mouse"
		noir.position.x = valid_x_pos(noir.position.x + (move_speed * delta))
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
	purin.particle_system.scale = Vector2(2 + level, 2 + level)
	purin.particle_system.process_material.emission_sphere_radius = new_radius * 0.5
	
	# if it's an evil purin then make that visible
	if evil and not training:
		purin.evil = true
		# if it's evil then make have more mass than normal
		purin.mass = pow(1.4, level + 2)
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

func score_by_level(level: int):
	#return int(pow(level+1, 3))
	return int(pow(level + 1, 2)) * int(1 + (dropped_purin_count * 0.1))

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
	if new_level > highest_achieved_purin_level:
		highest_achieved_purin_level = new_level
	
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
			new_purin.mass = pow(1.2, new_level + 2)
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
	if training:
		# training just get the score instantly don't do the orb thing
		gain_score(score_increase)
		time_since_last_score = 0
	else:
		var scoreorb: ScoreOrb = Global.score_orb_scene.instantiate()
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
	
	
func gain_score(score_amount: int):
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
	var updated_opponents: Array[PlayerController] = []
	for opponent in opponents:
		if is_instance_valid(opponent):
			updated_opponents.append(opponent)
	opponents = updated_opponents

func purin_is_moving(purin: Purin) -> bool:
	if not is_instance_valid(purin):
		return false
	
	# Make vertical velocity threshold stricter
	var horizontal_velocity_threshold: float = 2
	var vertical_velocity_threshold: float = 2 # Stricter for vertical movement
	var angular_threshold: float = 0.1
	
	# Check both linear and angular movement
	# Separate horizontal and vertical velocity checks
	var is_moving = (
		is_instance_valid(purin) and (
		abs(purin.linear_velocity.x) > horizontal_velocity_threshold or
		abs(purin.linear_velocity.y) > vertical_velocity_threshold or
		abs(purin.angular_velocity) > angular_threshold or
		not purin.get_contact_count() > 0)
	)
	
	return is_moving

func calculate_inputs(x:float=-1) -> Array[float]:
	if x < 0:
		x = noir.position.x
	var inputs: Array[float] = []
	
	# 1
	# Noir (player) position normalized (0-1)
	var noir_pos_normalized = clampf((x - left_edge.position.x) / (right_edge.position.x - left_edge.position.x), 0.0, 1.0)
	inputs.append(noir_pos_normalized)

	# 2
	# can drop purin
	#if time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec or not is_instance_valid(last_dropped_purin):
	#	inputs.append(1.0)
	#else:
	#	inputs.append(0.0)
	
	
	# Current and next purin level normalized (0-1)
	#var current_level_normalized = clampf(float(noir.held_purin.level + 1) / (Global.highest_possible_purin_level + 1), 0.0, 1.0)
	#var next_level_normalized = clampf(float(purin_bag.get_next_purin_level() + 1) / (Global.highest_possible_purin_level + 1), 0.0, 1.0)
	# 3
	#inputs.append(current_level_normalized)
	# 4
	#inputs.append(next_level_normalized)

	
	# 5. Board state information
	var all_purin = purin_node.get_children()
	
	# 6
	inputs.append(clampf(noir.purin_collide_position.y/800.0, 0.0, 1.0))
	# 7
	#inputs.append(clampf((noir.purin_collide_level+1)/10.0, 0.0, 1.0))
	#var level_diff_score:float = clampf(exp(-pow(noir.held_purin.level-noir.purin_collide_level, 2)/25.0), 0.0, 1.0)
	var level_diff_score = 0
	if noir.held_purin.level==noir.purin_collide_level:
		level_diff_score = 1
	# 8
	inputs.append(level_diff_score)
	
	# (num rays+1) * 3= 6*3 = 18
	#var eyes_inputs:Array = noir.eyes.get_inputs_from_raycasts(noir.held_purin.level, purin_bag.get_next_purin_level(), left_edge, right_edge)
	var eyes_inputs:Array = eyes.get_inputs_from_raycasts(noir.held_purin.level, purin_bag.get_next_purin_level(), left_edge, right_edge)
	
	inputs.append_array(eyes_inputs)
	
	# Add global state information
	# Total purin count normalized (assuming max 60 purin)
	# 9
	inputs.append(clampf(float(all_purin.size()) / 60.0, 0.0, 1.0))
	
	# 10
	# Current score normalized (assuming max score 500000)
	inputs.append(clampf(float(score) / 500000.0, 0.0, 1.0))
	
	# Check if any purin is in danger zone and calculate how close to game over we are
	var max_danger = 0.0
	for purin in all_purin:
		if not is_instance_valid(purin):
			continue
		
		if purin.position.y - purin.get_meta("radius") < top_edge.position.y:
			# Calculate danger value based on game over timer
			# Normalize between 0 and game over threshold
			var danger = clampf(purin.game_over_timer_sec / Global.game_over_threshold_sec, 0.0, 1.0)
			# If purin is completely off screen, max danger
			if purin.position.y + purin.get_meta("radius") < 0:
				danger = 1.0
			max_danger = max(max_danger, danger)
	# 11
	inputs.append(max_danger)
	return inputs

func early_termination():
	# not merging well enough
#	var total_purin:int = purin_node.get_child_count()
#	if highest_achieved_purin_level == 4 and total_purin > 9:
#		return true
#	if highest_achieved_purin_level == 5 and total_purin > 10:
#		return true
#	if highest_achieved_purin_level == 6 and total_purin > 11:
#		return true
#	if highest_achieved_purin_level == 7 and total_purin > 12:
#		return true
	
	return false

func process_ai(delta):
	time_since_last_prediction_sec += delta
	time_since_last_score += delta
	if gameover_screen.visible or not Global.best_brain:
		return
	
	if early_termination():
#		Global.add_experience({
#			"state": previous_state,
#			"action": previous_action,
#			"reward": -10,
#			"next_state": calculate_inputs(),
#			"done": true
#		})
		gameover_screen.visible = true
		return
	
	# If we're waiting for action resolution
	if waiting_for_action_resolution:
		if not is_instance_valid(last_dropped_purin) or not purin_is_moving(last_dropped_purin) or time_since_last_dropped_purin_sec > drop_purin_cooldown_sec * 10:
			waiting_for_action_resolution = false
			
			# Get current state after action resolved
			#var results = 
			var current_state_inputs: Array[float] = calculate_inputs()
			
			# Calculate reward based on the action's outcome
			#var reward = calculate_board_state_reward()
			var reward = calculate_reward(previous_score, score, previous_state, current_state_inputs, previous_previous_action, previous_action, Global.purin_sizes, 60)
			total_rewards += reward
			
			# Store experience only if we have a previous state and it was a purin drop
			if previous_state != null and previous_action == 1:
				Global.add_experience({
					"state": previous_state,
					"action": previous_action,
					"reward": reward,
					"next_state": current_state_inputs,
					"done": false
				})

	# Only take new action if we're not waiting for resolution and enough time has passed
	elif time_since_last_prediction_sec >= predict_every_sec:
		# Execute action
	
		# Get current state
		var state_inputs: Array[float] = calculate_inputs()
		
		# Store current state and score before action
		previous_state = state_inputs
		previous_score = score
		previous_purin_count = purin_node.get_child_count()
		previous_board_value = board_value
		previous_purin_level = noir.held_purin.level
		# Get action from policy
		var temperature = 1
		var result = Global.best_brain.select_action(state_inputs, temperature)
		var action = result[0]
		var probs = result[1]
		debug_label.text = "%s -> %s\nTotal Rewards: %s\n%s"%[probs, action, total_rewards, state_inputs]
		
		previous_previous_action = previous_action
		previous_action = action
		if Global.OUTPUT_NODES == 3:
			if action == 0:
				noir.position.x = valid_x_pos(noir.position.x - (move_speed * delta))
			elif time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec and action == 1:
				drop_purin()
			elif action == 2:
				noir.position.x = valid_x_pos(noir.position.x + (move_speed * delta))
		elif Global.OUTPUT_NODES == 5:
			if action == 0:
				noir.position.x = valid_x_pos(noir.position.x - (move_speed * delta))
			elif time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec and action == 1:
				drop_purin()
			elif action == 2:
				noir.position.x = valid_x_pos(noir.position.x + (move_speed * delta))
			elif action == 3:
				noir.position.x = valid_x_pos(noir.position.x - (3 * move_speed * delta))
			elif action == 4:
				noir.position.x = valid_x_pos(noir.position.x + (3 * move_speed * delta))
			
		else:
			noir.position.x = valid_x_pos(action)
			drop_purin()
		
		# Start waiting for action resolution
		waiting_for_action_resolution = true
		time_since_last_prediction_sec = 0

func is_bad_state(game: PlayerController) -> bool:
	# if they have a lot of the same purin size then it's not optimal enough
	if game.purin_node.get_child_count() <= 0:
		return false
	
	var purin_size_counts: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	for purin in game.purin_node.get_children():
		var purin_level: int = purin.get_meta("level", 0)
		purin_size_counts[purin_level] += 1
		if purin.position.y < 0:
			return true
	
	for i in range(0, purin_size_counts.size()):
		if purin_size_counts[i] >= 6:
			return true
	return false

func calculate_reward(p_previous_score: float, p_current_score: float, _previous_board_state: Array, _current_board_state: Array, previous_action:int, current_action: int, _purin_sizes: Array, max_purin_count: int) -> float:
	var reward: float = 0.0
	
	# 1. Score Increase Reward
	var score_increase: float = p_current_score - p_previous_score
	if score_increase> 0:
		reward += 20 * (previous_purin_level+1)
	
	# 2. Purin Combo Reward
#	var combo_reward: float = 0.0
#	for purin in purin_node.get_children():
#		if purin.get_meta("combined", false):  # Assuming purin has a flag for just combined
#			var level: int = purin.level
#			combo_reward += pow(level + 1, 2)  # Reward larger combos more
#	reward += combo_reward * 0.2  # Scale combo reward
#
	# 3. could've merged but didn't
	if previous_action == 1 and _previous_board_state[2] == 1 and previous_purin_count < purin_node.get_child_count():
		reward -= 50 * (previous_purin_level+1)
	
	# 5. Penalize Invalid Actions
#	if not is_valid_action(current_action):
#		reward -= 20.0  # Heavy penalty for invalid actions
	
	# exploration reward but only if you keep going in the direction you were going
#	if previous_action != 1:
#		# 0 left, 1 drop, 2 right, 3 big left, 4 big right
#		if (previous_action == 0 or previous_action == 3 ) and (current_action == 0 or current_action == 3 ):
#			reward += 1
#		elif (previous_action == 2 or previous_action == 4 ) and (current_action == 2 or current_action == 4 ):
#			reward += 1
#		else:
#			reward -= 2
	if previous_action != 1:
		reward +=1

	return reward

func is_valid_action(action: int) -> bool:
	# Check if the action is valid (e.g., not dropping outside the box)
	if action == 0 and noir.position.x > left_edge.position.x + 20:
		return true
	if action == 2 and noir.position.x < right_edge.position.x - 20:
		return true
	if action == 3 and noir.position.x > left_edge.position.x + 20:
		return true
	if action == 4 and noir.position.x < right_edge.position.x- 20:
		return true
	if action == 1:
		# we are only letting it predict when it's allowed to do this right now
		return true
		
	return false
	
# Helper Functions
func get_held_purin_level() -> int:
	# Return the level of the currently held purin
	return noir.held_purin.level

func get_collision_info() -> Dictionary:
	# Return information about where the purin landed (e.g., level of collided purin)
	return {}

func get_max_purin_level() -> int:
	# Return the highest level of purin on the board
	var max_level: int = 0
	for purin in purin_node.get_children():
		if purin.get_meta("level") > max_level:
			max_level = purin.get_meta("level")
	return max_level

func is_purin_covered(purin: Purin, all_purin: Array) -> bool:
	# Purin properties
	var purin_x: float = purin.position.x
	var purin_y: float = purin.position.y
	var purin_radius: float = purin.get_meta("radius")

	# Sort purin by y position (ascending order)
	all_purin.sort_custom(func(a, b): return a.position.y < b.position.y)

	# Check all purin above this one
	for other_purin in all_purin:
		if other_purin == purin:
			continue  # Skip the same purin

		var other_x: float = other_purin.position.x
		var other_y: float = other_purin.position.y
		var other_radius: float = other_purin.get_meta("radius")

		# Stop checking if the other purin is below this one
		if other_y > purin_y:
			break

		# Check if the horizontal positions overlap
		var x_distance: float = abs(other_x - purin_x)
		var max_x_distance: float = other_radius + purin_radius

		if x_distance < max_x_distance:
			# The other purin is above and overlapping horizontally
			return true

	# No purin is covering this one
	return false
