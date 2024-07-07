extends Node
class_name Game
@export var bowl:Node2D;
@export var noir:Node2D;
@export var next_purin:Sprite2D;
@export var score_ui:RichTextLabel;
@export var sfx_pop_player:AudioStreamPlayer;
@export var sfx_bonk_player:AudioStreamPlayer;
@export var lose_area:LoseArea;
@export var gameover_screen:Node2D;
@export var ai_controlled:bool;
@export var player_name:String;
@export var debug_text:RichTextLabel;
@export var player_name_text:RichTextLabel;
@export var mute_sound:bool = true;
@export var debug:bool = false;
@export var training:bool = false;
@export var difficulty:String = "best";
const BOWL_WIDTH:int = 800;
const BOWL_THICKNESS:int = 20;
const BOWL_DROP_DISTANCE:int = 40;
const AI_PURIN_COUNT_PENALTY_WEIGHT:int = 2;
var AI_DROP_DELAY_SECONDS:float = 2;
var AI_DROP_DELAY_PANIC_SECONDS:float = 1;
var AI_X_WEIGHT:float = 0;
var AI_Y_WEIGHT:float = 0;
var AI_LEVEL_WEIGHT:float = 0;
var AI_STACKED_WEIGHT:float = 0;
var AI_EASY_COMBINE_WEIGHT:float = 50;
var last_highest_level_reached:int = 0;
var PURIN_SCENE:Resource = load("res://assets/scenes/Purin.tscn");
var purin_sizes;
var max_purin_size_drop;
var highest_level_reached;
var purin_file_path_root
var purin_images = [];
var use_mouse_controls;
var move_speed;
var time_since_keypress;
var using_mouse_time_threshold;
var holding_purin:Sprite2D;
var held_purin_level:int;
var score:int;
var ai_adjusted_score:float;
var highscore:int = 0;
var ai_adjusted_highscore:float = 0;
var dropped_purin_count;
var game_over_timer:float;
var game_over_grace_period_seconds:int;
var purin_bag:Array;
var next_purin_level:int = 0;
var has_purin_in_danger:bool = false;

var time_since_ai_dropped_purin:float;
var config:ConfigFile;
var best_config:String = "best";
@export var mutation_rate:float = 3;
@export var ai_use_best_rate:float = 35;
@export var ai_use_personal_rate:float = 35;
var drop_bias:float = 0.0;
var next_purin_weight:float = 0.0;
var config_path:String = ProjectSettings.localize_path("res://assets/ML/%s.cfg"%[difficulty]);
func start_game():
	remove_all_purin();
	# setup a unique seed for the randomizer
	randomize();
	# TODO load from config file instead
	purin_sizes = [50, 100, 125, 156, 175, 195, 220, 250, 275, 300, 343];
	max_purin_size_drop = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6]
	highest_level_reached = 0;
	game_over_timer = 0;
	game_over_grace_period_seconds = 3;
	
	# tetris bag of purin to drop
	purin_bag = generate_purin_bag(max_purin_size_drop[highest_level_reached]);
	
	purin_file_path_root = "res://assets/images/";
	purin_images = [];
	next_purin_level = 0;
	use_mouse_controls = true;
	has_purin_in_danger = false;
	move_speed = 500.0;
	time_since_keypress = 0;
	using_mouse_time_threshold = 1;
	score = 0;
	ai_adjusted_score = 0;
	dropped_purin_count = 0;
	for i in range(1, len(purin_sizes)+1):
		var image_path = "%spurin%d.png"%[purin_file_path_root, i];
		purin_images.append(load(image_path));
		# ensure she is at the top of the bowl
	noir.position.y = bowl.position.y;
	holding_purin = noir.get_node("Purin");
	# always start the game holding the smallest purin
	held_purin_level = 0;
	holding_purin.texture = purin_images[held_purin_level];
	player_name_text.text = player_name;
	if ai_controlled:
		set_up_ai();

func generate_purin_bag(max_level):
	var bag = [];
	# add each level of purin to the bag
	for level in range(0, max_level+1):
		bag.append(level)
	# shuffle it randomly
	bag.shuffle();
	return bag;

func remove_all_purin():
	var purin_node:Node2D = get_node("PurinObjects");
	for purin in purin_node.get_children():
		if is_instance_of(purin, Purin):
			purin.queue_free();
	
func get_valid_drop_position():
	var noir_pos:Vector2 = noir.position;
	var spawn_x_pos:float = min(max(bowl.position.x + BOWL_THICKNESS, noir_pos.x), bowl.position.x + BOWL_WIDTH - BOWL_THICKNESS);
	
	return Vector2(spawn_x_pos, bowl.position.y + BOWL_DROP_DISTANCE);
	
	
func combine_purin(purin1:Purin, purin2:Purin):
	# if they were already freed then we have nothing to do
	if not is_instance_valid(purin1) or not is_instance_valid(purin2):
		return
	
	# average position between the two
	var spawnX = (purin1.position.x + purin2.position.x) * 0.5;
	var spawnY = (purin1.position.y + purin2.position.y) * 0.5;
	# also average their rotate and velocity
	var spawn_rotation = (purin1.rotation + purin2.rotation) * 0.5;
	var spawn_angular_velocity = (purin1.angular_velocity + purin2.angular_velocity)*0.5;
	var spawn_linear_velocity = (purin1.linear_velocity + purin2.linear_velocity)*0.5;
	var purin_node:Node2D = get_node("PurinObjects");
	
	# get the current level of the purin being combined
	var level = purin1.get_meta("level") + 1;
	var score_increase = int(pow(level, 2)) * int(1+(dropped_purin_count*0.1));
	score += score_increase;
	if ai_controlled:
		# punish for spamming purin when in panic mode
		var panic_penalty = 1;
		if has_purin_in_danger:
			panic_penalty = 0.5;
		# reward for high level combinations
		var level_bonuses = [1,1,1,2,2,2,3,3,4,5,6,10,10];
		# reward for being closer to the bottom
		var bottom_bonus = (spawnY/400.0);
		# punish AI for having more purin, so it will want to have more combined
		ai_adjusted_score += bottom_bonus * level_bonuses[level] * panic_penalty * max(1, score_increase - (purin_node.get_child_count() * AI_PURIN_COUNT_PENALTY_WEIGHT)  - (dropped_purin_count * AI_PURIN_COUNT_PENALTY_WEIGHT));
		
	if level > highest_level_reached:
		highest_level_reached = level-1;
		# if it gives a new highest level then generate a new bag but add it to the existing one
		purin_bag = purin_bag + generate_purin_bag(max_purin_size_drop[highest_level_reached]);
	# delete the two
	purin1.queue_free();
	purin2.queue_free();
	
	if level > len(purin_sizes)-1:
		return
	# add a new purin object at the new position with a level one higher
	
	var new_purin = spawn_purin(level, Vector2(spawnX, spawnY));
	new_purin.rotation = spawn_rotation;
	new_purin.angular_velocity = spawn_angular_velocity;
	new_purin.linear_velocity = spawn_linear_velocity;
	purin_node.call_deferred("add_child", new_purin);
	if not mute_sound:
		sfx_pop_player.play();
	
	
func spawn_purin(size:int, initial_position:Vector2=get_valid_drop_position()):
	"""Spawn a purin at the given location or the generic nearest valid drop position
	"""
	var level = min(size, len(purin_sizes)-1);
	var purin:Purin = PURIN_SCENE.instantiate();
	purin.position = initial_position;
	purin.mass = pow(1.2, level);
	var collider:CollisionShape2D = purin.get_node("Collider");
	var new_shape = CircleShape2D.new();
	new_shape.radius = (purin_sizes[level]*0.5)*1.17;
	collider.shape = new_shape;
	var image:Sprite2D = purin.get_node("Image");
	image.texture = purin_images[level];
	
	purin.set_meta("type", "purin%d"% [level]);
	purin.set_meta("level", level);
	#purin.debug_text.text = "[center]%s[/center]"%[level];
	purin.set_meta("radius", new_shape.radius);
	
	purin.connect("combine", combine_purin);
	purin.connect("bonk", bonk_purin);
	return purin;

func bonk_purin(_purin1:Purin, _purin2:Purin):
	# TODO later maybe use the bodys to do something else
	# for now just play audio file
	if not mute_sound:
		sfx_bonk_player.play();
	pass

# Called when the node enters the scene tree for the first time.
func _ready():
	start_game();
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	self.score_ui.text = "[center]%d[/center]" %(score);
	if ai_controlled and debug:
		self.score_ui.text = "[center]%d (%d)[/center]" %[score, ai_adjusted_score];
	last_highest_level_reached = highest_level_reached;
	if not ai_controlled and Input.is_action_pressed("retry"):
		gameover_screen.visible = false;
		if score > highscore:
			highscore = score;
		start_game();
		get_tree().paused = false;
		
	var purin_node:Node2D = get_node("PurinObjects");
	has_purin_in_danger = false;
	for purin in purin_node.get_children():
		if purin.has_meta("purin_in_danger") and purin.get_meta("purin_in_danger"):
			has_purin_in_danger = true;
			lose_area.start_countdown();
			break;
	if has_purin_in_danger:
		if game_over_timer >= game_over_grace_period_seconds:
			print("%s Game Overed with a score of %s (%s)"%[player_name, score, ai_adjusted_score]);
			if score > highscore:
				highscore = score;
			if not ai_controlled:
				get_tree().paused = true;
				gameover_screen.visible = true;
			else:
				if ai_controlled and ai_adjusted_score > ai_adjusted_highscore:
					ai_adjusted_highscore = ai_adjusted_score;
				if training:
					save_scores();
					self.queue_free();
				else:
					start_game();
				
				return;
		game_over_timer += delta;
	else:
		lose_area.stop_countdown();
		game_over_timer = 0;
	if not ai_controlled:
		if Input.is_action_pressed("move_right"):
			noir.translate(Vector2(move_speed*delta,0));
			noir.position.x = get_valid_drop_position().x;
			use_mouse_controls = false;
			time_since_keypress = 0;
			
		if Input.is_action_pressed("move_left"):
			noir.translate(Vector2(-move_speed*delta,0));
			noir.position.x = get_valid_drop_position().x;
			use_mouse_controls = false;
			time_since_keypress = 0;
		if use_mouse_controls:
			noir.position.x = get_viewport().get_mouse_position().x - self.position.x;
	else:
		process_ai_turn(delta)
	
	noir.position = update_noir_pos();
	
	check_to_drop_purin(delta)
	
	time_since_keypress += delta;
	if time_since_keypress >= using_mouse_time_threshold:
		var mouse_pos = get_viewport().get_mouse_position();
		if mouse_pos.x >= bowl.position.x +self.position.x and mouse_pos.x <= bowl.position.x + BOWL_WIDTH + self.position.x:
			use_mouse_controls = true;
			
func update_noir_pos():
	var purin_radius = ((purin_sizes[held_purin_level]*0.5)*1.17);
	var min_x_pos = bowl.position.x + BOWL_THICKNESS + purin_radius;
	var max_x_pos = bowl.position.x + BOWL_WIDTH - BOWL_THICKNESS - purin_radius;
	return Vector2(min(max(noir.position.x, min_x_pos),max_x_pos), noir.position.y);

func check_to_drop_purin(_delta):
	if purin_bag.is_empty():
		purin_bag = purin_bag + generate_purin_bag(max_purin_size_drop[highest_level_reached]);
		
	next_purin_level = purin_bag[-1];
	next_purin.texture = purin_images[purin_bag[-1]]
	if ai_controlled:
		return;
	if Input.is_action_just_pressed("drop_purin"):
		if use_mouse_controls:
			var mouse_pos = get_viewport().get_mouse_position();
			if mouse_pos.x <= bowl.position.x + self.position.x or mouse_pos.x >= bowl.position.x + BOWL_WIDTH + self.position.x:
				return;
		dropped_purin_count += 1;
		var purin_node:Node2D = get_node("PurinObjects");
		# create a new purin that is the same type as the held one
		var dropped_purin:Purin = spawn_purin(held_purin_level);
		purin_node.add_child(dropped_purin);
		# generate new purin to hold
		held_purin_level = purin_bag.pop_back();
		holding_purin.texture = purin_images[held_purin_level];
		
func save_scores():
	var purin_node:Node2D = get_node("PurinObjects");
	var final_purin_levels = "";
	for purin in purin_node.get_children():
		var purin_level = purin.get_meta("level");
		if purin_level > last_highest_level_reached:
			last_highest_level_reached = purin_level;
		final_purin_levels = "%s,%s"%[purin_level,final_purin_levels];
	config = ConfigFile.new();
	config.load(config_path);
	if score > 0:
		config.set_value(player_name, "previous_highscore", score);
	if ai_adjusted_score > 0:
		config.set_value(player_name, "previous_ai_adjusted_highscore", ai_adjusted_score);
	if ai_adjusted_highscore > config.get_value(player_name, "ai_adjusted_highscore", 0):
		print("%s got a new personal highscore of %s!"%[player_name, score])
		config.set_value(player_name, "highscore", highscore);
		config.set_value(player_name, "ai_adjusted_highscore", ai_adjusted_highscore);
		config.set_value(player_name, "x", AI_X_WEIGHT);
		config.set_value(player_name, "y", AI_Y_WEIGHT);
		config.set_value(player_name, "l", AI_LEVEL_WEIGHT);
		config.set_value(player_name, "s", AI_STACKED_WEIGHT);
		config.set_value(player_name, "c", AI_EASY_COMBINE_WEIGHT);
		config.set_value(player_name, "d1", AI_DROP_DELAY_SECONDS);
		config.set_value(player_name, "d2", AI_DROP_DELAY_PANIC_SECONDS);
		config.set_value(player_name, "drop_bias", drop_bias);
		config.set_value(player_name, "np", next_purin_weight);
		config.set_value(player_name, "player_name", player_name);
		config.set_value(player_name, "final_purin_levels", final_purin_levels);
		config.set_value(player_name, "highest_level_reached", last_highest_level_reached);
	config.save(config_path)
	
	if ai_adjusted_highscore > config.get_value(best_config, "ai_adjusted_highscore", 0):
		print("%s got a new global highscore of %s!"%[player_name, score])
		config.set_value(best_config, "previous_highscore", highscore);
		config.set_value(best_config, "previous_ai_adjusted_highscore", ai_adjusted_highscore);
		config.set_value(best_config, "highscore", highscore);
		config.set_value(best_config, "ai_adjusted_highscore", ai_adjusted_highscore);
		config.set_value(best_config, "x", AI_X_WEIGHT);
		config.set_value(best_config, "y", AI_Y_WEIGHT);
		config.set_value(best_config, "l", AI_LEVEL_WEIGHT);
		config.set_value(best_config, "s", AI_STACKED_WEIGHT);
		config.set_value(best_config, "c", AI_EASY_COMBINE_WEIGHT);
		config.set_value(best_config, "d1", AI_DROP_DELAY_SECONDS);
		config.set_value(best_config, "d2", AI_DROP_DELAY_PANIC_SECONDS);
		config.set_value(best_config, "drop_bias", drop_bias);
		config.set_value(best_config, "np", next_purin_weight);
		config.set_value(best_config, "player_name", player_name);
		config.set_value(best_config, "final_purin_levels", final_purin_levels);
		config.set_value(best_config, "highest_level_reached", last_highest_level_reached);
		
		config.save(config_path)
		
func set_up_ai():
	config = ConfigFile.new();
	config.load(config_path);
	#print("best:", config.get_value(best_config, "highscore"));
	
	var mutant_type = randf_range(0,100);
	
	if mutant_type < ai_use_best_rate:
		#print(player_name, " will try to improve on the best");
		AI_X_WEIGHT = get_and_mutate(best_config, "x", -30.0, 30.0, -100.0, 100.0);
		AI_Y_WEIGHT = get_and_mutate(best_config, "y", -30.0, 30.0, -100.0, 100.0);
		AI_LEVEL_WEIGHT = get_and_mutate(best_config, "l", -30.0, 30.0, -100.0, 100.0);
		AI_STACKED_WEIGHT = get_and_mutate(best_config, "s", -30.0, 30.0, 0.0, 100.0);
		AI_EASY_COMBINE_WEIGHT = get_and_mutate(best_config, "c", -30.0, 30.0, 0.0, 100.0);
		AI_DROP_DELAY_SECONDS = get_and_mutate(best_config, "d1", -0.5, 0.5, 0.5, 2.0);
		AI_DROP_DELAY_PANIC_SECONDS = get_and_mutate(best_config, "d2", -1.0, 1.0, AI_DROP_DELAY_SECONDS, AI_DROP_DELAY_SECONDS);
		drop_bias = get_and_mutate(best_config, "drop_bias", -20.0, 20.0, -50.0, 50.0);
		next_purin_weight = get_and_mutate(best_config, "np", -20.0, 20.0, 0.0, 50.0);
	elif mutant_type >= ai_use_best_rate and mutant_type < ai_use_best_rate + ai_use_personal_rate:
		#print(player_name, " will try to improve on the their personal");
		AI_X_WEIGHT = get_and_mutate(player_name, "x", -30.0, 30.0, -100.0, 100.0);
		AI_Y_WEIGHT = get_and_mutate(player_name, "y", -30.0, 30.0, -100.0, 100.0);
		AI_LEVEL_WEIGHT = get_and_mutate(player_name, "l", -30.0, 30.0, -100.0, 100.0);
		AI_STACKED_WEIGHT = get_and_mutate(player_name, "s", -30.0, 30.0, 0.0, 100.0);
		AI_EASY_COMBINE_WEIGHT = get_and_mutate(player_name, "c", -30.0, 30.0, 0.0, 100.0);
		AI_DROP_DELAY_SECONDS = get_and_mutate(player_name, "d1", -0.5, 0.5, 0.5, 2.0);
		AI_DROP_DELAY_PANIC_SECONDS = get_and_mutate(player_name, "d2", -1.0, 1.0, AI_DROP_DELAY_SECONDS, AI_DROP_DELAY_SECONDS);
		drop_bias = get_and_mutate(player_name, "drop_bias", -20.0, 20.0, -50.0, 50.0);
		next_purin_weight = get_and_mutate(player_name, "np", -20.0, 20.0, 0.0, 50.0);
	else:
		#print(player_name, " will try something random");
		AI_X_WEIGHT = randf_range(-100.0, 100.0);
		AI_Y_WEIGHT = randf_range(-100.0, 100.0);
		AI_LEVEL_WEIGHT = randf_range(-100.0, 100.0);
		AI_STACKED_WEIGHT = randf_range(0.0, 100.0);
		AI_EASY_COMBINE_WEIGHT = randf_range(0.0, 100.0);
		AI_DROP_DELAY_SECONDS = randf_range(0.5, 2.0);
		AI_DROP_DELAY_PANIC_SECONDS = randf_range(0.1, AI_DROP_DELAY_SECONDS);
		drop_bias = randf_range(0.0, 50.0);
		next_purin_weight = randf_range(-50.0, 50.0);
	if debug:
		debug_text.text = "X: %s, Y: %s, L:%s, S:%s, D1:%s, D2:%s, B:%s, np: %s, c:%s, Highscore:%s (%s)"%[round(AI_X_WEIGHT), round(AI_Y_WEIGHT), round(AI_LEVEL_WEIGHT), round(AI_STACKED_WEIGHT), AI_DROP_DELAY_SECONDS, AI_DROP_DELAY_PANIC_SECONDS, round(drop_bias), round(next_purin_weight), round(AI_EASY_COMBINE_WEIGHT), highscore, ai_adjusted_highscore]
	time_since_ai_dropped_purin = 0;
	
	pass

func get_and_mutate(config_name, key_name, mutation_min, mutation_max, true_min, true_max):
	var value = config.get_value(config_name, key_name, 1);
	if training and randf_range(0,100) < mutation_rate:
			value = min(true_max, max(true_min, value + randf_range(mutation_min, mutation_max)));
	
	return value;


class PurinSorter:
	var x_weight:float;
	var y_weight:float;
	var level_weight:float;
	var stacked_weight:float;
	var next_purin_level:int;
	var next_purin_weight:float;
	var drop_bias:float;
	var easy_combine_weight:float;
	var debug:bool;
	func init(xw, yw, lw, sw, npl, npw, db, c, debug_mode):
		self.x_weight = xw;
		self.y_weight = yw;
		self.level_weight = lw;
		self.stacked_weight = sw;
		self.next_purin_level = npl;
		self.next_purin_weight = npw;
		self.drop_bias = db;
		self.easy_combine_weight = c;
		self.debug = debug_mode;
		
	func normalize(number):
		if number != 0:
			return abs(number/number);
		return 0;
		
	func score_purin(held_purin_level, x, y, level, num_above, x2, y2, level2, num_above2):
		
		var xdiff = 0.1*x_weight * normalize(x2 - x);
		var ydiff = 0.1*y_weight * normalize(y2 - y);
		var leveldiff1 = held_purin_level - level;
		var leveldiff2 = held_purin_level - level2;
		var leveldiff = 0;
		if leveldiff1 < leveldiff2:
			leveldiff = leveldiff1 * level_weight;
		else:
			leveldiff = -leveldiff2 * level_weight;
		var easy_combine = 0;
		if leveldiff1 == 0:
			easy_combine = easy_combine_weight;
		elif leveldiff2 == 0:
			easy_combine = -easy_combine_weight;
		
		var above_diff = 0;
		if num_above < num_above2:
			above_diff = -stacked_weight * num_above;
		else:
			above_diff = -stacked_weight * num_above2;
		var height_penalty:float = 0.0;
		if y < 200 and y2 >= 200 and easy_combine < 0:
			height_penalty = 100*abs(y_weight);
		
		return xdiff + ydiff + leveldiff + above_diff + easy_combine - height_penalty;
		
	func prioritize_purin(purin1:Purin, purin2:Purin, held_purin_level:int):
		if purin2 == null:
			return 0;
		
		var next_purin_score = 0;
		if level_weight != 0:
			next_purin_score = score_purin(next_purin_level, purin1.position.x, purin1.position.y, purin1.get_meta("level"),  purin1.num_above_purin(), purin2.position.x, purin2.position.y, purin2.get_meta("level"),  purin2.num_above_purin())
		var this_score = score_purin(held_purin_level, purin1.position.x, purin1.position.y, purin1.get_meta("level"),  purin1.num_above_purin(), purin2.position.x, purin2.position.y, purin2.get_meta("level"),  purin2.num_above_purin())
		# if the next purin they'll take is better for the spot than this one, save it for that purin instead
		if this_score > next_purin_score:
			return this_score;
		return this_score * ((100-next_purin_weight)/100.0);

	func get_best_spawn_x(existing_purin, held_purin_level):
		var best_purin:Purin = null;
		var best_score:int = -9999;
		# custom_sort was throwing thousands of errors and I couldn't figure out why (inconsisent)
		# so I am sorting them myself >_>
		for purin1 in existing_purin:
			var purin_score = prioritize_purin(purin1, best_purin, held_purin_level);
			var rounded_score = round(purin_score*100.0)/100.0;
			if debug:
				var text_colour  = "00FF00";
				if purin_score < 0:
					text_colour = "FF0000";
				purin1.debug_text.text = "[center][color=#%s]%s %s[/color][/center]"%[text_colour, purin1.get_meta("level"), rounded_score];
			
			if purin_score > best_score or best_purin == null:
				best_purin = purin1;
				best_score = purin_score;
		if debug:
			var best_text_colour = "FFFF00";
			best_purin.debug_text.text = "[center][color=#%s]%s %s[/color][/center]"%[best_text_colour, best_purin.get_meta("level"), best_score];
		return best_purin.position.x + best_purin.linear_velocity.x# + (drop_bias);
	
func process_ai_turn(delta):
	time_since_ai_dropped_purin += delta;
	var max_wait:float = AI_DROP_DELAY_SECONDS;
	if has_purin_in_danger:
		max_wait = AI_DROP_DELAY_PANIC_SECONDS;
	
	if time_since_ai_dropped_purin >= max_wait:
		# if no purin on the board then drop on the left
		var purin_node:Node2D = get_node("PurinObjects");
		var purin_sorter:PurinSorter = PurinSorter.new();
		purin_sorter.init(AI_X_WEIGHT, AI_Y_WEIGHT, AI_LEVEL_WEIGHT, AI_STACKED_WEIGHT, next_purin_level, next_purin_weight, drop_bias, AI_EASY_COMBINE_WEIGHT, debug);
		
		var spawn_x = 0;
		
		if purin_node.get_child_count() > 0:
			var existing_purin:Array[Node] = purin_node.get_children();
			if not existing_purin.is_empty():
				spawn_x = bowl.position.x + purin_sorter.get_best_spawn_x(existing_purin, held_purin_level) - 0.5;
		noir.position.x = spawn_x;
		noir.position = update_noir_pos();
		
		dropped_purin_count += 1;
		# create a new purin that is the same type as the held one
		var dropped_purin:Purin = spawn_purin(held_purin_level);
		purin_node.add_child(dropped_purin);
		# generate new purin to hold
		held_purin_level = purin_bag.pop_back();
		holding_purin.texture = purin_images[held_purin_level];
		time_since_ai_dropped_purin = 0;
		return
	pass
