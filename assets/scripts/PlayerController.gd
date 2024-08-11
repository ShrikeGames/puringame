extends Node2D
class_name PlayerController
# random number generator seed
var initial_seed:String

@export var player_name: String = "player"
@export var config_path: String = "user://player.json"
@export var default_config_path: String = "res://default.json"
@export var ai_controlled: bool = false
@export var auto_retry: bool = false
@export var neural_training: bool = false
@export var max_retry_attempts: int = 999
var attempts:int = 0
@export var leaderboard:Leaderboard
var ai_controller: AIController
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
@export var sfx_pop_player: AudioStreamPlayer
@export var sfx_bonk_player: AudioStreamPlayer
@export var mute_sound: bool = false
@export var opponents: Array[PlayerController] = []
@export var gameover_screen: Node2D
@export var player_label: RichTextLabel
@export var debug_label: RichTextLabel
@export var score_label: RichTextLabel
@export var ai_inputs_object: Node2D
@export var ai_mutation_rate: float
@export var training: bool = false
@export var move_speed: float = 450.0
@export var last_mouse_pos:Vector2 = Vector2(0.0, 0.0)
@export var max_score_history_length:int = 10
var weight_proportions:Array[float]=[]
var mvp_weight:int = 0
var can_drop_early: bool =false
var auto_drop:bool = false
var target_score:float = 150000
@export var debug:bool = false
var rank: int = 0

var source_network:NeuralNetworkAdvanced

var config_json:Dictionary
var default_config_json:Dictionary

var score: int = 0

var dropped_purin_count: int = 0
var last_dropped_purin:Purin
var last_dropped_purin_touched_something:bool = false

var time_since_last_dropped_purin_sec: float = 0
var drop_purin_cooldown_sec: float = 2

var skip_saving:bool = false
func _on_ready():
	# set game speed
	if not ai_controlled:
		Engine.time_scale = Global.game_speed
	if not training:
		init()


func init():
	load_configs()
	if prediction_icon:
		prediction_icon.visible = neural_training
	if not training:
		# set up the game, can be called to restart at anytime
		set_up_game()

func load_configs():
	config_json = Global.read_json(config_path)
	default_config_json = Global.read_json(default_config_path)
	if config_json == null:
		config_json = default_config_json
	
func get_configurations_with_mutation(key: String, mutation_rate: float = 0.0, default_default_value = {}, random:bool=true, config_index:int=0):
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
	
	if mutation_rate != 0.0:
		config_value["weights"] = mutate_array(config_value["weights"], mutation_rate)
	return config_value

func mutate_array(list_floats:Array, mutation_rate:float):
	var mutated_list:Array[float] = []
	# should be an array so loop through each weight/bias
	for i in range(0, len(list_floats)):
		# individually give it a mutation chance
		if randf() <= mutation_rate:
			mutated_list.append(list_floats[i] + randf_range(-4,4))
		else:
			mutated_list.append(list_floats[i])
		mutated_list[i] = min(mutated_list[i], 16)
		mutated_list[i] = max(0, mutated_list[i])
		mutated_list[i] = snapped(mutated_list[i], 0.2)
	return mutated_list

func get_config_value_or_default(key: String, mutation_rate: float = 0.0, default_default_value = 0):
	var config_value = 0
	var default_value = default_default_value
	
	if default_config_json.has(key):
		default_value = default_config_json.get(key)
	if config_json != null and config_json.has(key):
		config_value = config_json.get(key, default_value)
	else:
		config_value = default_value
	if mutation_rate != 0.0:
		# should be an array so loop through each weight/bias
		for i in range(0, len(config_value)):
			# individually give it a mutation chance
			if randf() <= mutation_rate:
				config_value[i] += randf_range(-4,4)
			config_value[i] = min(config_value[i], 16)
			config_value[i] = max(0, config_value[i])
			config_value[i] = snapped(config_value[i], 0.2)
	return config_value


func restart_game():
	attempts += 1
	
	if training and purin_bag:
		purin_bag.queue_free()
		purin_bag = null
	if ai_controller:
		ai_controller.queue_free()
	if auto_retry and attempts > max_retry_attempts:
		self.queue_free()
		return
	set_up_game()
	
func set_up_game():
	# clear the game of any dropped purin
	remove_all_purin()
	# reset progress
	score = 0
	dropped_purin_count = 0
	if ai_controlled:
		drop_purin_cooldown_sec= 2.5
	else:
		drop_purin_cooldown_sec = 0.25
	time_since_last_dropped_purin_sec = drop_purin_cooldown_sec
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
	# if this is an AI player then create an AIController for it
	if ai_controlled:
		ai_controller = AIController.new()
		self.add_child(ai_controller)
		ai_controller.init(self)
	
	player_label.text = player_name
	update_score_label()

	gameover_screen.visible = false
	debug_label.visible = debug
	
	if neural_training and not neural_training:
		source_network = Global.load_ml()
	
	# for testing
	#spawn_purin(Vector2(350,400),{"level": 2, "evil": false})
	#spawn_purin(Vector2(300,400),{"level": 3, "evil": false})
	#spawn_purin(Vector2(200,400),{"level": 4, "evil": false})


func remove_all_purin():
	for purin in purin_node.get_children():
		purin.queue_free()
		
func update_score_label():
	if score_label != null:
		score_label.text = "[center]%s[/center]" % [score]

func get_state():
	
	var state:Array[float] = []
	state.append(purin_bag.get_current_purin()["level"]/float(Global.highest_possible_purin_level))
	state.append(purin_bag.get_next_purin()["level"]/float(Global.highest_possible_purin_level))
	# 64 purin * 3 each = 192 + 2 = 194 total size
	for purin in purin_node.get_children():
		state.append(purin.position.x/800.0)
		state.append(purin.position.y/800.0)
		state.append(purin.get_meta("level")/float(Global.highest_possible_purin_level))
	if len(state) < 194:
		for i in range(len(state), 195):
			state.append(0)
	
	return state.slice(0, min(195, len(state)))
	
func get_board_state():
	var state: Dictionary = {"purin":[]}
	var purin_list:Array[Dictionary] = []
	for purin in purin_node.get_children():
		var purin_level = purin.get_meta("level")
		var purin_info:Dictionary = {
			"level": purin_level,
			"x": purin.position.x,
			"y": purin.position.y,
			"evil": purin.evil
		}
		purin_list.append(purin_info)
	state["purin"] = purin_list
	return state

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
	# get latest copies of the configs before updating them
	config_json = Global.read_json(config_path)
	default_config_json = Global.read_json(default_config_path)
	if config_json == null:
		config_json = default_config_json
	if config_json == null:
		print("No config_json was loaded? ", config_path)
		return
	# update config
	var history:Array = config_json.get("history", [])
	var new_run:Dictionary = {
		"score": score,
		"board_state": get_board_state(),
	}
	if ai_controlled:
		new_run["configurations"] = ai_controller.configurations
		new_run["configurations"]["attempts"] = attempts
		new_run["configurations"]["username"] = player_name
		new_run["configurations"]["username_jp"] = player_name
		new_run["configurations"]["parent1"] = ai_controller.parent_1_name
		new_run["configurations"]["parent2"] = ai_controller.parent_2_name
		new_run["configurations"]["score"] = score
		
		new_run["configurations"]["weight_proportions"] = weight_proportions
		new_run["configurations"]["mvp_weight"] = mvp_weight
		new_run["configurations"]["replay"] = ai_controller.move_history
	
	history.append(new_run)
	
	# sort history from best to worst
	history.sort_custom(rank_history)
	if training:
		#  keep all
		config_json["history"] = history#.slice(0, min(40, len(history)))
	else:
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
	if ai_controlled:
		if is_instance_valid(ai_controller):
			ai_controller.process_ai(delta)
	else:
		process_player(delta)


func check_game_over(delta):
	if gameover_screen.visible == true:
		
		if Input.is_action_pressed("retry") or (ai_controlled and auto_retry):
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
			return false
		if ai_controlled and not auto_retry and training:
			#print("Delete AI player ", player_name, " because they lost, are not set to auto retry and are in training")
			#print("%s Game Over with a score of %s" % [player_name, score])
			save_results()
			self.queue_free()
		return true

	for purin in purin_node.get_children():
		if not is_instance_of(purin, Purin):
			continue
		# if the purin's game over time reaches the threshold you lose
		if ( 
			purin.game_over_timer_sec >= Global.game_over_threshold_sec
		):
			if ai_controlled:
				var weight_total:float = 0
				var highest_weight:float = 0
				
				var weights:Array = ai_controller.configurations.get("weights")
				for i in range(0, 6):
					weight_total += weights[i]
					if weights[i] > highest_weight:
						highest_weight = weights[i]
						mvp_weight = i
						
				for weight in weights:
					if weight_total> 0:
						weight_proportions.append(weight/weight_total)
					else:
						weight_proportions.append(0)
				var parents = "(%s+%s)"%[ai_controller.parent_1_name, ai_controller.parent_2_name]
					
				if training and source_network:
					# tell it the state when we lost
					var actuals = [int(noir.position.x)/800.0]
					source_network.train(get_state(), actuals)
				
				print("GameOver / %s %s / %s / %s / %s / %s / %s" % [player_name, parents, score, purin_bag.max_purin_level, dropped_purin_count, purin_node.get_child_count(), ai_controller.configurations["weights"]])
			
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
	if ai_controlled and training and terminate_training_early():
		var parents = "(%s+%s)"%[ai_controller.parent_1_name, ai_controller.parent_2_name]
		print("Performance / %s %s / %s / %s / %s / %s / %s" % [player_name, parents, score, purin_bag.max_purin_level, dropped_purin_count, purin_node.get_child_count(), ai_controller.configurations["weights"]])
		gameover_screen.visible = true
		#skip_saving = true
		return true
	return false

func mean_squared_error(actual, predicted):
	var sum_square_error = 0.0
	for i in range(len(actual)):
		sum_square_error += (actual[i] - predicted[i])**2.0
	var mean_square_error = 1.0 / len(actual) * sum_square_error
	return mean_square_error
	
func terminate_training_early():
	# Selection Pressure Rules
	# var current_purin_count:int = purin_node.get_child_count()
	# kill those with excessive purin that aren't combined
#	if is_instance_valid(purin_bag) and purin_bag.max_purin_level < 9 and current_purin_count > 20:
#		return true
	
	# semi optimal merging should get close to these scores with some wiggle room
#	if purin_bag.max_purin_level < 5 and score >= 1500:
#		return true
#	if purin_bag.max_purin_level < 6 and score >= 4000:
#		return true
#	if purin_bag.max_purin_level < 7 and score >= 12000:
#		return true
#	if purin_bag.max_purin_level < 8 and score >= 35000:
#		return true
#	# more wiggle room for higher tier purin
#	if purin_bag.max_purin_level < 9 and score >= 65000:
#		return true
#
	
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
		
		if neural_training and source_network:
			var actuals = [int(noir.position.x)/800.0]
			# get state of the game before anything is done
			var input = get_state()
			# tell it to predict to see what it's already learned if anything
			var predictions = source_network.predict(input)
			
			if prediction_icon:
				prediction_icon.position.x = predictions[0]*800
			
			#game.noir.position.x = predictions[0]
			# show us how close it was
			self.debug_label.text = "[Prediction] %s vs %s. MSE: %s"%[predictions, actuals, mean_squared_error(actuals, predictions)]
		
	
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
	if evil:
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
	return int(pow(level+1, 3))

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
		new_purin.evil = evil
		
		if evil:
			# if it's evil then make have more mass than normal
			new_purin.mass = pow(1.2, new_level+2)
		elif not opponents.is_empty() and new_level >= Global.evil_purin_spawn_level_threshold:
			remove_dead_opponents()
			if not opponents.is_empty():
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
		if not training:
			new_purin.particle_system.emitting = true
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
		gain_score(score_increase)
	else:
		var scoreorb:ScoreOrb = Global.score_orb_scene.instantiate()
		scoreorb.score_worth = score_increase
		scoreorb.position = Vector2(spawn_x, spawn_y)
		scoreorb.target_position = scoreorb_target.position
		scoreorb_node.add_child(scoreorb)
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

