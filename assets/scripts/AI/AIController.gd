extends Node2D
class_name AIController

var game:PlayerController
var held_purin_level:int
var next_purin_to_drop_level:int
var inputs:Array[AIInput]
var input_object:Resource
var weights:Array
var biases:Array
var debug:bool = false
func init(player_controller:PlayerController):
	self.game = player_controller
	self.held_purin_level = 0
	self.next_purin_to_drop_level = 0
	self.inputs = []
	# take the best results it has had
	self.weights = game.get_config_value_or_default("highscore_weights", self.game.ai_mutation_rate, [1, 1, 1, 1, 1.27339, 1.25569])
	self.biases = game.get_config_value_or_default("highscore_biases", self.game.ai_mutation_rate, [0, 0, 0, 0, 0, 0])
	self.game.debug_label.text = "weights: %s. biases: %s. HS: %s"%[self.weights, self.biases, self.game.highscore]
	
	input_object = load("res://assets/scenes/AI/AIInput.tscn")
	
	var space_state = game.get_world_2d().direct_space_state
	var radius =  self.game.get_purin_radius(0)*2
	for x in range(0, (game.right_edge.position.x - game.left_edge.position.x - (radius))/radius):
		var input:AIInput = input_object.instantiate()
		input.position = Vector2((x*radius)+radius, game.noir.position.y)
		input.disabled = true
		if debug:
			input.drop_line.visible = true
		game.ai_inputs_object.add_child(input)
		input.update(space_state)
		self.inputs.append(input)
	
func update_inputs():
	# clear the game of any dropped purin
	remove_all_inputs()
	
	var space_state = game.get_world_2d().direct_space_state
	var radius =  2*self.game.get_purin_radius(self.game.purin_bag.get_current_purin_level(self.game.highest_tier_purin_dropped))
	for x in range(0, (game.right_edge.position.x - game.left_edge.position.x - (radius))/radius):
		var input:AIInput = self.inputs[x]
		input.position = Vector2((x*radius)+radius, game.noir.position.y)
		input.disabled = false
		if debug:
			input.drop_line.visible = true
		input.update(space_state)
	
func remove_all_inputs():
	for input in game.ai_inputs_object.get_children():
		#input.queue_free()
		input.disabled = true
		input.drop_line.visible = false
		
	
func best_x_pos():
	# start at a random x_pos
	var x_pos:float = 0#game.valid_x_pos(randf_range(game.left_edge.position.x+50, game.right_edge.position.x-50))
	# TODO implement AI to evaluate board state and determine best place to drop a purin
	# maybe: ray cast down in set intervals (equal to the smallest purin size)
	held_purin_level = game.purin_bag.get_current_purin_level(game.highest_tier_purin_dropped)
	var values:Array[Value] = []
	if not inputs.is_empty():
		for input in inputs:
			update_inputs()
			var value:Value = input.value
			if is_instance_valid(value):
				if value.purin != null and is_instance_valid(value.purin):
					var next_purin_cost = value.evaluate(game, self, game.purin_bag.get_current_purin_level(game.highest_tier_purin_dropped))
					value.cost = value.evaluate(game, self, held_purin_level, next_purin_cost)
				else:
					value.cost = 99
				values.append(value)
		
	values.sort_custom(cost_function)
	
	if not values.is_empty():
		var best_value:Value = values[0]
		return Vector2(game.valid_x_pos(best_value.position.x - game.position.x), game.noir.position.y)
		
	return Vector2(game.valid_x_pos(x_pos), game.noir.position.y)
	
func update_noir_position():
	var best_position:Vector2 = best_x_pos()
	game.noir.position = best_position
	
func process_ai(_delta):
	var cool_down_sec = game.drop_purin_cooldown_sec
	for purin in game.purin_node.get_children():
		if purin.position.y - purin.get_meta("radius") < game.top_edge.position.y:
			cool_down_sec *= 0.25
			break
	if game.time_since_last_dropped_purin_sec >= cool_down_sec:
		# reposition the player
		update_noir_position()
		game.drop_purin()
		var space_state = game.get_world_2d().direct_space_state
		for input in inputs:
			input.update(space_state)

func cost_function(value1:Value, value2:Value):
	if value1.cost < value2.cost:
		return true
	
	return false
