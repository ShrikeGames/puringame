extends Node2D
class_name PlayerController

@export var player_name:String = "Player"
@export var config_path:String = "user://Player.cfg"
var default_config_path:String = "res://configs/default.cfg"
@export var ai_controlled:bool = false
var ai_controller:AIController
@export var noir: NoiR
@export var next_purin_indicator:Sprite2D
@export var top_edge:Node2D
@export var left_edge:Node2D
@export var right_edge:Node2D
@export var bottom_edge:Node2D
@export var purin_node: Node2D
@export var sfx_pop_player: AudioStreamPlayer
@export var sfx_bonk_player: AudioStreamPlayer
@export var mute_sound:bool = false
@export var opponents:Array[PlayerController] = [];
@export var gameover_screen:Node2D
@export var player_label:RichTextLabel
@export var debug_label:RichTextLabel
@export var score_label:RichTextLabel

var config: ConfigFile
var default_config:ConfigFile


var score:int
var highscore:int


var purin_object: Resource
var purin_textures:Array[Texture2D]
var purin_sizes:Array 
var highest_possible_purin_level:int
const purin_file_path_root = "res://assets/images/"
var purin_bag:PurinBag
var highest_tier_purin_dropped:int
var dropped_purin_count:int

var evil_purin_spawn_level_threshold:float
var evil_purin_spawn_level_divider:float 

var time_since_last_dropped_purin_sec:float
var drop_purin_cooldown_sec:float

var game_over_threshold_sec:float

func _on_ready() -> void:
	load_configs()
	# first time load the purin images/textures
	load_purin()
	# set up the game, can be called to restart at anytime
	set_up_game()

func load_configs():
	config = ConfigFile.new()
	config.load(config_path)
	default_config = ConfigFile.new()
	default_config.load(default_config_path)
	
	# get values from config file (player's save, or from default config)
	purin_sizes = get_config_value_or_default("purin_sizes")
	highest_possible_purin_level = get_config_value_or_default("highest_possible_purin_level")
	game_over_threshold_sec = get_config_value_or_default("game_over_threshold_sec")
	drop_purin_cooldown_sec = get_config_value_or_default("drop_purin_cooldown_sec")
	evil_purin_spawn_level_threshold = get_config_value_or_default("evil_purin_spawn_level_threshold")
	evil_purin_spawn_level_divider = get_config_value_or_default("evil_purin_spawn_level_divider")
	highscore = get_config_value_or_default("highscore")

func get_config_value_or_default(key):
	return config.get_value(player_name, key, default_config.get_value(player_name, key))

func load_purin():
	purin_object = load("res://assets/scenes/Purin.tscn")
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
	purin_bag.generate_purin_bag(highest_tier_purin_dropped)
	
	# if this is an AI player then create an AIController for it
	if ai_controlled:
		ai_controller = AIController.new()
		ai_controller.init(self)
	
	player_label.text = player_name
	update_score_label()
	# for testing
	#spawn_purin(Vector2(400,400),10)
	#spawn_purin(Vector2(400,400),9)
	#spawn_purin(Vector2(400,400),8)
	
func remove_all_purin():
	for purin in purin_node.get_children():
		if is_instance_of(purin, Purin):
			purin.queue_free()
	
func update_score_label():
	score_label.text = "[center]%s[/center]"%[score]

func get_board_state():
	var state:String = ""
	for purin in purin_node.get_children():
		var purin_level = purin.get_meta("level")
		state = "%s-%s-%s,%s" % [purin_level, purin.position.x, purin.position.y, state]
	return state
	
func save_results():
	# save the board-state
	var board_state:String = get_board_state()
	config.set_value(player_name, "last_board_state", board_state)
	
	# save their last score and their new highscore if they have one
	config.set_value(player_name, "last_score", score)
	if score > highscore:
		highscore = score
		config.set_value(player_name, "highscore", highscore)
		config.set_value(player_name, "highscore_board_state", board_state)
	
	config.save(config_path)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if check_game_over(delta):
		return
		
	time_since_last_dropped_purin_sec += delta
	if ai_controlled:
		ai_controller.process_ai(delta)
	else:
		process_player(delta)

func check_game_over(delta):
	if gameover_screen.visible:
		if Input.is_action_pressed("retry"):
			save_results()
			Input.action_release("retry")
			gameover_screen.visible = false
			get_tree().paused = false
			set_up_game()
			return false
		return true
	
	for purin in purin_node.get_children():
		# if the purin's game over time reaches the threshold you lose
		if purin.game_over_timer_sec >= game_over_threshold_sec:
			print("%s Game Over"%[player_name])
			gameover_screen.visible = true
			get_tree().paused = true
			return true
		# if the purin is above the height threshold start increasing its conter
		if purin.position.y - purin.get_meta("radius") < top_edge.position.y:
			purin.game_over_timer_sec += delta
			# if the counter is under 4 sec then start the 3sec countdown animation too
			# allows longer count downs even though the animation only counts down from 3
			if purin.game_over_timer_sec < 4:
				purin.game_over_countdown.visible = true
				if not purin.game_over_countdown.is_playing():
					purin.game_over_countdown.play()
		else:
			# otherwise it's safe, so reset its counter if needed and hide the animation
			purin.game_over_timer_sec = 0
			purin.game_over_countdown.visible = false
	
	return false

func process_player(_delta):
	# reposition the player
	update_noir_position()
	# check inputs
	if Input.is_action_just_pressed("drop_purin") and time_since_last_dropped_purin_sec >= drop_purin_cooldown_sec:
		spawn_purin()
		noir.change_held_purin(purin_textures[purin_bag.get_current_purin_level(highest_tier_purin_dropped)])
		next_purin_indicator.texture = purin_textures[purin_bag.get_next_purin_level(highest_tier_purin_dropped)]
		time_since_last_dropped_purin_sec = 0
	
func update_noir_position():
	# get mouse position in local coords instead of global
	var mouse_pos = to_local(get_viewport().get_mouse_position())
	noir.position.x = valid_x_pos(mouse_pos.x)
	
func valid_x_pos(x_pos:float):
	return max(left_edge.position.x, min(x_pos, right_edge.position.x))

func spawn_purin(initial_position:Vector2 = noir.position, level = purin_bag.drop_purin(highest_tier_purin_dropped), evil:bool = false):
	# level is 0-indexed
	var purin: Purin = purin_object.instantiate()
	purin.position = Vector2(valid_x_pos(initial_position.x), initial_position.y)
	purin.set_meta("level", level)
	purin.set_meta("combined", false)
	purin.image.texture = purin_textures[level]
	purin.mass = pow(1.2, level)
	# update collider shape to be appropriate size
	var new_shape = CircleShape2D.new()
	var new_radius: float =  (purin_sizes[level] * 0.5) * 1.17 * self.scale.x
	new_shape.radius = new_radius
	purin.set_meta("radius", new_radius)
	purin.collider.shape = new_shape
	
	# if it's an evil purin then make that visible
	if evil:
		purin.evil.visible = true
		# evil ones spawn at the bottom, so offset it by the radius so it's not in the ground
		purin.position = Vector2(purin.position.x, purin.position.y - new_radius)
		
	elif not opponents.is_empty() and level > evil_purin_spawn_level_threshold:
		var opponent:PlayerController = opponents.pick_random()
		if is_instance_valid(opponent):
			# if it's not evil then depending on level it could spawn an evil purin in opponent's game
			opponent.spawn_purin(Vector2(randf_range(opponent.left_edge.position.x, opponent.right_edge.position.y), opponent.bottom_edge.position.y), round(level/evil_purin_spawn_level_divider), true)
			
			
	# listen to its signals for combining or bonking
	purin.connect("combine", combine_purin)
	purin.connect("bonk", bonk_purin)
	
	# add it to the stage
	purin_node.call_deferred("add_child", purin)
	
	# keep track of how many total were spawned for scoring purposes
	dropped_purin_count += 1
	
	return purin
	
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
	# if it's a new record, remember that
	if new_level > highest_tier_purin_dropped:
		highest_tier_purin_dropped = new_level
		# restock the bag with sizes up to half the highest achieved
		purin_bag.restock_bag(round(highest_tier_purin_dropped))
	
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
	
	# play sfx if not muted
	if not mute_sound:
		sfx_pop_player.play()
		
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
