extends Node
class_name Value

var level:int
var cost:float
var position:Vector2
var purin:Purin

func get_strength(array:Array, index:int, default:float = 0.0):
	if len(array) > index:
		return array[index]
	return default

func evaluate(player_controller:PlayerController, ai_controller:AIController, held_purin_level:int, next_purin_cost:float = 9999):
	# get the weights and biases from the AI Controller
	var weights = ai_controller.weights
	var biases = ai_controller.biases
	
	var evaluated_cost:float = 0.0
	# punish it for putting larger purin on top of smaller ones
	if held_purin_level > level:
		evaluated_cost += get_strength(weights, 0) * abs(held_purin_level - level) + get_strength(biases, 0)
	else:
		# punish it for putting purin of different sizes on top of each other
		evaluated_cost += get_strength(weights, 1) * abs(held_purin_level - level) + get_strength(biases, 1)
	
	# punish it for being farther from the bottom
	evaluated_cost += get_strength(weights, 2) * (player_controller.bottom_edge.position.y / position.y)  + get_strength(biases, 2)
	
	# punish it for being in the middle and not the sides
	var width = (player_controller.right_edge.position.x - player_controller.left_edge.position.x)
	var mid_point = player_controller.left_edge.position.x + (0.5 * width)
	if position.x > mid_point:
		evaluated_cost += get_strength(weights, 2) * (position.x)  + get_strength(biases, 2)
	else:
		evaluated_cost += get_strength(weights, 2) * (player_controller.right_edge.position.x / position.x)  + get_strength(biases, 2)
	
	if purin != null and is_instance_valid(purin):
		if level != held_purin_level:
			evaluated_cost += (get_strength(weights, 4) * purin.number_possible_combines()) + get_strength(biases, 4)
		# if it's above the height limit then halve its penalty to nudging it
		if purin.position.y - purin.get_meta("radius") < player_controller.top_edge.position.y:
			if held_purin_level == purin.get_meta("level", 0):
				evaluated_cost *= 0.5
			else:
				evaluated_cost *= 2
	if evaluated_cost > next_purin_cost:
		evaluated_cost += (get_strength(weights, 5) * (evaluated_cost-next_purin_cost)) + get_strength(biases, 5)
	
	return snappedf(evaluated_cost, 0.01)
