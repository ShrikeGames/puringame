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

const BOWL_WIDTH:int = 800;
const BOWL_THICKNESS:int = 20;
const BOWL_DROP_DISTANCE:int = 40;
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
var score;
var dropped_purin_count;
var game_over_timer:float;
var game_over_grace_period_seconds:int;
@export var purin_bag:Array;
func start_game():
	remove_all_purin();
	
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
	use_mouse_controls = true;
	move_speed = 500.0;
	time_since_keypress = 0;
	using_mouse_time_threshold = 1;
	score = 0;
	dropped_purin_count = 0;
	for i in range(1, len(purin_sizes)+1):
		var image_path = "%spurin%d.png"%[purin_file_path_root, i];
		purin_images.append(load(image_path));
		# ensure she is at the top of the bowl
	noir.position.y = bowl.position.y;
	holding_purin = noir.get_node("Purin");
	# always start the game holding the smallest purin
	held_purin_level = 0
	holding_purin.texture = purin_images[held_purin_level]
	

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
	
	# get the current level of the purin being combined
	var level = purin1.get_meta("level");
	score += int(pow(level+1, 2)) * int(1+(dropped_purin_count*0.1));
	if level > highest_level_reached:
		highest_level_reached = level
		# if it gives a new highest level then generate a new bag but add it to the existing one
		purin_bag = purin_bag + generate_purin_bag(max_purin_size_drop[highest_level_reached]);
	# delete the two
	purin1.queue_free();
	purin2.queue_free();
	
	if level > len(purin_sizes)-1:
		return
	# add a new purin object at the new position with a level one higher
	var purin_node:Node2D = get_node("PurinObjects");
	var new_purin = spawn_purin(level, Vector2(spawnX, spawnY));
	new_purin.rotation = spawn_rotation;
	new_purin.angular_velocity = spawn_angular_velocity;
	new_purin.linear_velocity = spawn_linear_velocity;
	purin_node.call_deferred("add_child", new_purin);
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
	
	purin.set_meta("type", "purin%d"% [level+1]);
	purin.set_meta("level", level+1);
	
	purin.connect("combine", combine_purin);
	purin.connect("bonk", bonk_purin);
	return purin;

func bonk_purin(_purin1:Purin, _purin2:Purin):
	# TODO later maybe use the bodys to do something else
	# for now just play audio file
	sfx_bonk_player.play();

# Called when the node enters the scene tree for the first time.
func _ready():
	start_game();
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	self.score_ui.text = "[center]%d[/center]" %(score)
	var purin_node:Node2D = get_node("PurinObjects");
	var has_purin_in_danger:bool = false;
	for purin in purin_node.get_children():
		if purin.has_meta("purin_in_danger") and purin.get_meta("purin_in_danger"):
			has_purin_in_danger = true;
			lose_area.start_countdown();
			break;
	if has_purin_in_danger:
		if game_over_timer >= game_over_grace_period_seconds:
			print("Game Over");
			get_tree().paused = true;
			gameover_screen.visible = true;
		game_over_timer += delta;
	else:
		lose_area.stop_countdown();
		game_over_timer = 0;
	
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
		noir.position.x = get_viewport().get_mouse_position().x;
	
	var purin_radius = ((purin_sizes[held_purin_level]*0.5)*1.17);
	var min_x_pos = bowl.position.x + BOWL_THICKNESS + purin_radius;
	var max_x_pos = bowl.position.x + BOWL_WIDTH - BOWL_THICKNESS - purin_radius;
	noir.position = Vector2(min(max(noir.position.x, min_x_pos),max_x_pos), noir.position.y);
	
	check_to_drop_purin()
	
	time_since_keypress += delta;
	if time_since_keypress >= using_mouse_time_threshold:
		var mouse_pos = get_viewport().get_mouse_position();
		if mouse_pos.x >= bowl.position.x and mouse_pos.x <= bowl.position.x + BOWL_WIDTH:
			use_mouse_controls = true;
	

func check_to_drop_purin():
	if purin_bag.is_empty():
		purin_bag = purin_bag + generate_purin_bag(max_purin_size_drop[highest_level_reached]);
	next_purin.texture = purin_images[purin_bag[-1]]
	if Input.is_action_just_pressed("drop_purin"):
		if use_mouse_controls:
			var mouse_pos = get_viewport().get_mouse_position();
			if mouse_pos.x <= bowl.position.x or mouse_pos.x >= bowl.position.x + BOWL_WIDTH:
				return;
		dropped_purin_count += 1;
		var purin_node:Node2D = get_node("PurinObjects");
		# create a new purin that is the same type as the held one
		var dropped_purin:Purin = spawn_purin(held_purin_level);
		purin_node.add_child(dropped_purin);
		# generate new purin to hold
		held_purin_level = purin_bag.pop_back();
		holding_purin.texture = purin_images[held_purin_level]
