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

func punishments(player_controller:PlayerController, ai_controller:AIController, held_purin_level:int, next_purin_cost:float = 9999):
	# get the weights and biases from the AI Controller
	# unique to each purin level
	var weights = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_weights", [0,0,0,0,0,0])
	var biases = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_biases", [0,0,0,0,0,0])
	
	var evaluated_cost:float = 0.0
	# punish it for putting larger purin on top of smaller ones
	if held_purin_level > level:
		evaluated_cost += get_strength(weights, 0) * abs(held_purin_level - level) + get_strength(biases, 0)
	elif held_purin_level < level:
		# punish it for putting purin of different sizes on top of each other
		evaluated_cost += get_strength(weights, 1) * abs(held_purin_level - level) + get_strength(biases, 1)
	
	# punish it for being farther from the bottom
	evaluated_cost += get_strength(weights, 2) * (abs(player_controller.bottom_edge.position.y - position.y)*0.001)  + get_strength(biases, 2)
	
	# punish for being away from the left corner
	evaluated_cost += get_strength(weights, 2) * (position.x*0.01)  + get_strength(biases, 2)
	
	if purin != null and is_instance_valid(purin):
		
		# if it's above the height limit then reduce its penalty to nudging it
		if purin.position.y - purin.get_meta("radius") < player_controller.top_edge.position.y:
			if held_purin_level == purin.get_meta("level", 0):
				evaluated_cost *= 0.1
			else:
				evaluated_cost *= 0.25
	if evaluated_cost > next_purin_cost:
		evaluated_cost += 10*(get_strength(weights, 5) * max(1,(evaluated_cost-next_purin_cost))) + get_strength(biases, 5)
	# higher cost is bad
	return snappedf(evaluated_cost, 0.01)

func rewards(player_controller:PlayerController, ai_controller:AIController, held_purin_level:int, _next_purin_cost:float = 9999):
	var evaluated_reward:float = 0
	var weights = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_weights", [0,0,0,0,0,0])
	var biases = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_biases", [0,0,0,0,0,0])
	
	if purin != null and is_instance_valid(purin):
		if held_purin_level == level:
			# they can be combined! that's good :)
			evaluated_reward += int(pow(level+1, 2)) * int(1 + (player_controller.dropped_purin_count * 0.1))
			var possible_reward:float = int(pow(level+1, 2)) * int(1 + (player_controller.dropped_purin_count * 0.1))
			var num_possible_chain_combines:float = purin.number_possible_combines()
			var combination_value:float = (get_strength(weights, 4) * possible_reward * num_possible_chain_combines) + get_strength(biases, 4)
			evaluated_reward += combination_value
		if held_purin_level == level-1:
			evaluated_reward += 0.5 * int(pow(level+1, 2)) * int(1 + (player_controller.dropped_purin_count * 0.1))
			
			
	# higher reward = good
	return evaluated_reward

func evaluate(player_controller:PlayerController, ai_controller:AIController, held_purin_level:int, next_purin_cost:float = 9999):
	var punishment_cost:float = punishments(player_controller, ai_controller, held_purin_level, next_purin_cost)
	var rewards_amount:float = rewards(player_controller, ai_controller, held_purin_level, next_purin_cost)
	
	# lower is better
	return snappedf(punishment_cost - rewards_amount, 0.01)
