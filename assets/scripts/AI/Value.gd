extends Node
class_name Value

var level:int
var cost:float
var position:Vector2
var normal:Vector2
var purin:Purin

func get_strength(array:Array, index:int, default:float = 0.0):
	if len(array) > index:
		return array[index]
	return default

func punishments(player_controller:PlayerController, ai_controller:AIController,  held_purin_level:int, held_is_evil:bool = false, _next_purin_level:int = 0, _next_purin_is_evil:bool = false):
	# get the weights and biases from the AI Controller
	# unique to each purin level
	var weights = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_weights", [0,0,0,0,0,0])
	var biases = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_biases", [0,0,0,0,0,0])
	
	var evaluated_cost:float = 0.0
	if held_purin_level > level:
		# punish it for putting purin of different sizes on top of each other
		evaluated_cost += get_strength(weights, 0) * abs(held_purin_level - level) + get_strength(biases, 0)
	
	# punish for being away from the left corner
	evaluated_cost += get_strength(weights, 1) * (position.x*0.01)  + get_strength(biases, 1)
	# punish for being away from the right corner
	evaluated_cost += get_strength(weights, 2) * ((player_controller.right_edge.position.x - position.x)*0.01)  + get_strength(biases, 2)
	
	# punish it for being farther from the bottom
	evaluated_cost += get_strength(weights, 3) * (abs(player_controller.bottom_edge.position.y - position.y)*0.001)  + get_strength(biases, 3)
	
	
	
	if purin != null and is_instance_valid(purin):
		if held_purin_level != level:
			# if it would put it above the warning line
			if purin.position.y - purin.get_meta("radius") - (player_controller.get_purin_radius(held_purin_level)*2)< player_controller.top_edge.position.y:
				evaluated_cost += purin.get_meta("level", 1) * 25
			# would instantly lose
			if purin.position.y - purin.get_meta("radius") - (player_controller.get_purin_radius(held_purin_level)*2)< 0:
				evaluated_cost += 9999
		# can't combine if they're not both evil
		if held_is_evil and not purin.evil:
			evaluated_cost += 666
	
	# higher cost is bad
	return snappedf(evaluated_cost, 0.01)

func rewards(player_controller:PlayerController, ai_controller:AIController,  held_purin_level:int, held_is_evil:bool = false, _next_purin_level:int = 0, _next_purin_is_evil:bool = false):
	var evaluated_reward:float = 0
	var weights = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_weights", [0,0,0,0,0,0])
	var biases = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_biases", [0,0,0,0,0,0])
	
	if purin != null and is_instance_valid(purin):
		var evil_match:bool = ((held_is_evil and purin.evil) or (not held_is_evil and not purin.evil))
		if held_purin_level == level and evil_match:
			# they can be combined! that's good :)
			evaluated_reward += 100*int(pow(level+1, 2)) * int(1 + (player_controller.dropped_purin_count * 0.1))
			var possible_reward:float = 100*int(pow(level+1, 2)) * int(1 + (player_controller.dropped_purin_count * 0.1))
			var num_possible_chain_combines:float = max(1,purin.number_possible_combines())
			var combination_value:float = (get_strength(weights, 4) * possible_reward * num_possible_chain_combines) + get_strength(biases, 4)
			evaluated_reward += combination_value
			# if it's in danger
			if purin.game_over_countdown.visible:
				evaluated_reward += purin.get_meta("level", 1) * 50
		if held_purin_level == level-1 and evil_match:
			evaluated_reward += 0.25 * int(pow(level+1, 2)) * int(1 + (player_controller.dropped_purin_count * 0.1))
			# if it's in danger
			if purin.game_over_countdown.visible:
				evaluated_reward += purin.get_meta("level", 1) * 25
		
		
	# higher reward = good
	return evaluated_reward

func evaluate(player_controller:PlayerController, ai_controller:AIController, held_purin_level:int, held_is_evil:bool = false, next_purin_level:int = 0, next_purin_is_evil:bool = false, next_purin_cost:float = 9999):
	var weights = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_weights", [0,0,0,0,0,0])
	var biases = ai_controller.configurations.get("%s"%[held_purin_level], {}).get("highscore_biases", [0,0,0,0,0,0])
	
	var punishment_cost:float = punishments(player_controller, ai_controller, held_purin_level, held_is_evil, next_purin_level, next_purin_is_evil)
	var rewards_amount:float = rewards(player_controller, ai_controller,held_purin_level, held_is_evil, next_purin_level, next_purin_is_evil)
	var total_cost:float = snappedf(punishment_cost - rewards_amount, 0.01)
	
	# if the cost of this is more than placing this elsewhere so we
	# can place the next purin here then
	# everything else has to be that much worse to justify it
	if total_cost > next_purin_cost:
		var possible_reward:float = get_strength(weights, 5) * int(pow(next_purin_level+1, 2)) * int(1 + (player_controller.dropped_purin_count * 0.1))  + get_strength(biases, 5)
		total_cost += possible_reward
		
	# lower is better
	return total_cost
