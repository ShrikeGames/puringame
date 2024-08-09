extends Node2D
class_name AIController

var game:PlayerController
var held_purin_level:int
var held_is_evil:bool
var next_purin_to_drop_level:int
var next_purin_is_evil:bool
var inputs:Array[AIInput]

var configurations:Dictionary
var debug:bool = false
var last_x_pos:float = 0
var last_purin_level_dropped:int = 0
var parent_1_name:String = ""
var parent_2_name:String = ""
var parents:String = ""
func init(player_controller:PlayerController):
	self.game = player_controller
	self.held_purin_level = 0
	self.next_purin_to_drop_level = 0
	self.held_is_evil = false
	self.next_purin_is_evil = false
	self.debug = player_controller.debug
	self.inputs = []
	
	if game.training:
		if game.rank < 10:
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, game.rank)
			var cross_breed_configuration = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, self.configurations, false, game.rank+1)
			self.configurations = cross_breed(self.configurations, cross_breed_configuration)
		else:
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, true)
			var cross_breed_configuration = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, self.configurations)
			self.configurations = cross_breed(self.configurations, cross_breed_configuration)
		parents = "(%s+%s)"%[parent_1_name, parent_2_name]
	else:
		self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, true)
	
	if debug:
		self.game.debug_label.text = "%s %s"%[parents, game.ai_mutation_rate]
	
	for input in game.ai_inputs_object.get_children():
		input.queue_free()
	var radius =  self.game.get_purin_radius(0)
	for x in range(0, ((game.right_edge.position.x - game.left_edge.position.x - (radius))/(radius))+1):
		var input:AIInput = Global.ai_input_scene.instantiate()
		input.position = Vector2(5+(x*radius)+radius, game.noir.position.y)
		input.disabled = true
		input.debug = debug
		input.drop_line.visible = false
		input.bounce_line.visible = debug
		game.ai_inputs_object.add_child(input)
		self.inputs.append(input)

func cross_breed(config1:Dictionary, config2:Dictionary):
	if not config1:
		return config2
	if not config2:
		return config1
	var username_key:String = "username"
	if Global.language == "jp":
		username_key = "username_jp"
	parent_1_name = config1.get(username_key, "")
	parent_2_name = config2.get(username_key, "")
	for purin_level in range(0, Global.highest_possible_purin_level+1):
		var purin_config1:Dictionary = config1.get("%s"%[purin_level])
		var purin_config2:Dictionary = config2.get("%s"%[purin_level])
		if not purin_config1:
			return purin_config2
		if not purin_config2:
			return purin_config1
		var new_config = purin_config1
		for i in range(0, len(purin_config1["highscore_weights"])):
			# 50% chance for any weight to be taken from the other parent instead
			if randf() < 0.5:
				new_config["highscore_weights"][i] = purin_config2["highscore_weights"][i]
				new_config["highscore_biases"][i] = purin_config2["highscore_biases"][i]
			
	return config1

func update_inputs():
	# clear the game of any dropped purin
	remove_all_inputs()
	
	var radius =  self.game.get_purin_radius(self.game.purin_bag.get_current_purin()["level"])
	for x in range(0, ((game.right_edge.position.x - game.left_edge.position.x - (radius))/(radius))+1):
		var input:AIInput = self.inputs[x]
		input.position = Vector2(5+(x*radius)+radius, game.noir.position.y)
		input.disabled = false
		input.drop_line.visible = debug
		input.debug_text.visible = debug
		input.bounce_line.visible = false
		
func remove_all_inputs():
	for input in game.ai_inputs_object.get_children():
		#input.queue_free()
		input.reset()
		
	
func best_x_pos():
	held_purin_level = game.purin_bag.get_current_purin()["level"]
	held_is_evil = game.purin_bag.get_current_purin()["evil"]
	next_purin_to_drop_level = game.purin_bag.get_next_purin()["level"]
	next_purin_is_evil = game.purin_bag.get_next_purin()["evil"]
	var values:Array[Value] = []
	var space_state = game.get_world_2d().direct_space_state
	var radius =  self.game.get_purin_radius(self.game.purin_bag.get_current_purin()["level"])
	if debug:
		self.game.debug_label.text = "Attempt #%s %s %s %s"%[game.attempts+1, parents, game.ai_mutation_rate, configurations.get("%s"%[held_purin_level], "")]
	if not inputs.is_empty():
		update_inputs()
		for input in inputs:
			var next_purin_cost:float = Value.new().evaluate(game, self, next_purin_to_drop_level, next_purin_is_evil, next_purin_to_drop_level, next_purin_is_evil)
			input.update(space_state, radius, game, self, held_purin_level, held_is_evil, next_purin_to_drop_level, next_purin_is_evil, next_purin_cost)
			values.append(input.value)
			if debug:
				input.debug_text.text = "[center]%s[/center]"%[input.value.cost]
				
				input.debug_text.global_position.y = input.value.position.y
				input.debug_text.visible = debug
				input.bounce_line.visible = debug
				var strength = max(0, min(9, snapped((0.5+abs(input.value.cost*0.005))*9, 1)))
				#print(value.cost, " = ", strength)
				strength = "%s%s"%[strength, strength]
				if input.value.cost < 5:
					input.debug_text.text = "[color=00%s00]%s[/color]"%[strength, input.debug_text.text]
					input.drop_line.default_color = "00%s00"%[strength]
					input.bounce_line.default_color = "33%s00"%[strength]
				else:
					input.debug_text.text = "[color=%s0000]%s[/color]"%[strength, input.debug_text.text]
					input.drop_line.default_color = "%s0000"%[strength]
					input.bounce_line.default_color = "%s0033"%[strength]
				
	values.sort_custom(cost_function)
	
	if not values.is_empty():
		return values
	
	return null

func update_noir_position():
	var best_position:Array[Value] = best_x_pos()
	for pos in best_position:
		var next_best_x:Vector2 = Vector2(game.valid_x_pos(pos.position.x - game.position.x), game.noir.position.y)
#			if pos.purin and is_instance_valid(pos.purin):
#				var estimated_time_to_fall:float = abs(pos.purin.global_position.y - game.noir.global_position.y)*0.005
#				next_best_x.x += pos.purin.transform.x.normalized().x * estimated_time_to_fall
		game.noir.position = next_best_x
		last_x_pos = pos.position.x
		break
	
	
func process_ai(_delta):
	if game.gameover_screen.visible:
		return
	var cool_down_sec = game.drop_purin_cooldown_sec
	var emergency:bool = false
	
	var all_purin_stopped:bool = true
	var current_purin_count:int = game.purin_node.get_child_count()
	
	for purin in game.purin_node.get_children():
		if purin.game_over_countdown.visible:
			cool_down_sec = 0.25
			emergency = true
		if (abs(purin.linear_velocity.x) >= 5 or abs(purin.linear_velocity.y) >= 5) and current_purin_count > 5:
			all_purin_stopped = false
	
	var time_elapsed:bool = game.time_since_last_dropped_purin_sec >= cool_down_sec
	var double_time_elapsed:bool = game.time_since_last_dropped_purin_sec >= 2*cool_down_sec
	
	if (game.can_drop_early and game.time_since_last_dropped_purin_sec >= cool_down_sec*0.5 and all_purin_stopped) or (emergency and time_elapsed) or (time_elapsed and all_purin_stopped) or double_time_elapsed:
		# reposition the player
		update_noir_position()
		game.drop_purin()
		last_purin_level_dropped = held_purin_level
		game.can_drop_early = false
		
func cost_function(value1:Value, value2:Value):
	if value1.cost < value2.cost:
		return true
	
	return false
