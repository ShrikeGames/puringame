extends Node2D
class_name PlayerController

@export var player_name: String = "player"
@export var config_path: String = "user://player.json"
var default_config_path: String = "res://default.json"
@export var ai_controlled: bool = false
@export var auto_retry: bool = false
var ai_controller: AIController
@export var noir: NoiR
@export var next_purin_indicator: Sprite2D
@export var top_edge: Node2D
@export var left_edge: Node2D
@export var right_edge: Node2D
@export var bottom_edge: Node2D
@export var purin_node: Node2D
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
var rank: int = 0

var config_json
var default_config_json

var score: int = 0
var highscore: int = 0

var purin_object: Resource = load("res://assets/scenes/Purin.tscn")
var purin_textures: Array[Texture2D] = []
var purin_sizes: Array = [50, 100, 125, 156, 175, 195, 220, 250, 275, 300, 343]
var highest_possible_purin_level: int
const purin_file_path_root = "res://assets/images/"
var purin_bag: PurinBag
var highest_tier_purin_dropped: int = 0
var dropped_purin_count: int = 0

var evil_purin_spawn_level_threshold: float = 4
var evil_purin_spawn_level_divider: float = 3

var time_since_last_dropped_purin_sec: float = 0
var drop_purin_cooldown_sec: float = 0.5

var game_over_threshold_sec: float = 3


func _on_ready():
	print(player_name, " on ready")
	# first time load the purin images/textures
	load_purin()
	if not training:
		init()


func init():
	print(player_name, " init")
	load_configs()
	if not training:
		# set up the game, can be called to restart at anytime
		set_up_game()

func read_json(path:String):
	if not FileAccess.file_exists(path):
		return null
	var json_string = FileAccess.get_file_as_string(path)
	var json_dict = JSON.parse_string(json_string)

	return json_dict
	
func load_configs():
	print("load configs from ", config_path)
	config_json = read_json(config_path)
	print("config_json:", config_json)
	default_config_json = read_json(default_config_path)
	if config_json == null:
		config_json = default_config_json
	# get values from config file (player's save, or from default config)
	#purin_sizes = get_config_value_or_default("purin_sizes")
	print("purin_sizes:", purin_sizes)
	highest_possible_purin_level = get_config_value_or_default("highest_possible_purin_level", 0, 10)
	print("highest_possible_purin_level:", highest_possible_purin_level)
	game_over_threshold_sec = get_config_value_or_default("game_over_threshold_sec", 0, 6)
	print("game_over_threshold_sec:", game_over_threshold_sec)
	var hacky_workaround = 0.25
	if player_name != "player":
		hacky_workaround = 1.25
	drop_purin_cooldown_sec = get_config_value_or_default("drop_purin_cooldown_sec", 0, hacky_workaround)
	print("drop_purin_cooldown_sec:", drop_purin_cooldown_sec)
	evil_purin_spawn_level_threshold = get_config_value_or_default(
		"evil_purin_spawn_level_threshold", 0, 3
	)
	print("evil_purin_spawn_level_threshold:", evil_purin_spawn_level_threshold)
	evil_purin_spawn_level_divider = get_config_value_or_default("evil_purin_spawn_level_divider", 0, 4)
	print("evil_purin_spawn_level_divider:", evil_purin_spawn_level_divider)
	highscore = get_config_value_or_default("highscore", 0, 0)
	print("highscore:", highscore)
	#default_config.save(default_config_path)

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
				config_value[i] += randf_range(-1.0, 1.0)
				config_value[i] = min(config_value[i], 8.0)
				config_value[i] = max(0.1, config_value[i])
	
	return config_value


func load_purin():
	purin_textures = []
	for i in range(1, len(purin_sizes) + 1):
		var image_path = "%spurin%d.png" % [purin_file_path_root, i]
		purin_textures.append(load(image_path))


func set_up_game():
	# setup a unique seed for the randomizer
	randomize()
	# clear the game of any dropped purin
	remove_all_purin()
	# reset progress
	score = 0
	dropped_purin_count = 0
	time_since_last_dropped_purin_sec = drop_purin_cooldown_sec
	highest_tier_purin_dropped = 0
	# Generate a new bag of purin (what you get next to drop)
	purin_bag = PurinBag.new()
	purin_bag.generate_purin_bag(0)

	# if this is an AI player then create an AIController for it
	if ai_controlled and not is_instance_valid(ai_controller):
		ai_controller = AIController.new()
		ai_controller.init(self)

	player_label.text = player_name
	update_score_label()

	gameover_screen.visible = false
	Input.action_release("retry")
	# for testing
	#spawn_purin(Vector2(350,400),0)
	#spawn_purin(Vector2(300,400),1)
	#spawn_purin(Vector2(200,400),2)


func remove_all_purin():
	for purin in purin_node.get_children():
		purin.queue_free()
		
func update_score_label():
	score_label.text = "[center]%s[/center]" % [score]


func get_board_state():
	var state: String = ""
	for purin in purin_node.get_children():
		var purin_level = purin.get_meta("level")
		state = "%s_%s_%s,%s" % [purin_level, purin.position.x, purin.position.y, state]
	return state


func save_results():
	# cannot save to read-only res:// location
	if config_path.contains("res://"):
		return
	# get latest copies of the configs before updating them
	config_json = read_json(config_path)
	default_config_json = read_json(default_config_path)
	if config_json == null:
		config_json = default_config_json
	if config_json == null:
		print("No config_json was loaded? ", config_path)
		return
	# update config
	config_json["last_score"] = score
	if ai_controlled:
		config_json["weights"] = ai_controller.weights
		config_json["biases"] = ai_controller.biases
	if score > highscore:
		print(player_name, " got a new personal highscore of ", score)
		highscore = score
		config_json["highscore"] = highscore
		if ai_controlled:
			config_json["highscore_weights"] = ai_controller.weights
			config_json["highscore_biases"] = ai_controller.biases
	# save the results
	var json_string := JSON.stringify(config_json)
	# We will need to open/create a new file for this data string
	var file_access := FileAccess.open(config_path, FileAccess.WRITE)
	if not file_access:
		print("An error happened while saving data: ", FileAccess.get_open_error())
		return
		
	file_access.store_line(json_string)
	file_access.close()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if check_game_over(delta):
		print("Game is over for ", player_name)
		return

	time_since_last_dropped_purin_sec += delta
	if ai_controlled:
		ai_controller.process_ai(delta)
	else:
		process_player(delta)


func check_game_over(delta):
	if gameover_screen.visible == true:
		if Input.is_action_pressed("retry") or auto_retry:
			print("retry action pressed? ", Input.is_action_pressed("retry"))
			print("auto_retry? ", auto_retry)
			save_results()
			get_tree().paused = false
			set_up_game()
			return false
		if ai_controlled and not auto_retry and training:
			print("Delete AI player ", player_name, " because they lost, are not set to auto retry and are in training")
			save_results()
			self.queue_free()
		return true

	for purin in purin_node.get_children():
		if not is_instance_of(purin, Purin):
			continue
		# if the purin's game over time reaches the threshold you lose
		if ( 
			purin.game_over_timer_sec >= game_over_threshold_sec
			or purin.position.x < left_edge.position.x
			or purin.position.x > right_edge.position.x
		):
			print("%s Game Over with a score of %s" % [player_name, score])
			gameover_screen.visible = true
			purin.game_over_timer_sec = game_over_threshold_sec
			if not ai_controlled:
				get_tree().paused = true
			return true
		# if the purin is above the height threshold start increasing its conter
		if purin.position.y - purin.get_meta("radius") < top_edge.position.y:
			purin.game_over_timer_sec += delta
			# if the counter is under 3 sec then start the 3sec countdown animation too
			# allows longer count downs even though the animation only counts down from 3
			if purin.game_over_timer_sec > game_over_threshold_sec - 3:
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


func process_player(_delta):
	# reposition the player
	update_noir_position()
	# check inputs
	if (
		Input.is_action_just_pressed("drop_purin")
		and time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec
	):
		drop_purin()


func drop_purin():
	spawn_purin()
	noir.change_held_purin(
		purin_textures[purin_bag.get_current_purin_level(highest_tier_purin_dropped)]
	)
	next_purin_indicator.texture = purin_textures[purin_bag.get_next_purin_level(
		highest_tier_purin_dropped
	)]
	time_since_last_dropped_purin_sec = 0


func update_noir_position():
	# get mouse position in local coords instead of global
	var mouse_pos = to_local(get_viewport().get_mouse_position())
	noir.position.x = valid_x_pos(mouse_pos.x)


func valid_x_pos(x_pos: float):
	return max(left_edge.position.x, min(x_pos, right_edge.position.x))


func spawn_purin(
	initial_position: Vector2 = noir.position,
	level = purin_bag.drop_purin(highest_tier_purin_dropped),
	evil: bool = false
):
	# level is 0-indexed
	var purin: Purin = purin_object.instantiate()
	purin.position = Vector2(valid_x_pos(initial_position.x), initial_position.y)
	purin.set_meta("level", level)
	purin.set_meta("combined", false)
	purin.image.texture = purin_textures[level]
	purin.image.scale = self.scale
	purin.mass = pow(1.2, level)
	# update collider shape to be appropriate size
	var new_shape = CircleShape2D.new()
	var new_radius: float = get_purin_radius(level)
	new_shape.radius = new_radius
	purin.set_meta("radius", new_radius)
	purin.collider.shape = new_shape
	purin.particle_system.scale = Vector2(5+level, 5+level)
	purin.particle_system.process_material.emission_sphere_radius = new_radius * 0.5
	
	# if it's an evil purin then make that visible
	if evil:
		purin.evil.visible = true
		# evil ones spawn at the bottom
		purin.position = Vector2(purin.position.x, purin.position.y)

	elif not opponents.is_empty() and level > evil_purin_spawn_level_threshold:
		var opponent: PlayerController = opponents.pick_random()
		if is_instance_valid(opponent):
			# if it's not evil then depending on level it could spawn an evil purin in opponent's game
			opponent.spawn_purin(
				Vector2(
					randf_range(opponent.left_edge.position.x, opponent.right_edge.position.x),
					opponent.bottom_edge.position.y
				),
				round(level / evil_purin_spawn_level_divider),
				true
			)

	# listen to its signals for combining or bonking
	purin.connect("combine", combine_purin)
	purin.connect("bonk", bonk_purin)

	# add it to the stage
	purin_node.call_deferred("add_child", purin)
	
	# keep track of how many total were spawned for scoring purposes
	dropped_purin_count += 1

	return purin


func get_purin_radius(level: int):
	return (purin_sizes[level] * 0.5) * 1.17 * self.scale.x


func combine_purin(purin1: Purin, purin2: Purin):
	# if they were already freed then we have nothing to do
	if not is_instance_valid(purin1) or not is_instance_valid(purin2):
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

	# if both were evil before, so is the new one, otherwise it'll be normal
	var evil = purin1.evil.visible == true and purin2.evil.visible == true

	# combined purin will be of 1 level higher up to the max
	var new_level = min(purin1.get_meta("level") + 1, highest_possible_purin_level)

	# remove the two purin
	purin1.queue_free()
	purin2.queue_free()

	# create new purin of highest level
	var new_purin = spawn_purin(Vector2(spawn_x, spawn_y), new_level)
	# set its new values based on the combined stats
	new_purin.rotation = spawn_rotation
	new_purin.evil.visible = evil
	new_purin.angular_velocity = spawn_angular_velocity
	new_purin.linear_velocity = spawn_linear_velocity
	
	new_purin.particle_system.emitting = true
	# play sfx if not muted
	if not mute_sound:
		sfx_pop_player.play()

	if new_level > highest_tier_purin_dropped:
		highest_tier_purin_dropped = new_level
		purin_bag.bag.append_array(
			purin_bag.generate_purin_bag(max(0, round(highest_tier_purin_dropped * 0.5)))
		)
	# give the player score based on the size of the purin that was combined into
	# and give a multiplier that increases the more purin they have placed
	# so the value goes up the longer they play giving it a non-linear curve
	var score_increase = int(pow(new_level, 2)) * int(1 + (dropped_purin_count * 0.1))
	score += score_increase
	update_score_label()
	return new_purin


func bonk_purin(_purin1: Purin, _purin2: Purin):
	# TODO later maybe use the bodys to do something else
	# for now just play audio file
	if not mute_sound:
		sfx_bonk_player.play()
