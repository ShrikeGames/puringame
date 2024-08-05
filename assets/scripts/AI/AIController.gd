extends Node2D
class_name AIController

var game:PlayerController
var held_purin_level:int
var next_purin_to_drop_level:int
var inputs:Array[AIInput]
var input_object:Resource
var configurations:Dictionary
var debug:bool = false
var last_x_pos:float = 0
var last_purin_level_dropped:int = 0
func init(player_controller:PlayerController):
	self.game = player_controller
	self.held_purin_level = 0
	self.next_purin_to_drop_level = 0
	self.inputs = []
	if game.training and game.rank >= 10:
		self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}})
		var cross_breed_configuration = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, self.configurations)
		self.configurations = cross_breed(self.configurations, cross_breed_configuration)
	else:
		if game.training:
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, game.rank)
		else:
			self.configurations = game.get_configurations_with_mutation("configurations", game.ai_mutation_rate, {"0":{}}, false, 0)
	
	if debug:
		self.game.debug_label.text = "%s"%[self.configurations]
	
	input_object = load("res://assets/scenes/AI/AIInput.tscn")
	for input in game.ai_inputs_object.get_children():
		input.queue_free()
	var space_state = game.get_world_2d().direct_space_state
	var radius =  self.game.get_purin_radius(0)
	for x in range(0, ((game.right_edge.position.x - game.left_edge.position.x - (radius))/(radius))+1):
		var input:AIInput = input_object.instantiate()
		input.position = Vector2((x*radius)+radius, game.noir.position.y)
		input.disabled = true
		input.drop_line.visible = debug
		game.ai_inputs_object.add_child(input)
		input.update(space_state)
		self.inputs.append(input)

func cross_breed(config1:Dictionary, config2:Dictionary):
	if not config1:
		return config2
	if not config2:
		return config1
	for purin_level in range(0, game.highest_possible_purin_level+1):
		var purin_config1:Dictionary = config1.get("%s"%[purin_level])
		var purin_config2:Dictionary = config2.get("%s"%[purin_level])
		if not purin_config1:
			return purin_config2
		if not purin_config2:
			return purin_config1
		var new_config = purin_config1
		var split_point:int = randi_range(0,6)
		new_config["highscore_weights"] = purin_config1["highscore_weights"].slice(0,split_point) + purin_config2["highscore_weights"].slice(split_point,6)
		new_config["highscore_biases"] = purin_config1["highscore_biases"].slice(0,split_point) + purin_config2["highscore_biases"].slice(split_point,6)
	return config1

func update_inputs():
	# clear the game of any dropped purin
	remove_all_inputs()
	
	var space_state = game.get_world_2d().direct_space_state
	var radius =  self.game.get_purin_radius(self.game.purin_bag.get_current_purin()["level"])
	for x in range(0, ((game.right_edge.position.x - game.left_edge.position.x - (radius))/(radius))+1):
		var input:AIInput = self.inputs[x]
		input.position = Vector2((x*radius)+radius, game.noir.position.y)
		input.disabled = false
		input.drop_line.visible = debug
		input.debug_text.visible = debug
		input.update(space_state)
	
func remove_all_inputs():
	for input in game.ai_inputs_object.get_children():
		#input.queue_free()
		input.disabled = true
		input.drop_line.visible = false
		input.debug_text.visible = false
		
	
func best_x_pos():
	held_purin_level = game.purin_bag.get_current_purin()["level"]
	var values:Array[Value] = []
	if not inputs.is_empty():
		for input in inputs:
			update_inputs()
			var value:Value = input.value
			if is_instance_valid(value):
				if value.purin != null and is_instance_valid(value.purin):
					var next_purin_cost = value.evaluate(game, self, game.purin_bag.get_current_purin()["level"])
					value.cost = value.evaluate(game, self, held_purin_level, next_purin_cost)
				else:
					value.cost = 9999
				if debug:
					input.debug_text.text = "[center]%s[/center]"%[value.cost]
					input.debug_text.global_position = value.position
					input.debug_text.visible = debug
				values.append(value)
	values.sort_custom(cost_function)
	
	if not values.is_empty():
		return values
		
	return null

func update_noir_position():
	var best_position:Array[Value] = best_x_pos()
	for pos in best_position:
		# don't allow dropping in the same spot unless it's the same purin level
		if pos.position.x != last_x_pos or len(best_position) == 1 or held_purin_level == pos.level:
			var next_best_x:Vector2 = Vector2(game.valid_x_pos(pos.position.x - game.position.x), game.noir.position.y)
			game.noir.position = next_best_x
			last_x_pos = pos.position.x
			break
	
	
func process_ai(_delta):
	var cool_down_sec = game.drop_purin_cooldown_sec
	for purin in game.purin_node.get_children():
		if purin.position.y - purin.get_meta("radius") < game.top_edge.position.y:
			cool_down_sec = game.drop_purin_cooldown_sec * 0.75
			break
	if game.time_since_last_dropped_purin_sec >= cool_down_sec:
		var space_state = game.get_world_2d().direct_space_state
		for input in inputs:
			input.update(space_state)
		# reposition the player
		update_noir_position()
		game.drop_purin()
		last_purin_level_dropped = held_purin_level
		
		

func cost_function(value1:Value, value2:Value):
	if value1.cost < value2.cost:
		return true
	
	return false
