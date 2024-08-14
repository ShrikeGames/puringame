extends Node

# This class is always available
var settings_config_location:String = "user://settings.json"
var default_settings_config_location:String = "res://settings.json"
var purin_sizes = [50, 100, 125, 156, 175, 195, 250, 275, 300, 343]
var highest_possible_purin_level = 9
var game_over_threshold_sec = 6
var evil_purin_spawn_level_threshold = 9

# audio sliders 0.0 - 1.0
var volume_master:float = 0.5
var volume_menu:float = 0.5
var volume_game_sfx:float = 0.5
var volume_voices:float = 0.5
var volume_music:float = 0.5

# graphics
var enable_rain:bool = true
var fullscreen:bool = false

# controls
var active_controls:String = "mouse"
# enable or disable control types (applies to menus and in-game)
var controls_mouse:bool = true
var controls_keyboard:bool = true
var controls_controller:bool = true
var controls_move_speed:float = 50.0
# add additional keybinds for the actions, allow overlap with drop (applies to menus and in-game)
var custom_key_up:Key = KEY_W
var custom_key_down:Key = KEY_S
var custom_key_left:Key = KEY_A
var custom_key_right:Key = KEY_D
# for menus primarily
var cusom_key_accept:Key = KEY_ENTER
var custom_key_drop:Key = KEY_S
var custom_key_retry:Key = KEY_R
var custom_key_pause:Key = KEY_ESCAPE
var zoom_in:Key = KEY_PLUS
var zoom_out:Key = KEY_MINUS

# language: "en" or "jp"
var language:String = "en"

# Accessibility settings
# if true show the purin's "level" on them
var numbered_purin:bool = false
# if enabled will drop continuously until you press the key again
var drop_troggle:bool = true
# how often it should auto drop
var auto_drop_cooldown_sec:float = 1.0

# the normal game speed, slow it down to be easier. 0.5-1.0
var game_speed:float = 1
# if enabled the AI will only drop purin after you do
var turn_based_mode:bool = false

# AI training settings
var training_number_of_ai:int = 2
# how long each "generation" of training is before it restarts a new one
var training_generation_lifetime_sec:int = 600
# how fast the game should play when training 1.0-3.0
var training_game_speed:float = 1

var score_orb_scene: Resource = load("res://assets/scenes/ScoreOrb.tscn")
var evil_orb_scene: Resource = load("res://assets/scenes/EvilOrb.tscn")

var purin_object_scene: Resource = load("res://assets/scenes/Purin.tscn")

var purin_textures: Array[Texture2D] = []
var evil_purin_textures: Array[Texture2D] = []
const purin_file_path_root = "res://assets/images/game/"

var max_input_size:int = 98
var neural_training_models:Array[NeuralNetworkAdvanced] = []
var neural_training_total_score:float = 0
var neural_training_total_loss:float = 0
var neural_training_total_fitness:float = 0
var nna:NeuralNetworkAdvanced

func read_json(path:String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json_string = FileAccess.get_file_as_string(path)
	var json_dict = JSON.parse_string(json_string)
	
	return json_dict
	
func load_settings():
	var config_json:Dictionary = read_json(settings_config_location)
	var default_config_json:Dictionary = read_json(default_settings_config_location)
	if config_json.is_empty():
		config_json = default_config_json
	# audio sliders 0.0 - 1.0
	volume_master = config_json.get("volume_master", volume_master)
	volume_menu = config_json.get("volume_menu", volume_menu)
	volume_game_sfx = config_json.get("volume_game_sfx", volume_game_sfx)
	volume_voices = config_json.get("volume_voices", volume_voices)
	volume_music = config_json.get("volume_music", volume_music)
	
	# controls
	# enable or disable control types (applies to menus and in-game)
	controls_mouse = config_json.get("controls_mouse", controls_mouse)
	controls_keyboard = config_json.get("controls_keyboard", controls_keyboard)
	controls_controller = config_json.get("controls_controller", controls_controller)
	controls_move_speed = config_json.get("controls_move_speed", controls_move_speed)
	
	# graphics
	enable_rain = config_json.get("enable_rain", enable_rain)
	fullscreen = config_json.get("fullscreen", fullscreen)
	
	# add additional keybinds for the actions, allow overlap with drop (applies to menus and in-game)
	custom_key_up = config_json.get("custom_key_up", custom_key_up)
	custom_key_down = config_json.get("custom_key_down", custom_key_down)
	custom_key_left = config_json.get("custom_key_left", custom_key_left)
	custom_key_right =config_json.get("custom_key_right", custom_key_right)
	# for menus primarily
	cusom_key_accept = config_json.get("cusom_key_accept", cusom_key_accept)
	custom_key_drop = config_json.get("custom_key_drop", custom_key_drop)
	custom_key_retry = config_json.get("custom_key_retry", custom_key_retry)
	custom_key_pause = config_json.get("custom_key_pause", custom_key_pause)
	zoom_in = config_json.get("zoom_in", zoom_in)
	zoom_out = config_json.get("zoom_out", zoom_out)
	
	# language: "en" or "jp"
	language = config_json.get("language", language)
	if language not in ["en", "jp"]:
		language = "en"
		
	# Accessibility settings
	# if true show the purin's "level" on them
	numbered_purin = config_json.get("numbered_purin", numbered_purin)
	# if enabled will drop continuously until you press the key again
	drop_troggle = config_json.get("drop_troggle", drop_troggle)
	auto_drop_cooldown_sec = config_json.get("auto_drop_cooldown_sec", auto_drop_cooldown_sec)
	
	# the normal game speed, slow it down to be easier. 0.5-1.0
	game_speed = config_json.get("game_speed", game_speed)
	# if enabled the AI will only drop purin after you do
	turn_based_mode = config_json.get("turn_based_mode", turn_based_mode)
	
	# AI training settings
	training_number_of_ai = config_json.get("training_number_of_ai", training_number_of_ai)
	
	# how long each "generation" of training is before it restarts a new one
	training_generation_lifetime_sec = config_json.get("training_generation_lifetime_sec", training_generation_lifetime_sec)
	
	# how fast the game should play when training 1.0-3.0
	training_game_speed = config_json.get("training_game_speed", training_game_speed)
	
	update_all_volumes()
	

func save_settings():
	var config_json:Dictionary = read_json(settings_config_location)
	# audio sliders 0.0 - 1.0
	config_json["volume_master"] = volume_master
	config_json["volume_menu"] = volume_menu
	config_json["volume_game_sfx"] = volume_game_sfx
	config_json["volume_voices"] = volume_voices
	config_json["volume_music"] = volume_music
	
	# graphics
	config_json["enable_rain"] = enable_rain
	config_json["fullscreen"] = fullscreen
	
	# controls
	# enable or disable control types (applies to menus and in-game)
	config_json["controls_mouse"] = controls_mouse
	config_json["controls_keyboard"] = controls_keyboard
	config_json["controls_controller"] = controls_controller
	config_json["controls_move_speed"] = controls_move_speed
	
	# add additional keybinds for the actions, allow overlap with drop (applies to menus and in-game)
	config_json["custom_key_up"] = custom_key_up
	config_json["custom_key_down"] = custom_key_down
	config_json["custom_key_left"] = custom_key_left
	config_json["custom_key_right"] = custom_key_right
	
	# for menus primarily
	config_json["cusom_key_accept"] = cusom_key_accept
	config_json["custom_key_drop"] = custom_key_drop
	config_json["custom_key_retry"] = custom_key_retry
	config_json["custom_key_pause"] = custom_key_pause
	
	config_json["zoom_in"] = zoom_in
	config_json["zoom_out"] = zoom_out
	
	# language: "en" or "jp"
	config_json["language"] = language

	# Accessibility settings
	config_json["numbered_purin"] = numbered_purin
	config_json["drop_troggle"] = drop_troggle
	config_json["auto_drop_cooldown_sec"] = auto_drop_cooldown_sec
	config_json["game_speed"] = game_speed
	config_json["turn_based_mode"] = turn_based_mode
	
	# AI training settings
	config_json["training_number_of_ai"] = training_number_of_ai
	config_json["training_generation_lifetime_sec"] = training_generation_lifetime_sec
	config_json["training_game_speed"] = training_game_speed
	
	# save the results
	var json_string := JSON.stringify(config_json)
	# We will need to open/create a new file for this data string
	var file_access := FileAccess.open(settings_config_location, FileAccess.WRITE)
	if not file_access:
		print("An error happened while saving data: ", FileAccess.get_open_error())
		return
		
	file_access.store_line(json_string)
	file_access.close()
	
func update_volume(audio_bus_index:int, linear_value:float):
	var volume_db = 20 * (log(linear_value*0.01) / log(10))
	AudioServer.set_bus_volume_db(audio_bus_index, volume_db)

func update_all_volumes():
	update_volume(AudioServer.get_bus_index("Master"), Global.volume_master * 100)
	update_volume(AudioServer.get_bus_index("Menu"), Global.volume_menu * 100)
	update_volume(AudioServer.get_bus_index("Game"), Global.volume_game_sfx * 100)
	update_volume(AudioServer.get_bus_index("Voice"), Global.volume_voices * 100)
	update_volume(AudioServer.get_bus_index("Music"), Global.volume_music * 100)
	

func load_purin():
	if not purin_textures.is_empty():
		return
	purin_textures = []
	evil_purin_textures = []
	for i in range(1, len(Global.purin_sizes) + 1):
		var image_path = "%spurin%d.png" % [purin_file_path_root, i]
		purin_textures.append(load(image_path))
		var evil_image_path = "%spurin%d_evil.png" % [purin_file_path_root, i]
		evil_purin_textures.append(load(evil_image_path))


func load_ml(mutate:bool=true, mutation_rate:float = 0.03):
	var new_nna:NeuralNetworkAdvanced
	var default_ml_json = Global.read_json("res://ai_ml.json")
	var ml_json = Global.read_json("user://ai_ml.json")
	if not ml_json:
		ml_json = default_ml_json
	if not ml_json.get("ml", []).is_empty():
		new_nna = NeuralNetworkAdvanced.new()
		new_nna.mutation_rate = mutation_rate
		for layer_data in ml_json.get("ml"):
			new_nna.add_layer_from_layer_data(layer_data, mutate)
			
		new_nna.total_loss = ml_json.get("total_loss", 0)
		new_nna.total_score = ml_json.get("total_score", 0)
	else:
		new_nna = generate_new_nna(mutate, mutation_rate, false)
	return new_nna
	
func generate_new_nna(mutate:bool=false, mutation_rate:float = 0.03, randomize_layers:bool=false):
	print("Generate new NNA")
	var new_nna:NeuralNetworkAdvanced = NeuralNetworkAdvanced.new()
	new_nna.mutation_rate = mutation_rate
	var action_type = new_nna.ACTIVATIONS.SIGMOID
	new_nna.add_layer(max_input_size, action_type, mutate)
	if randomize_layers:
		# randomly pick how many hidden layers and how many nodes are in each
		for hidden_layer in range(0, randi_range(1, 3)):
			var num_nodes:int = int(pow(2,randi_range(1,6)))
			new_nna.add_layer(num_nodes, action_type, mutate)
	else:
		new_nna.add_layer(8, action_type, mutate)
		new_nna.add_layer(4, action_type, mutate)
	#output layer
	new_nna.add_layer(1, new_nna.ACTIVATIONS.SIGMOID, mutate)
	return new_nna

func save_ml_file(new_nna:NeuralNetworkAdvanced, input_file:String="user://ai_ml.json", output_file="user://ai_ml.json"):
	var ml_json = Global.read_json(input_file)
	if not ml_json:
		ml_json = {}
	var layers:Array[Dictionary] = []
	for layer in new_nna.layers:
		var layer_data: Dictionary = {
			"weights": Matrix.to_array(layer["weights"]),
			"bias": Matrix.to_array(layer["bias"]),
			"activation_name": layer["activation_name"],
			"size": layer["size"],
			"rows": layer["rows"],
			"cols": layer["cols"]
		}
		layers.append(layer_data)
	ml_json["ml"] = layers
	ml_json["total_score"] = nna.total_score
	ml_json["total_loss"] = nna.total_loss
	
	var json_string := JSON.stringify(ml_json)
	# We will need to open/create a new file for this data string
	var file_access := FileAccess.open(output_file, FileAccess.WRITE)
	if not file_access:
		print("An error happened while saving data: ", FileAccess.get_open_error())
		return
		
	file_access.store_line(json_string)
	file_access.close()
	
